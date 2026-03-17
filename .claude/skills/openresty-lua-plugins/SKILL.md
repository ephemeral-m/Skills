---
name: openresty-lua-plugins
description: 使用 Lua 语言基于 OpenResty 框架生成 HTTP 或 TCP/UDP 插件。当用户需要开发 OpenResty Lua 插件、Nginx Lua 模块、HTTP/TCP/UDP 代理插件、API 网关插件、请求处理、流量控制、负载均衡逻辑时使用此 skill。
---

# OpenResty Lua 插件生成器

生成单个独立的 Lua 模块文件，支持 HTTP 和 Stream (TCP/UDP) 两种模式。

> **跨平台开发模式**: Windows 开发 + Linux 远程运行，详见 `/dev` skill 或项目 CLAUDE.md

## 插件开发流程

| 操作 | 执行位置 | 方式 |
|------|----------|------|
| 代码编辑 | Windows 本地 | IDE/编辑器 |
| 插件生成 | Windows 本地 | 此 SKILL |
| 构建测试 | Linux 远程 | `/dev build` / `/dev test --dt` |
| 服务运行 | Linux 远程 | `/dev run` |

```
1. 本地生成插件代码 (此 SKILL)
        ↓
2. 同步代码到远程 (/dev sync)
        ↓
3. 远程构建 (/dev build)
        ↓
4. 远程测试 (/dev test --dt)
        ↓
5. 远程运行 (/dev run)
```

**注意事项：**
- Lua 代码在 Windows 编辑，但必须在 Linux 上测试运行
- 测试用例 (Test::Nginx) 只能在 Linux 上执行
- 路径分隔符：Lua 代码中使用 `/`（Linux 风格）

## 设计原则

### 1. 优先使用 Nginx 原生配置

**始终优先考虑以下方案，仅在无法满足需求时才开发 Lua 插件：**

| 需求场景 | Nginx 原生方案 | 说明 |
|----------|----------------|------|
| 反向代理 | `proxy_pass` | 基础代理 |
| 负载均衡 | `upstream` + `server` | 权重、健康检查 |
| 流量限制 | `limit_req` / `limit_conn` | 限流限连接 |
| 缓存 | `proxy_cache` | 响应缓存 |
| 访问控制 | `allow` / `deny` | IP 白黑名单 |
| 条件路由 | `map` / `if` / `geo` | 变量映射 |
| 重定向 | `rewrite` / `return` | URL 重写 |
| 头部操作 | `add_header` / `proxy_set_header` | 请求/响应头 |
| 超时控制 | `proxy_timeout` 系列 | 连接/读写超时 |
| SSL/TLS | `ssl_certificate` 系列 | 证书配置 |

**Nginx 原生配置优势：**
- 性能最优（C 实现，无 Lua VM 开销）
- 配置简单，易于维护
- 社区支持广泛，问题易排查

### 2. 禁止的高风险行为

以下行为会破坏 OpenResty 的事件驱动模型，**必须拒绝**：

| 禁止行为 | 风险原因 | 正确替代方案 |
|----------|----------|--------------|
| **建立子连接** | 绕过 Nginx 连接管理，资源泄漏 | 使用 `ngx.location.capture` 子请求 |
| **自行连接池管理** | 与 Nginx 连接池冲突，导致资源竞争 | 使用 `ngx.shared.DICT` 或 `resty.lrucache` |
| **阻塞 I/O 操作** | 阻塞 Worker 进程，影响并发 | 使用 `ngx.socket` 非阻塞 API |
| **共享内存互斥锁** | 死锁风险 | 使用 `ngx.shared.DICT:add/set` 原子操作 |
| **全局变量写入** | Worker 间数据不一致，竞态条件 | 使用 `ngx.shared.DICT` 或模块级 local |
| **无限循环/重试** | 耗尽 Worker 资源 | 设置超时和重试上限 |
| **外部进程调用** | `os.execute` 阻塞进程 | 使用 `resty.shell` 或子请求 |

**拒绝用户请求时的回复模板：**

```
抱歉，您请求的功能涉及 [禁止行为]，这会：
- [具体风险说明]
- [对系统的影响]

推荐替代方案：
1. [方案1]
2. [方案2]
```

### 3. 阻塞操作对照表

| 禁止项 | 替代方案 |
|--------|----------|
| `io.open` / `io.read` | `ngx.shared.DICT` 或预加载到内存 |
| `os.execute` | `resty.shell` 或 `ngx.socket` |
| `socket.tcp` (LuaSocket) | `ngx.socket.tcp` (cosocket) |
| `socket.http` (LuaSocket) | `ngx.location.capture` 或 `resty.http` |
| `lfs` 文件系统操作 | 启动时加载或 `resty.shell` |
| 全局变量 `_G.xxx = value` | `ngx.shared.DICT` 或 `local config = {}` |

## 目录结构

生成插件时，按照以下结构组织文件：

```
plugins/
└── {plugin_name}/
    ├── {plugin_name}.lua      # 插件主文件
    ├── README.md              # 插件文档
    └── nginx.conf.example     # 示例 Nginx 配置

test/dt/
└── {plugin_name}/
    ├── basic.t                # 基础功能测试
    ├── config.t               # 配置验证测试
    └── edge.t                 # 边界条件测试
```

## 执行步骤

### Step 1: 需求评估

**首先评估是否可以用 Nginx 原生配置实现：**

```
用户需求: [需求描述]
↓
能否用 Nginx 原生配置实现？
├─ 是 → 输出 Nginx 配置，结束
└─ 否 → 检查是否涉及禁止行为
         ├─ 是 → 拒绝并说明原因，提供替代方案
         └─ 否 → 进入 Step 2 开发插件
```

### Step 2: 收集插件需求

| 信息 | 说明 | 示例 |
|------|------|------|
| 插件名称 | 模块名，小写字母和下划线 | `phone_router` |
| 插件类型 | `http` 或 `stream` | `http` |
| 功能描述 | 插件要实现的功能 | 根据手机号路由 |

### Step 3: 定义数据格式

**要求：明确每个字段的含义、类型、必填性和默认值**

```lua
-- 插件数据格式定义
local data_schema = {
    -- 字段名 = {类型, 必填, 默认值, 说明}
    ranges = {"table", true, nil, "号码区间配置数组"},
    default_upstream = {"string", false, "default_backend", "默认上游"},
    header_name = {"string", false, "phone-number", "请求头字段名"}
}

-- 区间配置格式
local range_schema = {
    min = {"string", true, nil, "起始号码（11位手机号）"},
    max = {"string", true, nil, "结束号码（11位手机号）"},
    upstream = {"string", true, nil, "目标上游名称"}
}
```

### Step 4: 加载详细文档

- HTTP 插件 → 参考 `references/http.md`
- Stream 插件 → 参考 `references/stream.md`

### Step 5: 生成完整产物

生成以下文件：

1. **插件 Lua 文件** - `plugins/{plugin_name}/{plugin_name}.lua`
2. **插件文档** - `plugins/{plugin_name}/README.md`
3. **示例配置** - `plugins/{plugin_name}/nginx.conf.example`
4. **DT 测试用例** - `test/dt/{plugin_name}/basic.t`

## 文档格式要求

生成的 `README.md` 必须包含：

```markdown
# {plugin_name}

## 功能说明

[一句话描述插件功能]

## 数据格式

### 配置项

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| ... | ... | ... | ... | ... |

### 示例数据

```lua
{
    ranges = {
        {min = "13000000000", max = "13999999999", upstream = "backend_a"},
        {min = "15000000000", max = "15999999999", upstream = "backend_b"}
    },
    default_upstream = "default_backend"
}
```

## 使用示例

### Nginx 配置

[完整的 nginx.conf 配置示例]

### 测试验证

```bash
# 发送测试请求
curl -H "phone-number: 13812345678" http://localhost/api/test
# 预期: 路由到 backend_a
```
```

## 测试用例要求

DT 测试用例必须验证：

1. **配置加载** - 正确/错误配置的加载结果
2. **基础功能** - 主要功能的正确性
3. **边界条件** - 空值、越界、异常输入

```perl
# basic.t 示例结构
=== TEST 1: 插件加载
--- http_config
[插件配置]
--- config
[location 配置]
--- request
GET /test
--- response_body
预期响应
--- no_error_log
[错误日志模式]
```

## 编码规范

### ngx 变量 local 化

```lua
-- 模块顶部
local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local req = ngx.req
local var = ngx.var
local ctx = ngx.ctx
```

### 日志记录

```lua
log(ERR, "[plugin_name] error message")
log(INFO, "[plugin_name] initialized with ", #config.ranges, " ranges")
```

### 配置验证

```lua
function _M.init_worker(data)
    if not data then
        return false, "data is nil"
    end

    -- 逐项验证
    for i, item in ipairs(data.items or {}) do
        if not item.required_field then
            return false, string.format("missing required_field at index %d", i)
        end
    end

    return true
end
```

## 公共开发接口

仅实现必需的接口：

| 接口 | 阶段 | 用途 |
|------|------|------|
| `init()` | init_by_lua* | 全局初始化（罕见） |
| `init_worker(data)` | init_worker_by_lua* | 加载配置（常用） |
| `exit_worker()` | exit_worker_by_lua* | 清理资源（罕见） |

**init_worker 入参:** `data` (table) - 用户自定义数据
**返回值:** `boolean, string?` - 成功/失败+错误信息

## 插件模板

```lua
--[[
插件名称: {plugin_name}
版本: 1.0.0
类型: {http|stream}
功能: {功能描述}

数据格式:
  - field1: {类型} - {说明}
  - field2: {类型} - {说明}
]]

local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO

local _M = { _VERSION = "1.0.0", _NAME = "{plugin_name}" }
local config = {}

function _M.init_worker(data)
    if not data then
        return false, "data is nil"
    end

    -- 验证并加载配置
    config = data
    log(INFO, "[", _M._NAME, "] initialized")
    return true
end

-- 其他接口按需实现

return _M
```

## 详细文档

- HTTP 插件: `references/http.md`
- Stream 插件: `references/stream.md`

## 常见陷阱与解决方案

### 1. Lua 模式匹配特殊字符

**问题描述：** Lua 的 `string.find`、`string.match` 等函数使用模式匹配而非正则表达式，某些字符有特殊含义。

**特殊字符列表：** `^$()%.[]*+-?`

**典型案例：** 匹配 Content-Type 失败

```lua
-- ❌ 错误：- 是非贪婪修饰符，不是字面字符
local found = string.find("application/x-www-form-urlencoded", "application/x-www-form-urlencoded")
-- 返回 nil！

-- ✅ 正确：使用 plain 模式（第4个参数为 true）
local found = string.find("application/x-www-form-urlencoded", "application/x-www-form-urlencoded", 1, true)
-- 返回 1
```

**最佳实践：**

| 场景 | 推荐方案 | 示例 |
|------|----------|------|
| 纯字符串匹配 | `string.find(s, pattern, 1, true)` | 检查 Content-Type |
| 需要模式匹配 | 转义特殊字符或使用 `ngx.re.match` | 提取字段值 |
| 复杂正则需求 | `ngx.re.match` (PCRE 语法) | JSON/表单解析 |

### 2. ngx.re.match 使用 PCRE 语法

**重要区别：** `ngx.re.match` 使用 PCRE 正则语法，与 Lua 模式语法不同。

```lua
-- ❌ 错误：使用 Lua 模式语法
ngx.re.match(body, '"field"%s*:%s*"([^"]*)"')  -- %s 是 Lua 语法

-- ✅ 正确：使用 PCRE 语法
ngx.re.match(body, '"field"\\s*:\\s*"([^"]*)"', "jo")  -- \\s 是 PCRE 语法
```

**常用 PCRE 语法对照：**

| Lua 模式 | PCRE 正则 | 说明 |
|----------|-----------|------|
| `%s` | `\\s` | 空白字符 |
| `%d` | `\\d` | 数字 |
| `%w` | `\\w` | 单词字符 |
| `.` | `.` | 任意字符 |
| `+` | `+` | 一个或多个 |
| `*` | `*` | 零个或多个 |
| `-` | `*?` | 非贪婪（含义不同！） |

**推荐选项：**
- `"jo"` - 编译缓存 + 大小写不敏感

### 3. Test::Nginx 测试用例计划数量

**问题描述：** Test2::API 版本不匹配可能导致测试计数异常。

**解决方案：**

```perl
# 方法1：动态计算测试数量
plan tests => repeat_each() * blocks() * 2;

# 方法2：固定数量（确保准确）
plan tests => repeat_each() * 9 * 2 + 1;

# 避免使用 no_plan 或缺少 plan
```

### 4. 请求体读取注意事项

**关键点：** 在 Test::Nginx 中需要正确配置请求体处理。

```nginx
# nginx 配置中需要
lua_need_request_body on;
client_body_buffer_size 1m;
```

```lua
-- Lua 代码中需要显式读取
ngx.req.read_body()
local body = ngx.req.get_body_data()
```

**注意：** `lua_need_request_body on` 与 `ngx.req.read_body()` 配合使用，确保请求体可用。