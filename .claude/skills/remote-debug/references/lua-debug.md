# Lua 调试技巧

本文档提供 OpenResty Lua 模块的调试技巧和最佳实践。

## 日志调试

### 使用 ngx.log

```lua
-- 不同级别的日志
ngx.log(ngx.ERR, "错误信息: ", err)
ngx.log(ngx.WARN, "警告信息")
ngx.log(ngx.INFO, "普通信息")
ngx.log(ngx.DEBUG, "调试信息")

-- 格式化输出
ngx.log(ngx.ERR, string.format("值: %s, 类型: %s", value, type(value)))
```

### 条件日志

```lua
-- 开发环境启用调试日志
local DEBUG = os.getenv("DEBUG") == "true"

local function log_debug(...)
    if DEBUG then
        ngx.log(ngx.DEBUG, ...)
    end
end

log_debug("调试信息，仅开发环境可见")
```

## 错误处理

### pcall 和 xpcall

```lua
-- 安全执行代码
local ok, err = pcall(function()
    -- 可能出错的代码
    local result = some_function()
    return result
end)

if not ok then
    ngx.log(ngx.ERR, "执行失败: ", err)
end

-- 带追踪的错误处理
local function error_handler(err)
    return debug.traceback(err, 2)
end

local ok, result = xpcall(function()
    return risky_function()
end, error_handler)

if not ok then
    ngx.log(ngx.ERR, "错误追踪:\n", result)
end
```

### assert 和 error

```lua
-- 参数检查
local function process(data)
    assert(type(data) == "table", "data must be a table")
    assert(data.id, "data.id is required")
    -- ...
end

-- 自定义错误
if not valid then
    error("validation failed: " .. reason, 2)
end
```

## 调试工具

### resty CLI

```bash
# 执行 Lua 代码片段
resty -e 'print(ngx.now())'

# 加载模块
resty -e 'local json = require "cjson"; print(json.encode({a=1}))'

# 运行脚本
resty script.lua
```

### 在线调试

```lua
-- 通过 HTTP 接口执行代码（仅开发环境！）
if ngx.var.arg_debug then
    local code = ngx.var.arg_code
    if code then
        local fn, err = loadstring(code)
        if fn then
            local ok, result = pcall(fn)
            ngx.say(ok and result or "Error: " .. result)
        else
            ngx.say("Compile error: ", err)
        end
    end
end
```

## 状态检查

### 查看变量

```lua
-- 打印表结构
local function dump_table(t, indent)
    indent = indent or ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indent .. k .. ":")
            dump_table(v, indent .. "  ")
        else
            print(indent .. k .. " = " .. tostring(v))
        end
    end
end

-- 使用 cjson 序列化
local cjson = require "cjson"
print(cjson.encode(data))
```

### 请求信息

```lua
-- 打印请求信息
ngx.log(ngx.DEBUG, "URI: ", ngx.var.uri)
ngx.log(ngx.DEBUG, "Method: ", ngx.var.request_method)
ngx.log(ngx.DEBUG, "Args: ", ngx.var.args)
ngx.log(ngx.DEBUG, "Headers: ", cjson.encode(ngx.req.get_headers()))
ngx.log(ngx.DEBUG, "Body: ", ngx.req.get_body_data())
```

### 共享字典

```lua
-- 遍历共享字典
local dict = ngx.shared.mycache
local keys = dict:get_keys(100)

for i, key in ipairs(keys) do
    local value, flags = dict:get(key)
    ngx.log(ngx.DEBUG, key, " = ", value, " (flags: ", flags, ")")
end

-- 获取字典统计
if dict.capacity then
    ngx.log(ngx.DEBUG, "容量: ", dict:capacity())
    ngx.log(ngx.DEBUG, "空闲: ", dict:free_space())
end
```

## 性能调试

### 计时

```lua
-- 简单计时
local start = ngx.now()
-- ... 代码块 ...
local elapsed = ngx.now() - start
ngx.log(ngx.DEBUG, "耗时: ", elapsed, "s")

-- 更精确的计时
local start = ngx.req.start_time()
local elapsed = ngx.now() - start
```

### 内存使用

```lua
-- 检查 Lua 内存使用
local collectgarbage = collectgarbage
ngx.log(ngx.DEBUG, "Lua 内存: ", collectgarbage("count"), " KB")

-- 触发垃圾回收
collectgarbage("collect")
```

### 分析热点

```lua
-- 使用 LuaProfiler
local profiler = require "profiler"
profiler.start()

-- ... 代码 ...

profiler.stop()
profiler.report("profile.txt")
```

## 常见问题调试

### nil 值问题

```lua
-- 防御性编程
local function safe_get(t, ...)
    local current = t
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if type(current) ~= "table" then
            return nil, "not a table at level " .. i
        end
        current = current[key]
        if current == nil then
            return nil, "nil at key: " .. tostring(key)
        end
    end
    return current
end

local value = safe_get(config, "http", "server", "port") or 80
```

### 协程问题

```lua
-- 检查是否在协程中
if not ngx then
    error("必须在 OpenResty 环境中运行")
end

-- 检查是否可以 yield
local ok, err = ngx.on_abort(function()
    ngx.log(ngx.DEBUG, "请求被中断")
end)

if not ok then
    ngx.log(ngx.WARN, "无法设置中断回调: ", err)
end
```

### 连接池问题

```lua
-- 检查连接池状态
local mysql = require "resty.mysql"
local db, err = mysql:new()
db:set_timeout(1000)

local ok, err, errcode, sqlstate = db:connect{
    host = "127.0.0.1",
    port = 3306,
    database = "test",
    user = "root",
    password = "",
    pool_size = 10,  -- 连接池大小
}

-- 记录连接状态
ngx.log(ngx.DEBUG, "MySQL 连接: ", ok and "成功" or "失败: " .. err)
```

## 测试和断言

### 测试框架

```lua
-- 简单测试框架
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("[PASS] " .. name)
    else
        print("[FAIL] " .. name .. ": " .. err)
    end
end

test("add function", function()
    assert(add(1, 2) == 3)
    assert(add(-1, 1) == 0)
end)
```

### Mock 对象

```lua
-- 创建 mock ngx 对象
local mock_ngx = {
    log = function(level, ...)
        print("[LOG] " .. table.concat({...}, " "))
    end,
    var = {
        uri = "/test",
        request_method = "GET",
    },
    now = function() return os.time() end,
    shared = {
        cache = {
            get = function(self, key) return nil end,
            set = function(self, key, value) return true end,
        }
    }
}

-- 替换全局 ngx
local original_ngx = _G.ngx
_G.ngx = mock_ngx

-- 测试完成后恢复
-- _G.ngx = original_ngx
```

## 调试命令速查

| 命令 | 说明 |
|------|------|
| `ngx.log(ngx.ERR, ...)` | 记录错误日志 |
| `print(...)` | 输出到 stdout |
| `debug.traceback()` | 获取调用栈 |
| `type(v)` | 检查类型 |
| `tostring(v)` | 转字符串 |
| `pairs(t)` / `ipairs(t)` | 遍历表 |
| `pcall(fn)` | 安全调用 |
| `resty -e 'code'` | 命令行执行 |

## 注意事项

1. **避免在日志中输出敏感信息**
2. **DEBUG 日志级别在生产环境不输出**
3. **注意协程中变量的作用域**
4. **定期检查共享字典大小**
5. **使用连接池避免频繁创建连接**