---
name: openresty-lua-plugins
description: 使用 Lua 语言基于 OpenResty 框架生成 HTTP 或 TCP/UDP 插件。当用户需要开发 OpenResty Lua 插件、Nginx Lua 模块、HTTP/TCP/UDP 代理插件、API 网关插件时使用此 skill。
---

# OpenResty Lua 插件生成器

生成单个独立的 Lua 模块文件，支持 HTTP 和 Stream (TCP/UDP) 两种模式。

## 重要提示

**在决定开发插件之前，优先考虑以下方案：**

1. **Nginx 原生配置** - 许多功能可以通过 Nginx 配置直接实现：
   - 静态路由、反向代理 → `proxy_pass`
   - 负载均衡 → `upstream` + `proxy_pass`
   - 访问控制 → `allow`/`deny`
   - 限流 → `limit_req`/`limit_conn`
   - 缓存 → `proxy_cache`
   - 重定向 → `return`/`rewrite`
   - 头部操作 → `add_header`/`proxy_set_header`

2. **Nginx 内置变量** - 通过 `$variable` 实现动态逻辑

3. **现有 OpenResty 模块** - 使用成熟的 lua-resty-* 库

**仅当以上方案无法满足需求时，才考虑开发自定义插件。**

## 执行步骤

### 1. 收集插件需求

询问用户以下信息：

| 信息 | 说明 | 示例 |
|------|------|------|
| 插件名称 | 模块名，使用小写字母和下划线 | `phone_router` |
| 插件类型 | `http` 或 `stream` | `http` |
| 功能描述 | 插件要实现的功能 | 根据手机号路由 |
| 自定义数据 | JSON 格式的配置项定义 | 见下方示例 |

根据用户描述的功能，**自动判断**需要实现哪些接口，无需用户手动选择。

### 2. 自定义数据格式

```json
{
  "ranges": {
    "type": "array",
    "description": "号码区间配置",
    "items": {
      "min": "string",
      "max": "string",
      "upstream": "string"
    }
  },
  "default_upstream": {
    "type": "string",
    "default": "default_backend"
  }
}
```

### 3. 生成插件

根据插件类型加载详细文档：
- HTTP 插件 → 参考 `references/http.md`
- Stream 插件 → 参考 `references/stream.md`

---

## 公共开发接口

所有插件（HTTP 和 Stream）共享以下接口。**仅实现必需的接口，非必需接口不要定义。**

### init

| 属性 | 说明 |
|------|------|
| 用途 | Master 进程初始化 |
| 是否必需定义 | 仅当需要全局初始化时定义 |
| 阶段 | `init_by_lua*` |

**入参：** 无

**返回值：**

| 序号 | 类型 | 说明 |
|------|------|------|
| 1 | boolean | 成功返回 `true`，失败返回 `false` |
| 2 | string | 失败时返回错误信息 |

---

### init_worker

| 属性 | 说明 |
|------|------|
| 用途 | Worker 进程初始化，加载配置 |
| 是否必需定义 | 通常需要定义（用于接收配置） |
| 阶段 | `init_worker_by_lua*` |

**入参：**

| 序号 | 名称 | 类型 | 说明 |
|------|------|------|------|
| 1 | data | table | 用户自定义数据 |

**返回值：**

| 序号 | 类型 | 说明 |
|------|------|------|
| 1 | boolean | 成功返回 `true`，失败返回 `false` |
| 2 | string | 失败时返回错误信息 |

---

### exit_worker

| 属性 | 说明 |
|------|------|
| 用途 | Worker 退出清理 |
| 是否必需定义 | 仅当需要资源清理时定义 |
| 阶段 | `exit_worker_by_lua*` |

**入参：** 无

**返回值：** 无

---

## 编码规范

### ngx 变量 local 化

在模块开头将 `ngx.*` 变量 local 化，提升性能：

```lua
-- ✓ 正确：模块顶部 local 化
local ngx = ngx
local log = ngx.log
local INFO = ngx.INFO
local ERR = ngx.ERR
local var = ngx.var
local req = ngx.req
local header = ngx.header
local exit = ngx.exit
local ctx = ngx.ctx
local now = ngx.now

-- ✗ 错误：直接使用 ngx.*
function _M.handler()
    ngx.log(ngx.ERR, "error")  -- 性能较差
end
```

### 日志记录

直接使用 `ngx.log`，不要封装 log 函数：

```lua
-- ✓ 正确：直接调用
log(ERR, "[plugin_name] error message")

-- ✗ 错误：封装 log 函数
local function log(level, ...)
    ngx.log(level, "[plugin_name] ", ...)
end
```

### 配置存储

使用模块级 local 变量存储配置，无需共享内存：

```lua
-- ✓ 正确：local 变量存储配置
local config = {}

function _M.init_worker(data)
    config = data  -- Worker 级别共享
    return true
end

-- ✗ 错误：不必要的共享内存
function _M.init_worker(data)
    local dict = ngx.shared.plugin_dict
    dict:set("config", cjson.encode(data))
end
```

### 共享内存使用场景

仅在以下场景使用 `ngx.shared.DICT`：
- 需要跨 Worker 共享数据
- 需要持久化限流计数器
- 需要缓存外部数据

### 禁止的阻塞操作

| 禁止项 | 替代方案 |
|--------|----------|
| `io.open`、文件 I/O | `ngx.shared.DICT` |
| `os.execute` | `ngx.socket` 或 `resty.shell` |
| `socket.tcp`（LuaSocket） | `ngx.socket.tcp` |
| 阻塞数据库驱动 | `lua-resty-*` 库 |

### 返回值规范

有返回值的函数，失败时必须返回错误信息：

```lua
-- ✓ 正确
if not data then
    return false, "data is nil"
end

-- ✗ 错误
if not data then
    return false
end
```

---

## 插件模板

```lua
--[[
插件名称: {plugin_name}
版本: 1.0.0
类型: {http|stream}
功能: {功能描述}
]]

------------------------------------------------------------------------------
-- ngx 变量 local 化
------------------------------------------------------------------------------
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local var = ngx.var
local ctx = ngx.ctx
local req = ngx.req
local header = ngx.header

------------------------------------------------------------------------------
-- 模块定义
------------------------------------------------------------------------------
local _M = {
    _VERSION = "1.0.0",
    _NAME = "{plugin_name}"
}

-- 配置存储
local config = {}

------------------------------------------------------------------------------
-- 公共接口（仅定义必需的）
------------------------------------------------------------------------------
function _M.init_worker(data)
    if not data then
        return false, "data is nil"
    end

    config = data
    log(INFO, "[", _M._NAME, "] initialized")
    return true
end

------------------------------------------------------------------------------
-- HTTP/Stream 接口（根据需要定义）
------------------------------------------------------------------------------

return _M
```

---

## 详细文档

- **HTTP 插件**：`references/http.md`
- **Stream 插件**：`references/stream.md`