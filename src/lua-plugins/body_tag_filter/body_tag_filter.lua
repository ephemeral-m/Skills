--[[
插件名称: body_tag_filter
版本: 1.0.0
类型: http
功能: 根据请求体中的标签字段决定是否拦截请求

数据格式:
  - tag_field: string - 要检查的字段名（默认 "gray"）
  - block_values: string[] - 需要拦截的标签值列表
  - allow_values: string[] - 允许通过的标签值列表（优先级高于 block_values）
  - reject_code: number - 拒绝时的 HTTP 状态码（默认 403）
  - reject_message: string - 拒绝时的响应消息（默认 "Request blocked"）
  - reject_headers: table - 拒绝时添加的响应头
  - max_body_size: number - 最大请求体大小（字节，默认 1MB）
  - content_types: string[] - 支持的内容类型列表
]]

------------------------------------------------------------------------------
-- ngx 变量 local 化
------------------------------------------------------------------------------
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local req = ngx.req
local str_find = string.find
local str_sub = string.sub
local tonumber = tonumber
local type = type
local pairs = pairs
local ipairs = ipairs

------------------------------------------------------------------------------
-- 模块定义
------------------------------------------------------------------------------
local _M = {
    _VERSION = "1.0.0",
    _NAME = "body_tag_filter"
}

local config = {}

-- 默认配置
local DEFAULT_CONFIG = {
    tag_field = "gray",
    block_values = {},
    allow_values = {},
    reject_code = 403,
    reject_message = "Request blocked",
    reject_headers = {},
    max_body_size = 1024 * 1024,
    content_types = {
        "application/json",
        "application/x-www-form-urlencoded",
        "text/plain"
    }
}

------------------------------------------------------------------------------
-- 内部函数
------------------------------------------------------------------------------

-- 检查值是否在列表中
local function in_list(value, list)
    if not value or not list then return false end
    for _, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

-- 检查内容类型是否支持
local function is_content_type_supported(content_type)
    if not content_type then
        return false
    end

    -- 提取主类型（忽略 charset 等参数）
    local main_type = content_type
    local semicolon = str_find(content_type, ";", 1, true)
    if semicolon then
        main_type = str_sub(content_type, 1, semicolon - 1)
    end

    -- trim and lower
    main_type = main_type:gsub("^%s*(.-)%s*$", "%1"):lower()

    for _, ct in ipairs(config.content_types) do
        if ct:lower() == main_type then
            return true
        end
    end
    return false
end

-- 从 JSON 中提取字段值
local function extract_from_json(body, field)
    if not body or not field then return nil end

    -- 匹配字符串值: "field": "value"
    local m = ngx.re.match(body, '"' .. field .. '"\\s*:\\s*"([^"]*)"', "jo")
    if m and m[1] then
        return m[1]
    end

    -- 匹配数字值: "field": 123
    m = ngx.re.match(body, '"' .. field .. '"\\s*:\\s*([\\d\\.]+)', "jo")
    if m and m[1] then
        return m[1]
    end

    return nil
end

-- 从 form-urlencoded 中提取字段值
local function extract_from_form(body, field)
    if not body or not field then return nil end

    -- 使用 ngx.re.match 进行正则匹配
    local m = ngx.re.match(body, field .. "=([^&]*)", "jo")
    if m and m[1] then
        local value = m[1]
        -- URL 解码
        value = value:gsub("+", " ")
        value = value:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        -- 移除引号
        if str_sub(value, 1, 1) == '"' and str_sub(value, -1) == '"' then
            value = str_sub(value, 2, -2)
        end
        return value
    end

    return nil
end

-- 从请求体提取标签值
local function extract_tag_value(body, content_type)
    if not body then return nil end

    local lower_ct = (content_type or ""):lower()

    -- 使用 plain 模式匹配（第4个参数为 true）避免 - 等特殊字符被解释为模式
    if str_find(lower_ct, "application/json", 1, true) then
        return extract_from_json(body, config.tag_field)
    elseif str_find(lower_ct, "application/x-www-form-urlencoded", 1, true) then
        return extract_from_form(body, config.tag_field)
    else
        return nil
    end
end

------------------------------------------------------------------------------
-- 公共接口
------------------------------------------------------------------------------
function _M.init_worker(data)
    if not data then
        config = {}
        for k, v in pairs(DEFAULT_CONFIG) do
            config[k] = v
        end
        return true
    end

    config = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        config[k] = data[k] ~= nil and data[k] or v
    end

    if config.reject_code < 100 or config.reject_code > 599 then
        return false, "invalid reject_code: " .. config.reject_code
    end

    log(INFO, "[", _M._NAME, "] initialized with tag_field=", config.tag_field)
    return true
end

function _M.prerouting()
    local content_type = req.get_headers()["Content-Type"]

    -- GET/HEAD 无请求体
    local method = req.get_method()
    if method == "GET" or method == "HEAD" then
        ngx.ctx.filter_action = "pass"
        return true
    end

    -- 检查内容类型
    if content_type and not is_content_type_supported(content_type) then
        ngx.ctx.filter_action = "pass"
        return true
    end

    -- 检查请求体大小
    local content_length = tonumber(req.get_headers()["Content-Length"] or 0)
    if content_length > config.max_body_size then
        ngx.ctx.filter_action = "pass"
        return true
    end

    -- 读取请求体
    req.read_body()
    local body = req.get_body_data()

    if not body or #body == 0 then
        ngx.ctx.filter_action = "pass"
        return true
    end

    -- 提取标签值
    local tag_value = extract_tag_value(body, content_type)
    ngx.ctx.tag_value = tag_value

    -- 判断动作
    if tag_value and #config.allow_values > 0 then
        if in_list(tag_value, config.allow_values) then
            ngx.ctx.filter_action = "pass"
        else
            ngx.ctx.filter_action = "block"
        end
    elseif tag_value and #config.block_values > 0 then
        if in_list(tag_value, config.block_values) then
            ngx.ctx.filter_action = "block"
        else
            ngx.ctx.filter_action = "pass"
        end
    else
        ngx.ctx.filter_action = "pass"
    end

    return true
end

function _M.postrouting()
    if ngx.ctx.filter_action == "block" then
        if config.reject_headers then
            for k, v in pairs(config.reject_headers) do
                ngx.header[k] = v
            end
        end

        ngx.header["X-Block-Reason"] = "tag blocked"
        ngx.status = config.reject_code
        ngx.say(config.reject_message)
        return ngx.exit(config.reject_code)
    end

    return true
end

function _M.header_filter()
    if ngx.ctx.tag_value then
        ngx.header["X-Tag-Value"] = ngx.ctx.tag_value
    end
end

return _M