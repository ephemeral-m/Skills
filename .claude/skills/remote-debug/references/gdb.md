# GDB 常用命令参考

本文档提供 GDB 调试 Nginx/OpenResty 进程的常用命令参考。

## 基础操作

### 附加到进程

```bash
# 附加到运行中的进程
gdb -p <PID>

# 使用 batch 模式（非交互）
gdb -batch -ex "bt" -p <PID>
```

### 常用命令

| 命令 | 缩写 | 说明 |
|------|------|------|
| `backtrace` | `bt` | 显示调用栈 |
| `thread apply all bt` | | 显示所有线程调用栈 |
| `info threads` | | 列出所有线程 |
| `thread <n>` | | 切换到线程 n |
| `frame <n>` | `f` | 切换到栈帧 n |
| `list` | `l` | 显示源代码 |
| `print <var>` | `p` | 打印变量值 |
| `info locals` | | 显示局部变量 |
| `info args` | | 显示函数参数 |
| `detach` | | 分离进程（恢复运行） |
| `quit` | `q` | 退出 GDB |

## Nginx 调试技巧

### 查看所有线程调用栈

```gdb
set pagination off
thread apply all bt full
```

### 查看请求相关结构

```gdb
# 在请求处理函数中
p *r                    # 打印请求结构
p r->uri                # 打印 URI
p r->method_name        # 打印请求方法
p r->headers_in         # 打印请求头
```

### 查看 Lua 状态

```gdb
# 需要 LuaJIT 调试符号
p *L                    # 打印 Lua 状态
call lua_gettop(L)      # 获取栈顶
```

### 内存相关

```gdb
# 查看内存映射
info proc mappings

# 查看内存内容
x/100xb <address>       # 以十六进制显示 100 字节

# 查看字符串
x/s <address>
```

## Core Dump 分析

### 分析 Core Dump 文件

```bash
gdb <executable> <core-file>

# 常用命令
(gdb) bt full           # 完整调用栈
(gdb) info threads      # 线程信息
(gdb) thread apply all bt  # 所有线程调用栈
```

### 定位崩溃原因

```gdb
# 查看崩溃时的寄存器
info registers

# 查看崩溃地址附近的代码
x/10i $pc

# 查看崩溃时的信号
info signal
```

## 断点和监视

### 设置断点

```gdb
break <function>       # 函数断点
break <file>:<line>    # 行断点
break *<address>       # 地址断点

# 条件断点
break <function> if <condition>

# 查看断点
info breakpoints

# 删除断点
delete <n>
```

### 监视点

```gdb
watch <variable>       # 监视变量变化
rwatch <variable>      # 监视变量读取
awatch <variable>      # 监视变量读写
```

## 性能分析

### 函数调用统计

```gdb
# 使用 record 捕获执行
record
continue
# ... 执行一段时间后
stop
info record

# 查看函数调用
backtrace
```

### 内存泄漏检测

GDB 本身不直接支持内存泄漏检测，但可以：

1. 使用 Valgrind 运行 nginx
2. 使用 AddressSanitizer 编译
3. 使用 `mtrace` 跟踪内存分配

## 实用脚本

### 快速查看调用栈

```bash
#!/bin/bash
# gdb-bt.sh <PID>
PID=$1
gdb -batch \
    -ex "set pagination off" \
    -ex "thread apply all bt" \
    -p $PID
```

### 分析所有 Core Dump

```bash
#!/bin/bash
# gdb-core.sh <executable> <core-dir>
EXEC=$1
CORE_DIR=$2

for core in $CORE_DIR/core*; do
    echo "=== $core ==="
    gdb -batch -ex "bt full" $EXEC $core
done
```

### 监视进程状态

```bash
#!/bin/bash
# watch-process.sh <PID>
PID=$1

while true; do
    echo "=== $(date) ==="
    gdb -batch -ex "info threads" -p $PID 2>/dev/null
    sleep 5
done
```

## 调试 OpenResty 特定问题

### Lua 协程问题

OpenResty 使用 Lua 协程处理请求，调试时注意：

1. 每个请求可能对应不同的 Lua 协程
2. 协程切换由 OpenResty 调度
3. 查看 `ngx.ctx` 需要正确的请求上下文

### 共享字典调试

```lua
-- 在 Lua 代码中添加调试输出
local dict = ngx.shared.mycache
local keys = dict:get_keys(0)
for i, key in ipairs(keys) do
    ngx.log(ngx.ERR, "dict[", key, "] = ", dict:get(key))
end
```

### 连接池问题

```gdb
# 查看连接池状态
# 需要 OpenResty 调试符号
p *ngx_http_upstream_main_conf_t
```

## 注意事项

1. **生产环境慎用断点**：会导致进程暂停
2. **使用 batch 模式**：避免交互式暂停
3. **权限要求**：可能需要 root 或 ptrace 权限
4. **调试符号**：确保编译时包含 `-g` 选项
5. **Core Dump 大小**：可能很大，注意磁盘空间