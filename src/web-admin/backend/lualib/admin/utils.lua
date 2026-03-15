-- 公共工具模块
-- 提供共享的响应处理、CORS、请求解析等功能

local _M = {
    _VERSION = "1.0.0"
}

local cjson = require "cjson.safe"

-- 常量定义
_M.CONTENT_TYPE_JSON = "application/json"
_M.CONTENT_TYPE_HTML = "text/html"

_M.HTTP_STATUS = {
    OK = 200,
    CREATED = 201,
    BAD_REQUEST = 400,
    NOT_FOUND = 404,
    INTERNAL_ERROR = 500
}

-- CORS 头部
_M.CORS_HEADERS = {
    ["Access-Control-Allow-Origin"] = "*",
    ["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS",
    ["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
}

------------------------------------------------------------------------------
-- 发送 JSON 响应
------------------------------------------------------------------------------
function _M.send_response(status, data)
    local response = cjson.encode(data)

    ngx.status = status
    ngx.header["Content-Type"] = _M.CONTENT_TYPE_JSON

    -- 添加 CORS 头部
    for k, v in pairs(_M.CORS_HEADERS) do
        ngx.header[k] = v
    end

    ngx.say(response)
    ngx.exit(ngx.HTTP_OK)
end

------------------------------------------------------------------------------
-- 发送成功响应
------------------------------------------------------------------------------
function _M.send_success(data, message)
    local response = {
        success = true,
        message = message or "Success"
    }
    if data then
        response.data = data
    end
    _M.send_response(_M.HTTP_STATUS.OK, response)
end

------------------------------------------------------------------------------
-- 发送错误响应
------------------------------------------------------------------------------
function _M.send_error(message, status)
    status = status or _M.HTTP_STATUS.BAD_REQUEST
    _M.send_response(status, {
        success = false,
        error = message
    })
end

------------------------------------------------------------------------------
-- 发送创建成功响应
------------------------------------------------------------------------------
function _M.send_created(id, message)
    _M.send_response(_M.HTTP_STATUS.CREATED, {
        success = true,
        id = id,
        message = message or "Created successfully"
    })
end

------------------------------------------------------------------------------
-- 发送更新成功响应
------------------------------------------------------------------------------
function _M.send_updated(message)
    _M.send_response(_M.HTTP_STATUS.OK, {
        success = true,
        message = message or "Updated successfully"
    })
end

------------------------------------------------------------------------------
-- 发送删除成功响应
------------------------------------------------------------------------------
function _M.send_deleted(message)
    _M.send_response(_M.HTTP_STATUS.OK, {
        success = true,
        message = message or "Deleted successfully"
    })
end

------------------------------------------------------------------------------
-- 处理 OPTIONS 预检请求
------------------------------------------------------------------------------
function _M.handle_preflight()
    for k, v in pairs(_M.CORS_HEADERS) do
        ngx.header[k] = v
    end
    ngx.exit(204)
end

------------------------------------------------------------------------------
-- 检查请求方法是否为 JSON
------------------------------------------------------------------------------
function _M.is_json_request()
    local content_type = ngx.req.get_headers()["Content-Type"] or ""
    return content_type:find(_M.CONTENT_TYPE_JSON, 1, true) ~= nil
end

------------------------------------------------------------------------------
-- 解析 JSON 请求体
------------------------------------------------------------------------------
function _M.parse_json_body()
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

------------------------------------------------------------------------------
-- 安全获取表字段
------------------------------------------------------------------------------
function _M.get_field(tbl, key, default)
    if type(tbl) == "table" then
        return tbl[key] or default
    end
    return default
end

------------------------------------------------------------------------------
-- 检查必需字段
------------------------------------------------------------------------------
function _M.check_required(data, fields)
    for _, field in ipairs(fields) do
        if not data[field] then
            return false, "Missing required field: " .. field
        end
    end
    return true
end

return _M