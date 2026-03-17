-- 配置 CRUD 处理模块

local _M = {}
local storage = require "admin.storage"
local utils = require "admin.utils"

------------------------------------------------------------------------------
-- 常量定义
------------------------------------------------------------------------------

-- 支持的配置域
local DOMAINS = {
    servers = true,
    ["server-groups"] = true,
    routes = true,
    ["listeners-http"] = true,
    ["listeners-tcp"] = true
}

------------------------------------------------------------------------------
-- 配置验证器
------------------------------------------------------------------------------

local VALIDATORS = {
    servers = function(data)
        if not data.id then return false, "id is required" end
        if not data.host then return false, "host is required" end
        if not data.port then return false, "port is required" end
        return true
    end,

    ["server-groups"] = function(data)
        if not data.id then return false, "id is required" end
        return true
    end,

    routes = function(data)
        if not data.id then return false, "id is required" end
        if not data.path then return false, "path is required" end
        return true
    end,

    ["listeners-http"] = function(data)
        if not data.id then return false, "id is required" end
        return true
    end,

    ["listeners-tcp"] = function(data)
        if not data.id then return false, "id is required" end
        if not data.listen then return false, "listen is required" end
        return true
    end
}

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

    return utils.send_deleted()
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