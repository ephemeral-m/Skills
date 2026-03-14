# HTTP 插件开发

HTTP 插件用于处理 HTTP 请求和响应。

## 阶段划分

```
请求方向 →
┌─────────────────────────────────────────────────────────────────────┐
│  Master 进程                                                         │
│  ┌──────────────┐                                                    │
│  │    init      │  ← 全局初始化（通常不需要）                         │
│  └──────────────┘                                                    │
├─────────────────────────────────────────────────────────────────────┤
│  Worker 进程                                                         │
│  ┌──────────────┐                                                    │
│  │ init_worker  │  ← 加载配置（通常需要）                             │
│  └──────────────┘                                                    │
├─────────────────────────────────────────────────────────────────────┤
│  请求处理阶段                                                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                 │
│  │ prerouting  │ → │  rewrite    │ → │   access    │                 │
│  └─────────────┘   └─────────────┘   └─────────────┘                 │
│         │                                     │                      │
│         └─────────────→┌─────────────┐←──────┘                      │
│                        │ postrouting │                               │
│                        └─────────────┘                               │
├─────────────────────────────────────────────────────────────────────┤
│  响应过滤阶段                                                         │
│  ┌─────────────────┐   ┌─────────────────┐                          │
│  │  header_filter  │ → │   body_filter   │                          │
│  └─────────────────┘   └─────────────────┘                          │
└─────────────────────────────────────────────────────────────────────┘
```

## 二次开发接口

**仅实现必需的接口，非必需接口不要定义。**

### prerouting

| 属性 | 说明 |
|------|------|
| 用途 | 请求预处理：读取请求体、参数提取、白名单检查 |
| 是否必需定义 | 按需 |
| 阶段 | `rewrite_by_lua*` |

**入参：**

| 序号 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 1 | data | table | 用户自定义数据（可选，通常用 nil） |

**返回值：**

| 序号 | 类型 | 说明 |
|------|------|------|
| 1 | boolean | 允许继续返回 `true`，拒绝返回 `false` |
| 2 | string | 拒绝时返回错误信息 |

---

### postrouting

| 属性 | 说明 |
|------|------|
| 用途 | 路由决策、灰度发布、动态上游选择 |
| 是否必需定义 | 按需 |
| 阶段 | `access_by_lua*` |

**入参：**

| 序号 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 1 | data | table | 用户自定义数据（可选，通常用 nil） |

**返回值：**

| 序号 | 类型 | 说明 |
|------|------|------|
| 1 | boolean | 成功返回 `true` |
| 2 | string | 失败时返回错误信息 |

---

### header_filter

| 属性 | 说明 |
|------|------|
| 用途 | 响应头修改 |
| 是否必需定义 | 按需 |
| 阶段 | `header_filter_by_lua*` |

**入参：**

| 序号 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 1 | data | table | 用户自定义数据（可选） |

**返回值：** 无

---

### body_filter

| 属性 | 说明 |
|------|------|
| 用途 | 响应体修改、数据脱敏 |
| 是否必需定义 | 按需 |
| 阶段 | `body_filter_by_lua*` |

**入参：**

| 序号 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 1 | data | table | 用户自定义数据（可选） |

**返回值：** 无（通过修改 `ngx.arg[1]` 改变输出）

---

## 功能映射表

| 功能关键词 | 推荐接口 |
|------------|----------|
| 白名单、请求体解析 | `prerouting` |
| 灰度发布、动态路由 | `postrouting` |
| 响应头修改 | `header_filter` |
| 响应体修改 | `body_filter` |

---

## 完整示例

### 手机号区间路由插件

```lua
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
local var = ngx.var
local ctx = ngx.ctx
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

    -- 按起始值排序
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
        ctx.phone = phone
        ctx.phone_num = phone_to_number(phone)
    end
    return true
end

function _M.postrouting()
    local phone_num = ctx.phone_num
    local target = config.default_upstream

    if phone_num then
        target = find_upstream(phone_num) or config.default_upstream
        log(DEBUG, "[", _M._NAME, "] phone=", ctx.phone, " -> ", target)
    elseif ctx.phone then
        log(WARN, "[", _M._NAME, "] invalid phone: ", ctx.phone)
    end

    var.upstream = target
    return true
end

function _M.header_filter()
    if ctx.phone then
        header["X-Phone"] = ctx.phone
    end
    header["X-Upstream"] = var.upstream
end

return _M
```

### Nginx 配置

```nginx
http {
    lua_package_path "/path/to/plugins/?.lua;;";

    upstream backend_a { server 192.168.1.10:8080; }
    upstream backend_b { server 192.168.2.10:8080; }
    upstream default_backend { server 192.168.100.10:8080; }

    init_worker_by_lua_block {
        local plugin = require "phone_range_router"
        local ok, err = plugin.init_worker({
            ranges = {
                {min = "13000000000", max = "13999999999", upstream = "backend_a"},
                {min = "15000000000", max = "15999999999", upstream = "backend_b"}
            },
            default_upstream = "default_backend",
            header_name = "phone-number"
        })
        if not ok then
            ngx.log(ngx.ERR, "init failed: ", err)
        end
    }

    server {
        listen 80;
        set $upstream default_backend;

        location /api/ {
            rewrite_by_lua_block {
                require("phone_range_router").prerouting()
            }
            access_by_lua_block {
                require("phone_range_router").postrouting()
            }
            proxy_pass http://$upstream;
            header_filter_by_lua_block {
                require("phone_range_router").header_filter()
            }
        }
    }
}
```