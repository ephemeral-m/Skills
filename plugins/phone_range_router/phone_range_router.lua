--[[
插件名称: phone_range_router
版本: 1.0.0
类型: http
功能: 根据请求头 phone-number 字段值范围路由到不同后端
]]

------------------------------------------------------------------------------
-- ngx 变量 local 化
------------------------------------------------------------------------------
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local WARN = ngx.WARN
local DEBUG = ngx.DEBUG
local req = ngx.req
local re = ngx.re

------------------------------------------------------------------------------
-- 模块定义
------------------------------------------------------------------------------
local _M = {
    _VERSION = "1.0.0",
    _NAME = "phone_range_router"
}

local config = {}

------------------------------------------------------------------------------
-- 内部函数
------------------------------------------------------------------------------
local function phone_to_number(phone)
    if not phone then return nil end
    phone = re.gsub(phone, "[^0-9]", "", "jo")
    return #phone == 11 and tonumber(phone) or nil
end

local function find_upstream(phone_num)
    for _, r in ipairs(config.ranges or {}) do
        if phone_num >= r.min_num and phone_num <= r.max_num then
            return r.upstream
        end
    end
    return nil
end

------------------------------------------------------------------------------
-- 公共接口
------------------------------------------------------------------------------
function _M.init_worker(data)
    if not data then
        return false, "data is nil"
    end

    -- 解析并验证区间配置
    local ranges = {}
    for i, r in ipairs(data.ranges or {}) do
        local min_num = phone_to_number(r.min)
        local max_num = phone_to_number(r.max)
        if not min_num or not max_num then
            return false, string.format("invalid range at index %d", i)
        end
        if min_num > max_num then
            return false, string.format("min > max at index %d", i)
        end
        if not r.upstream then
            return false, string.format("upstream required at index %d", i)
        end
        table.insert(ranges, {
            min_num = min_num,
            max_num = max_num,
            upstream = r.upstream
        })
    end

    -- 按起始值排序优化匹配效率
    table.sort(ranges, function(a, b) return a.min_num < b.min_num end)

    config.ranges = ranges
    config.default_upstream = data.default_upstream or "default_backend"
    config.header_name = data.header_name or "phone-number"

    log(INFO, "[", _M._NAME, "] loaded ", #ranges, " ranges")
    return true
end

------------------------------------------------------------------------------
-- HTTP 接口
------------------------------------------------------------------------------
function _M.prerouting()
    local phone = req.get_headers()[config.header_name]
    if phone then
        if type(phone) == "table" then phone = phone[1] end
        ngx.ctx.phone = phone
        ngx.ctx.phone_num = phone_to_number(phone)
    end
    return true
end

function _M.postrouting()
    local phone_num = ngx.ctx.phone_num
    local target = config.default_upstream

    if phone_num then
        target = find_upstream(phone_num) or config.default_upstream
        log(DEBUG, "[", _M._NAME, "] phone=", ngx.ctx.phone, " -> ", target)
    elseif ngx.ctx.phone then
        log(WARN, "[", _M._NAME, "] invalid phone format: ", ngx.ctx.phone)
    end

    ngx.var.upstream = target
    return true
end

function _M.header_filter()
    if ngx.ctx.phone then
        ngx.header["X-Phone"] = ngx.ctx.phone
    end
    ngx.header["X-Upstream"] = ngx.var.upstream
end

return _M