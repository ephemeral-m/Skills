--[[
插件名称: gray_router
版本: 1.0.0
类型: http
功能: 根据请求体中 gray=true 标签决定返回灰度响应或正常转发

数据格式:
  - response: table - 灰度响应配置
    - status: number - 响应状态码（默认: 200）
    - headers: table - 响应头键值对
    - body: string - 响应体内容
  - tag_pattern: string - 匹配模式（默认: "gray=true"）
]]

local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG
local req = ngx.req

local _M = {
    _VERSION = "1.0.0",
    _NAME = "gray_router"
}

local config = {
    response = {
        status = 200,
        headers = {},
        body = ""
    },
    tag_pattern = "gray=true"
}

--- 检查字符串中是否包含灰度标签
-- @param body 请求体字符串
-- @param pattern 要匹配的模式
-- @return boolean 是否匹配到灰度标签
local function has_gray_tag(body, pattern)
    if not body or body == "" then
        return false
    end

    -- 使用 plain 模式进行纯字符串匹配，避免 pattern 特殊字符问题
    local found = string.find(body, pattern, 1, true)
    return found ~= nil
end

--- 发送灰度响应
-- @param response 响应配置
local function send_gray_response(response)
    local status = response.status or 200
    local headers = response.headers or {}
    local body = response.body or ""

    -- 设置响应头
    for key, value in pairs(headers) do
        ngx.header[key] = value
    end

    -- 设置默认 Content-Type
    if not ngx.header["Content-Type"] then
        ngx.header["Content-Type"] = "application/json; charset=utf-8"
    end

    -- 记录日志
    log(INFO, "[", _M._NAME, "] returning gray response, status=", status)

    -- 返回响应
    ngx.status = status
    ngx.say(body)
    ngx.exit(status)
end

--- 初始化插件配置
-- @param data 配置数据
-- @return boolean, string? 成功/失败+错误信息
function _M.init_worker(data)
    if not data then
        log(INFO, "[", _M._NAME, "] no config provided, using defaults")
        return true
    end

    -- 加载响应配置
    if data.response then
        config.response = {
            status = data.response.status or 200,
            headers = data.response.headers or {},
            body = data.response.body or ""
        }

        -- 验证 status
        if type(config.response.status) ~= "number" then
            return false, "response.status must be a number"
        end
    end

    -- 加载标签模式
    if data.tag_pattern then
        if type(data.tag_pattern) ~= "string" then
            return false, "tag_pattern must be a string"
        end
        config.tag_pattern = data.tag_pattern
    end

    log(INFO, "[", _M._NAME, "] initialized with tag_pattern='", config.tag_pattern, "'")
    return true
end

--- 请求预处理：读取请求体并检查灰度标签
-- @return boolean 是否继续处理
function _M.prerouting()
    local method = req.get_method()

    -- 只处理有请求体的方法
    if method == "POST" or method == "PUT" or method == "PATCH" then
        -- 读取请求体
        req.read_body()
        local body = req.get_body_data()

        -- 如果请求体太大，尝试读取临时文件
        if not body then
            local body_file = req.get_body_file()
            if body_file then
                -- 对于大文件，只读取前 1MB 进行匹配
                local file = io.open(body_file, "r")
                if file then
                    body = file:read(1024 * 1024)
                    file:close()
                end
            end
        end

        -- 检查是否包含灰度标签
        if has_gray_tag(body, config.tag_pattern) then
            ngx.ctx.is_gray = true
            log(DEBUG, "[", _M._NAME, "] gray tag detected in request body")
        end
    end

    return true
end

--- 路由决策：返回灰度响应或继续转发
-- @return boolean 是否成功
function _M.postrouting()
    if ngx.ctx.is_gray then
        send_gray_response(config.response)
        -- 注意: ngx.exit() 会终止请求，以下代码不会执行
        return true
    end

    log(DEBUG, "[", _M._NAME, "] no gray tag, forwarding to backend")
    return true
end

return _M