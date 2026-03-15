-- 配置 CRUD 处理模块
-- 处理 HTTP/Stream/Upstream/Location 配置的增删改查

local _M = {}
local cjson = require "cjson.safe"
local storage = require "admin.storage"

-- 支持的配置域
local DOMAINS = {
    http = true,
    stream = true,
    upstream = true,
    location = true
}

-- 配置验证规则
local VALIDATORS = {
    http = function(data)
        if not data.server_name then
            return false, "server_name is required"
        end
        if not data.listen then
            return false, "listen is required"
        end
        return true
    end,

    stream = function(data)
        if not data.listen then
            return false, "listen is required"
        end
        return true
    end,

    upstream = function(data)
        if not data.id then
            return false, "id is required"
        end
        if not data.servers or #data.servers == 0 then
            return false, "servers is required and cannot be empty"
        end
        for _, server in ipairs(data.servers or {}) do
            if not server.host or not server.port then
                return false, "each server must have host and port"
            end
        end
        return true
    end,

    location = function(data)
        if not data.path then
            return false, "path is required"
        end
        return true
    end
}

-- 验证配置
function _M.validate(domain, data)
    if not DOMAINS[domain] then
        return false, "Invalid domain: " .. domain
    end

    local validator = VALIDATORS[domain]
    if validator then
        return validator(data)
    end

    return true
end

-- 发送 JSON 响应
local function send_response(status, data)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say(cjson.encode(data))
end

-- 解析请求体
local function get_request_body()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    if not body then
        return nil, "Request body is empty"
    end

    local data, err = cjson.decode(body)
    if not data then
        return nil, "Invalid JSON: " .. (err or "unknown error")
    end

    return data
end

-- 解析 URL 参数
local function parse_uri(uri)
    -- /api/config/:domain/:id?
    local domain = uri:match("^/api/config/([^/]+)")
    local id = uri:match("^/api/config/[^/]+/([^/]+)")

    if not domain then
        return nil, nil, "Invalid URI format"
    end

    return domain, id
end

-- 处理 GET 请求
local function handle_get(domain, id)
    if not DOMAINS[domain] then
        return send_response(400, { error = "Invalid domain: " .. domain })
    end

    if id then
        -- 获取单个配置项
        local item, err = storage.get_item(domain, id)
        if not item then
            return send_response(404, { error = err or "Item not found" })
        end
        return send_response(200, item)
    else
        -- 获取配置列表
        local data, err = storage.load(domain)
        if not data then
            return send_response(500, { error = err or "Failed to load config" })
        end
        return send_response(200, data)
    end
end

-- 处理 POST 请求
local function handle_post(domain, uri)
    local body, err = get_request_body()
    if not body then
        return send_response(400, { error = err })
    end

    -- 检查是否是验证请求
    if uri:match("/validate$") then
        local valid, verr = _M.validate(domain, body)
        return send_response(200, {
            valid = valid,
            error = verr
        })
    end

    -- 创建新配置
    local valid, verr = _M.validate(domain, body)
    if not valid then
        return send_response(400, { error = verr })
    end

    local ok, item_id = storage.add_item(domain, body)
    if not ok then
        return send_response(500, { error = item_id or "Failed to save config" })
    end

    return send_response(201, {
        id = item_id,
        message = "Created successfully"
    })
end

-- 处理 PUT 请求
local function handle_put(domain, id)
    if not id then
        return send_response(400, { error = "ID is required for update" })
    end

    local body, err = get_request_body()
    if not body then
        return send_response(400, { error = err })
    end

    local valid, verr = _M.validate(domain, body)
    if not valid then
        return send_response(400, { error = verr })
    end

    local ok, uerr = storage.update_item(domain, id, body)
    if not ok then
        return send_response(500, { error = uerr or "Failed to update config" })
    end

    return send_response(200, { message = "Updated successfully" })
end

-- 处理 DELETE 请求
local function handle_delete(domain, id)
    if not id then
        return send_response(400, { error = "ID is required for delete" })
    end

    local ok, err = storage.delete_item(domain, id)
    if not ok then
        return send_response(500, { error = err or "Failed to delete config" })
    end

    return send_response(200, { message = "Deleted successfully" })
end

-- 处理回滚请求
local function handle_rollback(domain)
    local body, err = get_request_body()
    if not body or not body.version then
        return send_response(400, { error = "version is required for rollback" })
    end

    local ok, rerr = storage.rollback(domain, body.version)
    if not ok then
        return send_response(500, { error = rerr or "Failed to rollback" })
    end

    return send_response(200, { message = "Rolled back to version " .. body.version })
end

-- 处理历史请求
local function handle_history(domain)
    local versions = storage.history(domain)
    return send_response(200, { versions = versions })
end

-- 主处理函数
function _M.handle(method, uri)
    local domain, id, err = parse_uri(uri)
    if not domain then
        return send_response(400, { error = err or "Invalid URI" })
    end

    -- 检查域是否有效
    if not DOMAINS[domain] then
        return send_response(400, { error = "Invalid domain: " .. domain })
    end

    -- 路由请求
    if method == "GET" then
        -- 检查是否是历史请求
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
        return send_response(405, { error = "Method not allowed" })
    end
end

return _M