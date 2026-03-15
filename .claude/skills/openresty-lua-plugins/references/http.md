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

## 禁止的高风险行为

### 1. 禁止在请求处理阶段建立外部连接

```lua
-- ❌ 禁止：使用 LuaSocket（阻塞）
local socket = require("socket")
local sock = socket.tcp()
sock:connect("192.168.1.1", 80)  -- 阻塞 Worker 进程！

-- ❌ 禁止：自行管理连接池
local connection_pool = {}  -- 与 Nginx 连接池冲突

-- ✅ 正确：使用 cosocket（非阻塞）
local sock = ngx.socket.tcp()
sock:connect("192.168.1.1", 80)

-- ✅ 正确：使用子请求
local res = ngx.location.capture("/internal/upstream")
```

**原因：**
- 阻塞 I/O 会挂起 Worker 进程，影响所有并发请求
- 自行管理的连接池与 Nginx 事件循环冲突，导致资源泄漏

### 2. 禁止全局变量写入

```lua
-- ❌ 禁止：写入全局变量
_G.cache = {}
cache[key] = value  -- Worker 间数据不一致

-- ✅ 正确：使用共享字典
local dict = ngx.shared.cache
dict:set(key, value)

-- ✅ 正确：模块级 local 变量（只读配置）
local config = {}  -- init_worker 时加载，之后只读
```

**原因：**
- Nginx Worker 进程独立，全局变量无法共享
- 写入会导致竞态条件和数据不一致

### 3. 禁止阻塞操作

```lua
-- ❌ 禁止：文件 I/O
local file = io.open("/path/to/file", "r")  -- 阻塞！
local data = file:read("*a")

-- ❌ 禁止：执行外部命令
os.execute("curl http://api.example.com")  -- 阻塞！

-- ✅ 正确：启动时预加载
-- init_worker 中读取，存入 ngx.shared.DICT 或模块变量

-- ✅ 正确：使用 resty.shell（非阻塞）
local shell = require "resty.shell"
shell.run("curl", {"http://api.example.com"}, {timeout = 5000})
```

### 4. 禁止无限重试

```lua
-- ❌ 禁止：无限重试
while true do
    local ok = do_something()
    if ok then break end
end

-- ✅ 正确：限制重试次数
local max_retries = 3
for i = 1, max_retries do
    local ok = do_something()
    if ok then break end
    if i == max_retries then
        return false, "max retries exceeded"
    end
    ngx.sleep(0.1 * i)  -- 指数退避
end
```

## 开发接口

**仅实现必需的接口，非必需接口不要定义。**

### prerouting

| 属性 | 说明 |
|------|------|
| 用途 | 请求预处理：读取请求体、参数提取、白名单检查 |
| 阶段 | `rewrite_by_lua*` |

**入参：** `data` (table, 可选)

**返回值：**
- `true` - 允许继续
- `false, error_msg` - 拒绝请求

---

### postrouting

| 属性 | 说明 |
|------|------|
| 用途 | 路由决策、灰度发布、动态上游选择 |
| 阶段 | `access_by_lua*` |

**入参：** `data` (table, 可选)

**返回值：**
- `true` - 成功
- `false, error_msg` - 失败

---

### header_filter

| 属性 | 说明 |
|------|------|
| 用途 | 响应头修改 |
| 阶段 | `header_filter_by_lua*` |

**入参：** `data` (table, 可选)

**返回值：** 无

---

### body_filter

| 属性 | 说明 |
|------|------|
| 用途 | 响应体修改、数据脱敏 |
| 阶段 | `body_filter_by_lua*` |

**返回值：** 无（通过修改 `ngx.arg[1]` 改变输出）

---

## 功能映射表

| 功能关键词 | 推荐接口 | 优先考虑原生方案 |
|------------|----------|------------------|
| IP 白名单 | `prerouting` | `allow`/`deny` 指令 |
| 请求体解析 | `prerouting` | `lua_need_request_body` |
| 灰度发布 | `postrouting` | `split_clients` 指令 |
| 动态路由 | `postrouting` | `map` 指令 |
| 响应头修改 | `header_filter` | `add_header` 指令 |
| 响应体修改 | `body_filter` | `sub_filter` 指令 |

---

## 完整示例

### 手机号区间路由插件

**目录结构：**
```
plugins/phone_range_router/
├── phone_range_router.lua
├── README.md
└── nginx.conf.example

test/dt/phone_range_router/
├── basic.t
├── config.t
└── edge.t
```

**插件代码：**

```lua
--[[
插件名称: phone_range_router
版本: 1.0.0
类型: http
功能: 根据请求头 phone-number 字段值范围路由到不同后端

数据格式:
  - ranges: table[] - 号码区间配置
    - min: string - 起始号码（11位）
    - max: string - 结束号码（11位）
    - upstream: string - 目标上游名称
  - default_upstream: string - 默认上游（默认: default_backend）
  - header_name: string - 请求头字段名（默认: phone-number）
]]

local ngx = ngx
local log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local WARN = ngx.WARN
local DEBUG = ngx.DEBUG
local req = ngx.req
local re = ngx.re

local _M = {
    _VERSION = "1.0.0",
    _NAME = "phone_range_router"
}

local config = {}

-- 内部函数
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

-- 公共接口
function _M.init_worker(data)
    if not data then
        return false, "data is nil"
    end

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

    table.sort(ranges, function(a, b) return a.min_num < b.min_num end)

    config.ranges = ranges
    config.default_upstream = data.default_upstream or "default_backend"
    config.header_name = data.header_name or "phone-number"

    log(INFO, "[", _M._NAME, "] loaded ", #ranges, " ranges")
    return true
end

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
```

**README.md：**

```markdown
# phone_range_router

根据手机号区间路由到不同后端服务器。

## 功能说明

读取请求头中的手机号，根据配置的号段区间匹配对应的上游服务器。

## 数据格式

### 配置项

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| ranges | table[] | 是 | - | 号码区间配置数组 |
| default_upstream | string | 否 | default_backend | 默认上游 |
| header_name | string | 否 | phone-number | 请求头字段名 |

### range 配置

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| min | string | 是 | 起始号码（11位手机号） |
| max | string | 是 | 结束号码（11位手机号） |
| upstream | string | 是 | 目标上游名称 |

### 示例数据

```lua
{
    ranges = {
        {min = "13000000000", max = "13999999999", upstream = "backend_a"},
        {min = "15000000000", max = "15999999999", upstream = "backend_b"}
    },
    default_upstream = "default_backend",
    header_name = "phone-number"
}
```

## 使用示例

### nginx.conf

```nginx
http {
    lua_package_path "/path/to/plugins/?.lua;;";

    upstream backend_a { server 192.168.1.10:8080; }
    upstream backend_b { server 192.168.2.10:8080; }
    upstream default_backend { server 192.168.100.10:8080; }

    init_worker_by_lua_block {
        local plugin = require "phone_range_router.phone_range_router"
        plugin.init_worker({
            ranges = {
                {min = "13000000000", max = "13999999999", upstream = "backend_a"},
                {min = "15000000000", max = "15999999999", upstream = "backend_b"}
            },
            default_upstream = "default_backend"
        })
    }

    server {
        listen 80;
        set $upstream default_backend;

        location /api/ {
            rewrite_by_lua_block { require("phone_range_router.phone_range_router").prerouting() }
            access_by_lua_block { require("phone_range_router.phone_range_router").postrouting() }
            header_filter_by_lua_block { require("phone_range_router.phone_range_router").header_filter() }
            proxy_pass http://$upstream;
        }
    }
}
```

### 测试验证

```bash
# 130 号段 → backend_a
curl -H "phone-number: 13812345678" http://localhost/api/test
# 预期: X-Upstream: backend_a

# 150 号段 → backend_b
curl -H "phone-number: 15812345678" http://localhost/api/test
# 预期: X-Upstream: backend_b

# 其他号段 → default_backend
curl -H "phone-number: 18812345678" http://localhost/api/test
# 预期: X-Upstream: default_backend
```
```

**nginx.conf.example：**

```nginx
# phone_range_router 示例配置
# 放置于 http 块内

lua_package_path "/path/to/plugins/?.lua;;";

# 定义上游服务器
upstream backend_a {
    server 192.168.1.10:8080;
    keepalive 32;
}

upstream backend_b {
    server 192.168.2.10:8080;
    keepalive 32;
}

upstream default_backend {
    server 192.168.100.10:8080;
    keepalive 32;
}

# 初始化插件
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
        ngx.log(ngx.ERR, "plugin init failed: ", err)
    end
}

# 服务器配置
server {
    listen 80;
    server_name localhost;

    # 用于动态路由的变量
    set $upstream default_backend;

    location /api/ {
        # 请求预处理
        rewrite_by_lua_block {
            require("phone_range_router.phone_range_router").prerouting()
        }

        # 路由决策
        access_by_lua_block {
            require("phone_range_router.phone_range_router").postrouting()
        }

        # 响应头处理
        header_filter_by_lua_block {
            require("phone_range_router.phone_range_router").header_filter()
        }

        # 代理到选中的上游
        proxy_pass http://$upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```