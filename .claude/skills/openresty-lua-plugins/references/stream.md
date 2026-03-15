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

## 禁止的高风险行为

### 1. 禁止自行建立后端连接

```lua
-- ❌ 禁止：在 content 阶段自行管理连接
local function bad_proxy()
    local upstream = socket.tcp()  -- LuaSocket 阻塞！
    upstream:connect(host, port)
    -- ...
end

-- ✅ 正确：使用 cosocket（非阻塞）
local function good_proxy()
    local upstream = ngx.socket.tcp()
    upstream:settimeout(5000)
    local ok, err = upstream:connect(host, port)
    if not ok then return nil, err end
    -- ...
end
```

**原因：**
- Stream 模块通常处理长连接，阻塞操作会严重影响吞吐量
- 自行管理的连接可能与 Nginx 事件循环冲突

### 2. 禁止无限等待数据

```lua
-- ❌ 禁止：无限超时
local sock = ngx.req.socket()
local data = sock:receive("*l")  -- 可能永久阻塞

-- ✅ 正确：设置合理超时
local sock = ngx.req.socket()
sock:settimeout(10000)  -- 10 秒超时
local data, err = sock:receive("*l")
if err == "timeout" then
    ngx.log(ngx.ERR, "receive timeout")
    return
end
```

### 3. 禁止在 preread 阶段消耗过多数据

```lua
-- ❌ 禁止：读取过多数据
local data = sock:receive(1024 * 1024)  -- 1MB，影响性能

-- ✅ 正确：只读取必要的协议识别数据
local data, err = sock:receiveany(256)  -- 最多 256 字节
```

**原因：**
- preread 阶段读取的数据需要在后续阶段传递
- 读取过多数据会增加内存压力和延迟

### 4. 禁止阻塞式协议识别

```lua
-- ❌ 禁止：等待完整协议握手
while not protocol_detected do
    local data = sock:receive("*l")
    -- 分析协议...
end

-- ✅ 正确：非阻塞快速识别
sock:settimeout(100)  -- 短超时
local data = sock:receiveany(128)
if data then
    protocol = detect_protocol(data)
end
```

## 开发接口

**仅实现必需的接口，非必需接口不要定义。**

### preread

| 属性 | 说明 |
|------|------|
| 用途 | 协议识别、白名单检查、动态上游选择 |
| 阶段 | `preread_by_lua*` |

**入参：** `data` (table, 可选)

**返回值：**
- `true` - 允许继续
- `false, error_msg` - 拒绝连接

---

### content

| 属性 | 说明 |
|------|------|
| 用途 | TCP 代理转发、数据处理 |
| 阶段 | `content_by_lua*` |

**入参：** `data` (table, 可选)

**返回值：** 无

---

## 功能映射表

| 功能关键词 | 推荐接口 | 优先考虑原生方案 |
|------------|----------|------------------|
| IP 白名单 | `preread` | `allow`/`deny` 指令 |
| 协议识别 | `preread` | `ssl_preread` 模块 |
| 动态上游 | `preread` | `upstream` + `server` 指令 |
| TCP 代理 | `content` | `proxy_pass` 指令 |

---

## 优先考虑 Nginx 原生配置

| 需求 | Nginx 原生方案 | 说明 |
|------|----------------|------|
| TCP 负载均衡 | `stream { upstream {} proxy_pass; }` | 最优方案 |
| 基于端口的代理 | `listen` + `proxy_pass` | 简单高效 |
| SSL 终止 | `ssl_certificate` 系列 | 无需 Lua |
| 连接限速 | `proxy_download_rate` / `proxy_upload_rate` | 原生支持 |
| 连接超时 | `proxy_timeout` | 原生支持 |

**只有以下场景才需要 Lua 插件：**
1. 基于数据内容的协议识别
2. 复杂的路由逻辑（如数据库分片路由）
3. 数据内容转换/脱敏

---

## 完整示例

### TCP 智能路由插件

**目录结构：**
```
plugins/tcp_smart_router/
├── tcp_smart_router.lua
├── README.md
└── nginx.conf.example

test/dt/tcp_smart_router/
├── basic.t
└── protocol.t
```

**插件代码：**

```lua
--[[
插件名称: tcp_smart_router
版本: 1.0.0
类型: stream
功能: 基于协议识别的 TCP 智能路由

数据格式:
  - upstreams: table - 协议到上游的映射
    - redis: string - Redis 协议上游地址
    - http: string - HTTP 协议上游地址
  - default_upstream: string - 默认上游地址
  - timeout: number - 超时时间（毫秒，默认: 30000）
]]

local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG
local ctx = ngx.ctx
local re = ngx.re
local socket = ngx.socket

local _M = {
    _VERSION = "1.0.0",
    _NAME = "tcp_smart_router"
}

local config = {}

-- 协议识别（基于首字节/首行特征）
local function detect_protocol(data)
    if not data or #data < 1 then return nil end

    -- Redis: 以 * 开头（RESP 协议）
    if data:sub(1, 1) == "*" then return "redis" end

    -- HTTP: 以 HTTP 方法开头
    if re.match(data, "^(GET|POST|PUT|DELETE|HEAD|OPTIONS|PATCH) ", "jo") then
        return "http"
    end

    -- MySQL: 以 0x0a (greeting packet) 开头
    if #data >= 5 and data:byte(1) == 0x0a then
        return "mysql"
    end

    return nil
end

-- 公共接口
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

-- Stream 接口
function _M.preread()
    local sock = ngx.req.socket()
    sock:settimeout(1000)  -- 1 秒识别超时

    -- 只读取必要的协议识别数据
    local data, err = sock:receiveany(256)
    if not data then
        log(ERR, "[", _M._NAME, "] receive failed: ", err)
        return false, "receive failed: " .. (err or "unknown")
    end

    -- 保存预读数据供 content 使用
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

    -- 连接上游（非阻塞）
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

    -- 双向数据转发
    local client = ngx.req.socket()
    local function forward(src, dst)
        while true do
            local data, err = src:receiveany(8192)
            if not data then break end
            if not dst:send(data) then break end
        end
    end

    local th1 = ngx.thread.spawn(forward, client, upstream)
    local th2 = ngx.thread.spawn(forward, upstream, client)
    ngx.thread.wait(th1, th2)

    upstream:close()
end

return _M
```

**README.md：**

```markdown
# tcp_smart_router

基于协议识别的 TCP 智能路由插件。

## 功能说明

通过分析 TCP 连接的初始数据，识别协议类型（Redis/HTTP/MySQL 等），
自动路由到对应的上游服务器。

## 数据格式

### 配置项

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| upstreams | table | 否 | {} | 协议到上游的映射 |
| default_upstream | string | 是 | - | 默认上游地址 |
| timeout | number | 否 | 30000 | 超时时间（毫秒） |

### upstreams 配置

| 字段 | 类型 | 说明 |
|------|------|------|
| redis | string | Redis 协议上游地址 |
| http | string | HTTP 协议上游地址 |
| mysql | string | MySQL 协议上游地址 |

### 示例数据

```lua
{
    upstreams = {
        redis = "192.168.1.10:6379",
        http = "192.168.1.20:80",
        mysql = "192.168.1.30:3306"
    },
    default_upstream = "192.168.100.10:8080",
    timeout = 30000
}
```

## 支持的协议

| 协议 | 识别特征 |
|------|----------|
| Redis | 首字符 `*` (RESP 协议) |
| HTTP | 首行为 HTTP 方法 |
| MySQL | 首字节 `0x0a` (greeting packet) |

## 使用示例

### nginx.conf

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

### 测试验证

```bash
# 测试 Redis 协议
redis-cli -p 3300 PING
# 预期: 路由到 192.168.1.10:6379

# 测试 HTTP 协议
curl http://localhost:3300/api/test
# 预期: 路由到 192.168.1.20:80
```
```

**nginx.conf.example：**

```nginx
# tcp_smart_router 示例配置
# 放置于 stream 块内

lua_package_path "/path/to/plugins/?.lua;;";

# 初始化插件
init_worker_by_lua_block {
    local plugin = require "tcp_smart_router"
    local ok, err = plugin.init_worker({
        upstreams = {
            redis = "192.168.1.10:6379",
            http = "192.168.1.20:80",
            mysql = "192.168.1.30:3306"
        },
        default_upstream = "192.168.100.10:8080",
        timeout = 30000
    })
    if not ok then
        ngx.log(ngx.ERR, "plugin init failed: ", err)
    end
}

# 多协议代理入口
server {
    listen 3300;

    # 协议识别
    preread_by_lua_block {
        require("tcp_smart_router").preread()
    }

    # 数据转发
    content_by_lua_block {
        require("tcp_smart_router").content()
    }
}
```