-- 监控接口模块
-- 提供 Nginx 状态、连接统计、共享字典状态等监控数据

local _M = {}
local cjson = require "cjson.safe"

-- 发送 JSON 响应
local function send_response(status, data)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say(cjson.encode(data))
end

-- 获取 Nginx 状态
local function get_nginx_status()
    -- 从共享字典获取启动时间
    local status_dict = ngx.shared.status
    local start_time = status_dict and status_dict:get("start_time") or ngx.now()

    -- 如果是第一次访问，记录启动时间
    if status_dict and not status_dict:get("start_time") then
        status_dict:set("start_time", ngx.now())
    end

    local status = {
        version = ngx.config.nginx_version,
        ngx_lua_version = ngx.config.ngx_lua_version,
        worker_processes = ngx.worker.count() or 1,
        worker_id = ngx.worker.id() or 0,
        pid = ngx.worker.pid() or 0,
        uptime = ngx.now() - start_time,
        hostname = ngx.var.hostname or "",
        prefix = ngx.config.prefix()
    }

    -- 计算运行时间
    local days = math.floor(status.uptime / 86400)
    local hours = math.floor((status.uptime % 86400) / 3600)
    local minutes = math.floor((status.uptime % 3600) / 60)
    local seconds = math.floor(status.uptime % 60)

    status.uptime_human = string.format("%d days, %d hours, %d minutes, %d seconds",
        days, hours, minutes, seconds)

    return status
end

-- 获取连接统计
local function get_connections()
    -- 使用 ngx.shared.DICT 统计连接
    local status_dict = ngx.shared.status
    local connections = {
        active = 0,
        reading = 0,
        writing = 0,
        waiting = 0,
        accepted = 0,
        handled = 0,
        requests = 0
    }

    -- 从共享字典获取统计数据
    if status_dict then
        connections.active = status_dict:get("connections_active") or 0
        connections.accepted = status_dict:get("connections_accepted") or 0
        connections.handled = status_dict:get("connections_handled") or 0
        connections.requests = status_dict:get("requests_total") or 0
    end

    -- 尝试读取 stub_status 数据（如果配置了）
    -- 这是一个简化版本，实际应该通过内部请求获取

    return connections
end

-- 获取共享字典状态
local function get_dict_status()
    local dicts = {}
    local dict_names = { "config_cache", "status" }

    for _, name in ipairs(dict_names) do
        local dict = ngx.shared[name]
        if dict then
            local keys = dict:get_keys(0) or {}
            local total_size = 0
            for _ in pairs(keys) do
                total_size = total_size + 1
            end

            dicts[name] = {
                name = name,
                keys = total_size,
                -- 注意：free_space 在某些版本可能不可用
                capacity = "N/A"
            }
        else
            dicts[name] = {
                name = name,
                error = "Not initialized"
            }
        end
    end

    return dicts
end

-- 获取配置缓存状态
local function get_config_cache()
    local cache = ngx.shared.config_cache
    local cache_data = {
        http = nil,
        stream = nil,
        upstream = nil,
        location = nil
    }

    if cache then
        local cjson = require "cjson.safe"
        for domain in pairs(cache_data) do
            local cached = cache:get(domain)
            if cached then
                local decoded = cjson.decode(cached)
                cache_data[domain] = {
                    version = decoded and decoded.version,
                    updated_at = decoded and decoded.updated_at,
                    items_count = decoded and decoded.items and #decoded.items or 0
                }
            else
                cache_data[domain] = { cached = false }
            end
        end
    end

    return cache_data
end

-- 获取请求统计
local function get_request_stats()
    local status_dict = ngx.shared.status
    local stats = {
        total = 0,
        by_status = {
            ["2xx"] = 0,
            ["3xx"] = 0,
            ["4xx"] = 0,
            ["5xx"] = 0
        },
        by_method = {
            GET = 0,
            POST = 0,
            PUT = 0,
            DELETE = 0
        },
        avg_response_time = 0
    }

    if status_dict then
        stats.total = status_dict:get("requests_total") or 0
        stats.by_status["2xx"] = status_dict:get("status_2xx") or 0
        stats.by_status["3xx"] = status_dict:get("status_3xx") or 0
        stats.by_status["4xx"] = status_dict:get("status_4xx") or 0
        stats.by_status["5xx"] = status_dict:get("status_5xx") or 0
        stats.by_method.GET = status_dict:get("method_get") or 0
        stats.by_method.POST = status_dict:get("method_post") or 0
        stats.by_method.PUT = status_dict:get("method_put") or 0
        stats.by_method.DELETE = status_dict:get("method_delete") or 0
    end

    return stats
end

-- 解析请求路径
local function parse_uri(uri)
    -- /api/status/:type
    local status_type = uri:match("^/api/status/([^/]+)")
    return status_type
end

-- 主处理函数
function _M.handle(method, uri)
    if method ~= "GET" then
        return send_response(405, { error = "Method not allowed" })
    end

    local status_type = parse_uri(uri)
    local data, err

    if status_type == "nginx" then
        data = get_nginx_status()
    elseif status_type == "connections" then
        data = get_connections()
    elseif status_type == "dict" then
        data = get_dict_status()
    elseif status_type == "cache" then
        data = get_config_cache()
    elseif status_type == "requests" then
        data = get_request_stats()
    elseif status_type == "all" then
        -- 返回所有监控数据
        data = {
            nginx = get_nginx_status(),
            connections = get_connections(),
            dict = get_dict_status(),
            cache = get_config_cache(),
            requests = get_request_stats(),
            timestamp = ngx.localtime()
        }
    else
        return send_response(400, { error = "Invalid status type: " .. (status_type or "nil") })
    end

    return send_response(200, data)
end

-- 初始化统计字典
function _M.init()
    local status = ngx.shared.status
    if status then
        -- 初始化计数器
        if not status:get("connections_active") then
            status:set("connections_active", 0)
            status:set("connections_accepted", 0)
            status:set("connections_handled", 0)
            status:set("requests_total", 0)
            status:set("status_2xx", 0)
            status:set("status_3xx", 0)
            status:set("status_4xx", 0)
            status:set("status_5xx", 0)
            status:set("method_get", 0)
            status:set("method_post", 0)
            status:set("method_put", 0)
            status:set("method_delete", 0)
        end
    end
end

return _M