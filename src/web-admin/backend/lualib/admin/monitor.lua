-- 监控接口模块
-- 提供 Nginx 状态、负载均衡规则、转发配置等监控数据

local _M = {}
local cjson = require "cjson.safe"
local utils = require "admin.utils"
local storage = require "admin.storage"
local io_open = io.open

------------------------------------------------------------------------------
-- Loadbalance 模块信息
------------------------------------------------------------------------------

-- 获取负载均衡目录路径
local function get_loadbalance_dir()
    local prefix = ngx.config.prefix()
    prefix = prefix:gsub("/+$", "")

    local parts = {}
    for part in prefix:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    for i = 1, 2 do
        if #parts > 0 then
            table.remove(parts)
        end
    end

    table.insert(parts, "loadbalance")
    return "/" .. table.concat(parts, "/")
end

local function get_loadbalance_info()
    local loadbalance_dir = get_loadbalance_dir()
    local info = {
        version = "-",
        compile_args = {},
        loaded = false,
        config_dir = loadbalance_dir .. "/conf.d",
        pid_file = loadbalance_dir .. "/logs/nginx.pid"
    }

    -- 检查负载均衡进程是否运行
    local pid_file = io_open(info.pid_file, "r")
    if pid_file then
        local pid = pid_file:read("*n")
        pid_file:close()

        if pid then
            local proc_check = io_open("/proc/" .. pid .. "/cmdline", "r")
            if proc_check then
                local cmdline = proc_check:read("*a")
                proc_check:close()
                info.loaded = cmdline and cmdline:find("nginx") ~= nil
                info.pid = pid
            end
        end
    end

    -- 获取 nginx 版本作为负载均衡版本
    local nginx_bin = ngx.config.prefix() .. "../../../build/openresty/nginx/sbin/nginx"
    local handle = io.popen(nginx_bin .. " -v 2>&1", "r")
    if handle then
        local version_output = handle:read("*a")
        handle:close()
        -- 提取版本号: openresty/1.29.2.1 或 nginx/1.29.0
        info.version = version_output:match("openresty/([%d%.]+)") or
                       version_output:match("nginx/([%d%.]+)") or
                       version_output:gsub("\n", "")
    end

    -- 获取编译参数
    handle = io.popen(nginx_bin .. " -V 2>&1", "r")
    if handle then
        local compile_output = handle:read("*a")
        handle:close()

        -- 提取关键编译参数
        local key_modules = {
            "with-http_ssl_module", "with-http_v2_module", "with-http_realip_module",
            "with-http_gzip_static_module", "with-stream", "with-stream_ssl_module",
            "with-luajit"
        }
        for _, mod in ipairs(key_modules) do
            if compile_output:find(mod, 1, true) then
                table.insert(info.compile_args, "--" .. mod)
            end
        end
    end

    return info
end

------------------------------------------------------------------------------
-- 转发规则配置状态
------------------------------------------------------------------------------

local function get_forward_rules()
    local rules = {}

    -- 加载所有配置资源
    local servers_config = storage.load("servers")
    local server_groups_config = storage.load("server-groups")
    local routes_config = storage.load("routes")
    local http_listeners_config = storage.load("listeners-http")
    local tcp_listeners_config = storage.load("listeners-tcp")

    -- 构建映射表
    local servers_map = {}
    if servers_config and servers_config.items then
        for _, item in ipairs(servers_config.items) do
            servers_map[item.id] = item
        end
    end

    local server_groups_map = {}
    if server_groups_config and server_groups_config.items then
        for _, item in ipairs(server_groups_config.items) do
            server_groups_map[item.id] = item
        end
    end

    local routes_map = {}
    if routes_config and routes_config.items then
        for _, item in ipairs(routes_config.items) do
            routes_map[item.id] = item
        end
    end

    -- HTTP 监听器规则
    if http_listeners_config and http_listeners_config.items then
        for _, listener in ipairs(http_listeners_config.items) do
            local rule = {
                id = listener.id,
                type = "HTTP",
                listen = {},
                server_name = listener.server_name or "",
                route_refs = listener.route_refs or {},
                status = "active",
                updated_at = http_listeners_config.updated_at or ""
            }

            -- 解析监听端口
            for _, l in ipairs(listener.listen or {}) do
                table.insert(rule.listen, l.port .. (l.ssl and " (SSL)" or ""))
            end

            -- 检查引用的路由是否有后端服务器组
            local has_valid_backend = false
            for _, route_id in ipairs(listener.route_refs or {}) do
                local route = routes_map[route_id]
                if route and route.server_group_ref and route.server_group_ref ~= "" then
                    local group = server_groups_map[route.server_group_ref]
                    if group then
                        has_valid_backend = true
                        rule.server_group_ref = route.server_group_ref
                        break
                    end
                end
            end

            if not has_valid_backend and #rule.route_refs > 0 then
                rule.status = "no_backend"
            end

            table.insert(rules, rule)
        end
    end

    -- TCP 监听器规则
    if tcp_listeners_config and tcp_listeners_config.items then
        for _, listener in ipairs(tcp_listeners_config.items) do
            local rule = {
                id = listener.id,
                type = listener.protocol == "udp" and "UDP" or "TCP",
                listen = { listener.listen },
                server_group_ref = listener.server_group_ref or "",
                status = "active",
                updated_at = tcp_listeners_config.updated_at or ""
            }

            -- 检查后端服务器组是否有效
            if listener.server_group_ref and listener.server_group_ref ~= "" then
                local group = server_groups_map[listener.server_group_ref]
                if not group then
                    rule.status = "no_backend"
                end
            else
                rule.status = "no_backend"
            end

            table.insert(rules, rule)
        end
    end

    -- 路由规则详情
    local route_details = {}
    if routes_config and routes_config.items then
        for _, route in ipairs(routes_config.items) do
            local detail = {
                id = route.id,
                path = route.path,
                server_group_ref = route.server_group_ref or "",
                has_custom = route.custom_directives and route.custom_directives ~= "",
                status = "active"
            }

            -- 检查后端服务器组
            if route.server_group_ref and route.server_group_ref ~= "" then
                local group = server_groups_map[route.server_group_ref]
                if not group then
                    detail.status = "no_backend"
                else
                    detail.server_count = #(group.server_refs or {})
                end
            else
                -- 没有后端服务器组，但有自定义指令，仍可工作
                if not detail.has_custom then
                    detail.status = "no_backend"
                end
            end

            table.insert(route_details, detail)
        end
    end

    -- 服务器组详情
    local server_group_details = {}
    if server_groups_config and server_groups_config.items then
        for _, group in ipairs(server_groups_config.items) do
            local detail = {
                id = group.id,
                balance = group.balance or "round_robin",
                server_count = #(group.server_refs or {}),
                servers = {}
            }

            for _, server_id in ipairs(group.server_refs or {}) do
                local server = servers_map[server_id]
                if server then
                    table.insert(detail.servers, {
                        id = server.id,
                        host = server.host,
                        port = server.port,
                        weight = server.weight or 1
                    })
                end
            end

            table.insert(server_group_details, detail)
        end
    end

    return {
        rules = rules,
        route_details = route_details,
        server_group_details = server_group_details,
        stats = {
            total_rules = #rules,
            http_rules = #(http_listeners_config and http_listeners_config.items or {}),
            tcp_rules = #(tcp_listeners_config and tcp_listeners_config.items or {}),
            routes = #(routes_config and routes_config.items or {}),
            server_groups = #(server_groups_config and server_groups_config.items or {}),
            servers = #(servers_config and servers_config.items or {})
        }
    }
end

------------------------------------------------------------------------------
-- Nginx 状态
------------------------------------------------------------------------------

local function get_nginx_status()
    local status_dict = ngx.shared.status
    local start_time = status_dict and status_dict:get("start_time") or ngx.now()

    -- 首次访问时记录启动时间
    if status_dict and not status_dict:get("start_time") then
        status_dict:set("start_time", ngx.now())
    end

    local uptime = ngx.now() - start_time
    local days = math.floor(uptime / 86400)
    local hours = math.floor((uptime % 86400) / 3600)
    local minutes = math.floor((uptime % 3600) / 60)
    local seconds = math.floor(uptime % 60)

    return {
        version = ngx.config.nginx_version,
        ngx_lua_version = ngx.config.ngx_lua_version,
        worker_processes = ngx.worker.count() or 1,
        worker_id = ngx.worker.id() or 0,
        pid = ngx.worker.pid() or 0,
        uptime = uptime,
        uptime_human = string.format("%d days, %d hours, %d minutes, %d seconds",
            days, hours, minutes, seconds),
        hostname = ngx.var.hostname or "",
        prefix = ngx.config.prefix()
    }
end

------------------------------------------------------------------------------
-- 连接统计
------------------------------------------------------------------------------

local function get_connections()
    local status_dict = ngx.shared.status
    return {
        active = utils.get_field(status_dict, "connections_active", 0),
        reading = 0,
        writing = 0,
        waiting = 0,
        accepted = utils.get_field(status_dict, "connections_accepted", 0),
        handled = utils.get_field(status_dict, "connections_handled", 0),
        requests = utils.get_field(status_dict, "requests_total", 0)
    }
end

------------------------------------------------------------------------------
-- 共享字典状态
------------------------------------------------------------------------------

local function get_dict_status()
    local dicts = {}
    local dict_names = { "config_cache", "status" }

    for _, name in ipairs(dict_names) do
        local dict = ngx.shared[name]
        if dict then
            local keys = dict:get_keys(0) or {}
            local count = 0
            for _ in pairs(keys) do count = count + 1 end
            dicts[name] = { name = name, keys = count, capacity = "N/A" }
        else
            dicts[name] = { name = name, error = "Not initialized" }
        end
    end

    return dicts
end

------------------------------------------------------------------------------
-- 配置缓存状态
------------------------------------------------------------------------------

local function get_config_cache()
    local cache = ngx.shared.config_cache
    local domains = { "http", "stream", "upstream", "location" }
    local cache_data = {}

    for _, domain in ipairs(domains) do
        cache_data[domain] = { cached = false }
    end

    if not cache then return cache_data end

    for _, domain in ipairs(domains) do
        local cached = cache:get(domain)
        if cached then
            local decoded = cjson.decode(cached)
            cache_data[domain] = {
                version = decoded and decoded.version,
                updated_at = decoded and decoded.updated_at,
                items_count = decoded and decoded.items and #decoded.items or 0
            }
        end
    end

    return cache_data
end

------------------------------------------------------------------------------
-- 请求统计
------------------------------------------------------------------------------

local function get_request_stats()
    local status_dict = ngx.shared.status
    if not status_dict then
        return {
            total = 0,
            by_status = { ["2xx"] = 0, ["3xx"] = 0, ["4xx"] = 0, ["5xx"] = 0 },
            by_method = { GET = 0, POST = 0, PUT = 0, DELETE = 0 }
        }
    end

    return {
        total = status_dict:get("requests_total") or 0,
        by_status = {
            ["2xx"] = status_dict:get("status_2xx") or 0,
            ["3xx"] = status_dict:get("status_3xx") or 0,
            ["4xx"] = status_dict:get("status_4xx") or 0,
            ["5xx"] = status_dict:get("status_5xx") or 0
        },
        by_method = {
            GET = status_dict:get("method_get") or 0,
            POST = status_dict:get("method_post") or 0,
            PUT = status_dict:get("method_put") or 0,
            DELETE = status_dict:get("method_delete") or 0
        }
    }
end

------------------------------------------------------------------------------
-- 状态获取器映射
------------------------------------------------------------------------------

local STATUS_HANDLERS = {
    nginx = get_nginx_status,
    connections = get_connections,
    dict = get_dict_status,
    cache = get_config_cache,
    requests = get_request_stats,
    loadbalance = get_loadbalance_info,
    ["forward-rules"] = get_forward_rules,
    all = function()
        return {
            nginx = get_nginx_status(),
            loadbalance = get_loadbalance_info(),
            forward_rules = get_forward_rules(),
            timestamp = ngx.localtime()
        }
    end
}

------------------------------------------------------------------------------
-- 主处理函数
------------------------------------------------------------------------------

function _M.handle(method, uri)
    if method ~= "GET" then
        return utils.send_response(405, { error = "Method not allowed" })
    end

    local status_type = uri:match("^/api/status/([^/]+)")
    local handler = STATUS_HANDLERS[status_type]

    if not handler then
        return utils.send_error("Invalid status type: " .. (status_type or "nil"))
    end

    return utils.send_success(handler())
end

------------------------------------------------------------------------------
-- 初始化统计字典
------------------------------------------------------------------------------

function _M.init()
    local status = ngx.shared.status
    if not status then return end

    -- 初始化计数器（仅在首次启动时）
    if status:get("connections_active") then return end

    local counters = {
        "connections_active", "connections_accepted", "connections_handled",
        "requests_total", "status_2xx", "status_3xx", "status_4xx", "status_5xx",
        "method_get", "method_post", "method_put", "method_delete"
    }

    for _, counter in ipairs(counters) do
        status:set(counter, 0)
    end
end

return _M