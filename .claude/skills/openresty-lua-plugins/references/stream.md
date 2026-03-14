# Stream 插件开发

Stream 插件用于处理 TCP/UDP 流量。

## 阶段划分

```
连接方向 →
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
│  数据处理阶段                                                         │
│  ┌─────────────┐   ┌─────────────┐                                   │
│  │  preread    │ → │  content    │                                   │
│  └─────────────┘   └─────────────┘                                   │
└─────────────────────────────────────────────────────────────────────┘
```

## 二次开发接口

**仅实现必需的接口，非必需接口不要定义。**

### preread

| 属性 | 说明 |
|------|------|
| 用途 | 协议识别、白名单检查、动态上游选择 |
| 是否必需定义 | 按需 |
| 阶段 | `preread_by_lua*` |

**入参：**

| 序号 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 1 | data | table | 用户自定义数据（可选） |

**返回值：**

| 序号 | 类型 | 说明 |
|------|------|------|
| 1 | boolean | 允许继续返回 `true`，拒绝返回 `false` |
| 2 | string | 拒绝时返回错误信息 |

---

### content

| 属性 | 说明 |
|------|------|
| 用途 | TCP 代理转发、数据处理 |
| 是否必需定义 | 按需 |
| 阶段 | `content_by_lua*` |

**入参：**

| 序号 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 1 | data | table | 用户自定义数据（可选） |

**返回值：** 无

---

## 功能映射表

| 功能关键词 | 推荐接口 |
|------------|----------|
| 协议识别、白名单 | `preread` |
| TCP 代理、转发 | `content` |

---

## 完整示例

### TCP 智能路由插件

```lua
--[[
插件名称: tcp_smart_router
版本: 1.0.0
类型: stream
功能: 基于协议识别的 TCP 智能路由
]]

------------------------------------------------------------------------------
-- ngx 变量 local 化
------------------------------------------------------------------------------
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG
local var = ngx.var
local ctx = ngx.ctx
local re = ngx.re
local socket = ngx.socket

------------------------------------------------------------------------------
-- 模块定义
------------------------------------------------------------------------------
local _M = {
    _VERSION = "1.0.0",
    _NAME = "tcp_smart_router"
}

local config = {}

------------------------------------------------------------------------------
-- 内部函数
------------------------------------------------------------------------------
local function detect_protocol(data)
    if not data or #data < 4 then return nil end

    -- Redis
    if data:sub(1, 1) == "*" then return "redis" end

    -- HTTP
    if re.match(data, "^(GET|POST|PUT|DELETE|HEAD) ", "jo") then
        return "http"
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

    config.upstreams = data.upstreams or {}
    config.default_upstream = data.default_upstream
    config.timeout = data.timeout or 30000

    log(INFO, "[", _M._NAME, "] initialized")
    return true
end

------------------------------------------------------------------------------
-- Stream 接口
------------------------------------------------------------------------------
function _M.preread()
    local sock = ngx.req.socket()
    sock:settimeout(1000)

    local data, err = sock:receiveany(256)
    if not data then
        log(ERR, "[", _M._NAME, "] receive failed: ", err)
        return false, "receive failed: " .. (err or "unknown")
    end

    ctx.peek_data = data
    ctx.protocol = detect_protocol(data)

    -- 选择上游
    local upstream = config.default_upstream
    if ctx.protocol and config.upstreams[ctx.protocol] then
        upstream = config.upstreams[ctx.protocol]
    end

    ctx.upstream = upstream
    log(DEBUG, "[", _M._NAME, "] protocol=", ctx.protocol, " upstream=", upstream)

    return true
end

function _M.content()
    local upstream_addr = ctx.upstream
    if not upstream_addr then
        log(ERR, "[", _M._NAME, "] upstream not set")
        return
    end

    local host, port = upstream_addr:match("^([^:]+):(%d+)$")
    if not host then
        log(ERR, "[", _M._NAME, "] invalid upstream: ", upstream_addr)
        return
    end

    -- 连接上游
    local upstream = socket.tcp()
    upstream:settimeout(config.timeout)

    local ok, err = upstream:connect(host, tonumber(port))
    if not ok then
        log(ERR, "[", _M._NAME, "] connect failed: ", err)
        return
    end

    -- 发送预读数据
    if ctx.peek_data then
        upstream:send(ctx.peek_data)
    end

    -- 双向转发
    local sock = ngx.req.socket()
    local function forward(src, dst)
        while true do
            local data, err = src:receiveany(8192)
            if not data then break end
            if not dst:send(data) then break end
        end
    end

    local th1 = ngx.thread.spawn(forward, sock, upstream)
    local th2 = ngx.thread.spawn(forward, upstream, sock)
    ngx.thread.wait(th1, th2)

    upstream:close()
end

return _M
```

### Nginx 配置

```nginx
stream {
    lua_package_path "/path/to/plugins/?.lua;;";

    init_worker_by_lua_block {
        local plugin = require "tcp_smart_router"
        plugin.init_worker({
            upstreams = {
                redis = "192.168.1.10:6379",
                http = "192.168.1.20:80"
            },
            default_upstream = "192.168.100.10:8080",
            timeout = 30000
        })
    }

    server {
        listen 3300;

        preread_by_lua_block {
            require("tcp_smart_router").preread()
        }

        content_by_lua_block {
            require("tcp_smart_router").content()
        }
    }
}
```