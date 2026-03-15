-- 监控接口模块
-- 提供 Nginx 状态、连接统计、共享字典状态等监控数据

local _M = {}
local cjson = require "cjson.safe"
local utils = require "admin.utils"

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
    all = function()
        return {
            nginx = get_nginx_status(),
            connections = get_connections(),
            dict = get_dict_status(),
            cache = get_config_cache(),
            requests = get_request_stats(),
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