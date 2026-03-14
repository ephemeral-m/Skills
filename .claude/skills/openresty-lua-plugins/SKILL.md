---
name: openresty-lua-plugins
description: 使用 Lua 语言基于 OpenResty 框架生成 HTTP 或 TCP/UDP 插件。当用户需要开发 OpenResty Lua 插件、Nginx Lua 模块、HTTP/TCP/UDP 代理插件、API 网关插件、请求处理、流量控制、负载均衡逻辑时使用此 skill。
---

# OpenResty Lua 插件生成器

生成单个独立的 Lua 模块文件，支持 HTTP 和 Stream (TCP/UDP) 两种模式。

## 执行步骤

### 1. 收集插件需求

| 信息 | 说明 | 示例 |
|------|------|------|
| 插件名称 | 模块名，小写字母和下划线 | `phone_router` |
| 插件类型 | `http` 或 `stream` | `http` |
| 功能描述 | 插件要实现的功能 | 根据手机号路由 |
| 自定义数据 | JSON 格式的配置项定义 | 见下方示例 |

### 2. 自定义数据格式

```json
{
  "ranges": {
    "type": "array",
    "description": "号码区间配置",
    "items": { "min": "string", "max": "string", "upstream": "string" }
  },
  "default_upstream": { "type": "string", "default": "default_backend" }
}
```

### 3. 加载详细文档

- HTTP 插件 → 参考 `references/http.md`
- Stream 插件 → 参考 `references/stream.md`

## 优先方案

开发插件前，优先考虑：

1. **Nginx 原生配置** - `proxy_pass`、`upstream`、`limit_req`、`proxy_cache`
2. **Nginx 内置变量** - 通过 `$variable` 实现动态逻辑
3. **现有模块** - lua-resty-* 库

## 公共开发接口

仅实现必需的接口：

| 接口 | 阶段 | 必需性 |
|------|------|--------|
| `init()` | init_by_lua* | 仅全局初始化时 |
| `init_worker(data)` | init_worker_by_lua* | 通常需要 |
| `exit_worker()` | exit_worker_by_lua* | 仅需清理时 |

**init_worker 入参:** `data` (table) - 用户自定义数据
**返回值:** `boolean, string?` - 成功/失败+错误信息

## 编码规范

### ngx 变量 local 化

```lua
-- 模块顶部
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local var = ngx.var
```

### 日志记录

```lua
log(ERR, "[plugin_name] error message")
```

### 配置存储

```lua
local config = {}

function _M.init_worker(data)
    config = data  -- Worker 级别共享
    return true
end
```

### 禁止的阻塞操作

| 禁止项 | 替代方案 |
|--------|----------|
| `io.open` | `ngx.shared.DICT` |
| `os.execute` | `ngx.socket` / `resty.shell` |
| `socket.tcp` (LuaSocket) | `ngx.socket.tcp` |

## 插件模板

```lua
--[[
插件名称: {plugin_name}
版本: 1.0.0
类型: {http|stream}
功能: {功能描述}
]]

local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local _M = { _VERSION = "1.0.0", _NAME = "{plugin_name}" }
local config = {}

function _M.init_worker(data)
    if not data then return false, "data is nil" end
    config = data
    log(INFO, "[", _M._NAME, "] initialized")
    return true
end

return _M
```

## 详细文档

- HTTP 插件: `references/http.md`
- Stream 插件: `references/stream.md`