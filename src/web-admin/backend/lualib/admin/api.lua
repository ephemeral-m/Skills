-- API 路由入口模块
-- 处理所有 API 请求的路由分发

local _M = {}
local cjson = require "cjson.safe"
local config = require "admin.config"
local monitor = require "admin.monitor"
local deploy = require "admin.deploy"
local utils = require "admin.utils"

------------------------------------------------------------------------------
-- 日志和统计
------------------------------------------------------------------------------

-- 记录请求日志
local function log_request(method, uri, status)
    ngx.log(ngx.INFO, string.format('[%s] %s %s - %d',
        ngx.localtime(), method, uri, status))
end

-- 更新请求统计
local function update_stats(method, status)
    local status_dict = ngx.shared.status
    if not status_dict then return end

    -- 更新总请求数
    status_dict:incr("requests_total", 1, 0)

    -- 更新状态码统计
    local status_key = status >= 500 and "status_5xx"
                    or status >= 400 and "status_4xx"
                    or status >= 300 and "status_3xx"
                    or "status_2xx"
    status_dict:incr(status_key, 1, 0)

    -- 更新方法统计
    local method_key = "method_" .. string.lower(method)
    if status_dict:get(method_key) ~= nil then
        status_dict:incr(method_key, 1, 0)
    end
end

------------------------------------------------------------------------------
-- 请求验证
------------------------------------------------------------------------------

local function validate_request()
    local method = ngx.req.get_method()
    if method == "POST" or method == "PUT" then
        if not utils.is_json_request() then
            return false, "Content-Type must be application/json"
        end
    end
    return true
end

------------------------------------------------------------------------------
-- 部署路由处理
------------------------------------------------------------------------------

local function handle_deploy(method, uri)
    -- POST /api/deploy/preview
    if method == "POST" and uri:match("/preview$") then
        return utils.send_success(deploy.preview())
    end

    -- POST /api/deploy/apply
    if method == "POST" and uri:match("/apply$") then
        local result = deploy.apply()
        return result.success
            and utils.send_success(result)
            or utils.send_response(utils.HTTP_STATUS.INTERNAL_ERROR, result)
    end

    -- GET /api/deploy/status
    if method == "GET" and uri:match("/status$") then
        return utils.send_success(deploy.status())
    end

    -- GET /api/deploy - API 信息
    if method == "GET" then
        return utils.send_success({
            endpoints = {
                preview = "POST /api/deploy/preview",
                apply = "POST /api/deploy/apply",
                status = "GET /api/deploy/status"
            }
        })
    end

    return utils.send_error("Not Found", utils.HTTP_STATUS.NOT_FOUND)
end

------------------------------------------------------------------------------
-- API 信息
------------------------------------------------------------------------------

local API_INFO = {
    name = "OpenResty Config Admin API",
    version = "2.0.0",
    endpoints = {
        config = {
            list = "GET /api/config/:domain",
            get = "GET /api/config/:domain/:id",
            create = "POST /api/config/:domain",
            update = "PUT /api/config/:domain/:id",
            delete = "DELETE /api/config/:domain/:id"
        },
        status = {
            nginx = "GET /api/status/nginx",
            connections = "GET /api/status/connections",
            dict = "GET /api/status/dict",
            cache = "GET /api/status/cache",
            requests = "GET /api/status/requests",
            all = "GET /api/status/all"
        },
        deploy = {
            preview = "POST /api/deploy/preview",
            apply = "POST /api/deploy/apply",
            status = "GET /api/deploy/status"
        },
        health = "GET /api/health"
    }
}

------------------------------------------------------------------------------
-- 初始化
------------------------------------------------------------------------------

function _M.init()
    monitor.init()
    ngx.log(ngx.INFO, "Admin API initialized")
end

------------------------------------------------------------------------------
-- 路由分发
------------------------------------------------------------------------------

function _M.dispatch()
    local uri = ngx.var.uri
    local method = ngx.req.get_method()

    -- 处理 OPTIONS 预检请求
    if method == "OPTIONS" then
        return utils.handle_preflight()
    end

    -- 请求验证
    local valid, verr = validate_request()
    if not valid then
        log_request(method, uri, 400)
        return utils.send_error(verr)
    end

    -- 路由分发
    local status = 200
    local success, err = pcall(function()
        if uri:match("^/api/config/") then
            config.handle(method, uri)
        elseif uri:match("^/api/status/") then
            monitor.handle(method, uri)
        elseif uri == "/api/health" or uri == "/api/health/" then
            utils.send_success({
                status = "healthy",
                timestamp = ngx.localtime(),
                version = "2.0.0"
            })
        elseif uri:match("^/api/deploy") then
            handle_deploy(method, uri)
        elseif uri == "/api" or uri == "/api/" then
            utils.send_success(API_INFO)
        else
            status = 404
            utils.send_error("Not Found", utils.HTTP_STATUS.NOT_FOUND)
        end
    end)

    if not success then
        ngx.log(ngx.ERR, "API Error: ", err)
        status = 500
        utils.send_response(500, { error = "Internal Server Error", message = err })
    end

    -- 更新统计
    status = ngx.status or status
    update_stats(method, status)
    log_request(method, uri, status)
end

return _M