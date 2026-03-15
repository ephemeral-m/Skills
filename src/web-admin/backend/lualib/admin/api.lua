-- API 路由入口模块
-- 处理所有 API 请求的路由分发

local _M = {}
local cjson = require "cjson.safe"
local config = require "admin.config"
local monitor = require "admin.monitor"

-- CORS 头
local function set_cors_headers()
    ngx.header["Access-Control-Allow-Origin"] = "*"
    ngx.header["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    ngx.header["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    ngx.header["Access-Control-Max-Age"] = "3600"
end

-- 发送 JSON 响应
local function send_response(status, data)
    ngx.status = status
    set_cors_headers()
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say(cjson.encode(data))
end

-- 处理 OPTIONS 预检请求
local function handle_options()
    set_cors_headers()
    ngx.status = 204
    ngx.exit(204)
end

-- 记录请求日志
local function log_request(method, uri, status)
    local log_entry = string.format(
        '[%s] %s %s - %d',
        ngx.localtime(),
        method,
        uri,
        status
    )
    ngx.log(ngx.INFO, log_entry)
end

-- 更新请求统计
local function update_stats(method, status)
    local status_dict = ngx.shared.status
    if not status_dict then return end

    -- 更新总请求数
    status_dict:incr("requests_total", 1, 0)

    -- 更新状态码统计
    if status >= 200 and status < 300 then
        status_dict:incr("status_2xx", 1, 0)
    elseif status >= 300 and status < 400 then
        status_dict:incr("status_3xx", 1, 0)
    elseif status >= 400 and status < 500 then
        status_dict:incr("status_4xx", 1, 0)
    elseif status >= 500 then
        status_dict:incr("status_5xx", 1, 0)
    end

    -- 更新方法统计
    local method_lower = string.lower(method)
    local key = "method_" .. method_lower
    if status_dict:get(key) ~= nil then
        status_dict:incr(key, 1, 0)
    end
end

-- 请求验证
local function validate_request()
    -- 检查 Content-Type（POST/PUT 请求）
    local method = ngx.req.get_method()
    if method == "POST" or method == "PUT" then
        local content_type = ngx.req.get_headers()["Content-Type"] or ""
        if not content_type:find("application/json", 1, true) then
            return false, "Content-Type must be application/json"
        end
    end

    -- 可以添加更多验证逻辑，如认证检查
    -- local auth = ngx.req.get_headers()["Authorization"]
    -- if not auth then
    --     return false, "Authorization header is required"
    -- end

    return true
end

-- 初始化
function _M.init()
    -- 初始化监控统计
    monitor.init()

    ngx.log(ngx.INFO, "Admin API initialized")
end

-- 路由分发
function _M.dispatch()
    local uri = ngx.var.uri
    local method = ngx.req.get_method()

    -- 处理 OPTIONS 预检请求
    if method == "OPTIONS" then
        return handle_options()
    end

    -- 请求验证
    local valid, verr = validate_request()
    if not valid then
        log_request(method, uri, 400)
        return send_response(400, { error = verr })
    end

    -- 路由分发
    local status = 200
    local success, err = pcall(function()
        if uri:match("^/api/config/") then
            config.handle(method, uri)
        elseif uri:match("^/api/status/") then
            monitor.handle(method, uri)
        elseif uri == "/api/health" or uri == "/api/health/" then
            -- 健康检查端点
            send_response(200, {
                status = "healthy",
                timestamp = ngx.localtime(),
                version = "1.0.0"
            })
        elseif uri == "/api" or uri == "/api/" then
            -- API 信息端点
            send_response(200, {
                name = "OpenResty Config Admin API",
                version = "1.0.0",
                endpoints = {
                    config = {
                        list = "GET /api/config/:domain",
                        get = "GET /api/config/:domain/:id",
                        create = "POST /api/config/:domain",
                        update = "PUT /api/config/:domain/:id",
                        delete = "DELETE /api/config/:domain/:id",
                        validate = "POST /api/config/:domain/validate",
                        history = "GET /api/config/:domain/history",
                        rollback = "POST /api/config/:domain/rollback"
                    },
                    status = {
                        nginx = "GET /api/status/nginx",
                        connections = "GET /api/status/connections",
                        dict = "GET /api/status/dict",
                        cache = "GET /api/status/cache",
                        requests = "GET /api/status/requests",
                        all = "GET /api/status/all"
                    },
                    health = "GET /api/health"
                }
            })
        else
            status = 404
            send_response(404, { error = "Not Found", uri = uri })
        end
    end)

    if not success then
        ngx.log(ngx.ERR, "API Error: ", err)
        status = 500
        send_response(500, { error = "Internal Server Error", message = err })
    end

    -- 更新统计
    status = ngx.status or status
    update_stats(method, status)
    log_request(method, uri, status)
end

return _M