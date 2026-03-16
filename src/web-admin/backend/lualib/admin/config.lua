-- 配置 CRUD 处理模块
-- 处理 HTTP/Stream/Upstream/Location 配置的增删改查

local _M = {}
local cjson = require "cjson.safe"
local storage = require "admin.storage"
local deploy = require "admin.deploy"
local utils = require "admin.utils"

------------------------------------------------------------------------------
-- 常量定义
------------------------------------------------------------------------------

-- 支持的配置域
local DOMAINS = {
    http = true,
    stream = true,
    upstream = true,
    location = true
}

------------------------------------------------------------------------------
-- 配置验证器
------------------------------------------------------------------------------

local VALIDATORS = {
    http = function(data)
        if not data.server_name then return false, "server_name is required" end
        if not data.listen then return false, "listen is required" end
        return true
    end,

    stream = function(data)
        if not data.listen then return false, "listen is required" end
        return true
    end,

    upstream = function(data)
        if not data.id then return false, "id is required" end
        if not data.servers or #data.servers == 0 then
            return false, "servers is required and cannot be empty"
        end
        for _, server in ipairs(data.servers) do
            if not server.host or not server.port then
                return false, "each server must have host and port"
            end
        end
        return true
    end,

    location = function(data)
        if not data.path then return false, "path is required" end
        return true
    end
}

------------------------------------------------------------------------------
-- 自动应用配置到 loadbalance
------------------------------------------------------------------------------

local AUTO_APPLY = true  -- 可通过环境变量或配置控制

local function auto_apply_config()
    if not AUTO_APPLY then return end

    local result = deploy.apply()
    if result and result.success then
        ngx.log(ngx.INFO, "Config auto-applied to loadbalance")
    else
        ngx.log(ngx.WARN, "Auto-apply failed: ", result and result.message or "unknown error")
    end
end

------------------------------------------------------------------------------
-- 验证配置
------------------------------------------------------------------------------

function _M.validate(domain, data)
    if not DOMAINS[domain] then
        return false, "Invalid domain: " .. domain
    end

    local validator = VALIDATORS[domain]
    return validator and validator(data) or true
end

------------------------------------------------------------------------------
-- URL 解析
------------------------------------------------------------------------------

local function parse_uri(uri)
    -- /api/config/:domain/:id?
    local domain = uri:match("^/api/config/([^/]+)")
    local id = uri:match("^/api/config/[^/]+/([^/]+)")

    if not domain then
        return nil, nil, "Invalid URI format"
    end

    return domain, id
end

------------------------------------------------------------------------------
-- GET 请求处理
------------------------------------------------------------------------------

local function handle_get(domain, id)
    if id then
        local item, err = storage.get_item(domain, id)
        if not item then
            return utils.send_error(err or "Item not found", utils.HTTP_STATUS.NOT_FOUND)
        end
        return utils.send_response(utils.HTTP_STATUS.OK, item)
    end

    local data, err = storage.load(domain)
    if not data then
        return utils.send_error(err or "Failed to load config", utils.HTTP_STATUS.INTERNAL_ERROR)
    end
    return utils.send_response(utils.HTTP_STATUS.OK, data)
end

------------------------------------------------------------------------------
-- POST 请求处理
------------------------------------------------------------------------------

local function handle_post(domain, uri)
    local body, err = utils.parse_json_body()
    if not body then
        return utils.send_error(err)
    end

    -- 验证请求
    if uri:match("/validate$") then
        local valid, verr = _M.validate(domain, body)
        return utils.send_response(utils.HTTP_STATUS.OK, {
            valid = valid,
            error = verr
        })
    end

    -- 创建配置
    local valid, verr = _M.validate(domain, body)
    if not valid then
        return utils.send_error(verr)
    end

    local ok, item_id = storage.add_item(domain, body)
    if not ok then
        return utils.send_error(item_id or "Failed to save config", utils.HTTP_STATUS.INTERNAL_ERROR)
    end

    -- 自动应用配置
    auto_apply_config()

    return utils.send_created(item_id)
end

------------------------------------------------------------------------------
-- PUT 请求处理
------------------------------------------------------------------------------

local function handle_put(domain, id)
    if not id then
        return utils.send_error("ID is required for update")
    end

    local body, err = utils.parse_json_body()
    if not body then
        return utils.send_error(err)
    end

    local valid, verr = _M.validate(domain, body)
    if not valid then
        return utils.send_error(verr)
    end

    local ok, uerr = storage.update_item(domain, id, body)
    if not ok then
        return utils.send_error(uerr or "Failed to update config", utils.HTTP_STATUS.INTERNAL_ERROR)
    end

    -- 自动应用配置
    auto_apply_config()

    return utils.send_updated()
end

------------------------------------------------------------------------------
-- DELETE 请求处理
------------------------------------------------------------------------------

local function handle_delete(domain, id)
    if not id then
        return utils.send_error("ID is required for delete")
    end

    local ok, err = storage.delete_item(domain, id)
    if not ok then
        return utils.send_error(err or "Failed to delete config", utils.HTTP_STATUS.INTERNAL_ERROR)
    end

    -- 自动应用配置
    auto_apply_config()

    return utils.send_deleted()
end

------------------------------------------------------------------------------
-- 回滚处理
------------------------------------------------------------------------------

local function handle_rollback(domain)
    local body, err = utils.parse_json_body()
    if not body or not body.version then
        return utils.send_error("version is required for rollback")
    end

    local ok, rerr = storage.rollback(domain, body.version)
    if not ok then
        return utils.send_error(rerr or "Failed to rollback", utils.HTTP_STATUS.INTERNAL_ERROR)
    end

    return utils.send_response(utils.HTTP_STATUS.OK, {
        success = true,
        message = "Rolled back to version " .. body.version
    })
end

------------------------------------------------------------------------------
-- 历史处理
------------------------------------------------------------------------------

local function handle_history(domain)
    local versions = storage.history(domain)
    return utils.send_success({ versions = versions })
end

------------------------------------------------------------------------------
-- 主处理函数
------------------------------------------------------------------------------

function _M.handle(method, uri)
    local domain, id, err = parse_uri(uri)
    if not domain then
        return utils.send_error(err or "Invalid URI")
    end

    if not DOMAINS[domain] then
        return utils.send_error("Invalid domain: " .. domain)
    end

    -- 路由请求
    if method == "GET" then
        if uri:match("/history$") then
            return handle_history(domain)
        end
        return handle_get(domain, id)
    elseif method == "POST" then
        return handle_post(domain, uri)
    elseif method == "PUT" then
        return handle_put(domain, id)
    elseif method == "DELETE" then
        return handle_delete(domain, id)
    else
        return utils.send_response(405, { error = "Method not allowed" })
    end
end

return _M