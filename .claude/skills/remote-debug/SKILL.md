---
name: remote-debug
description: 远程调试 Skill，支持 C 模块和 Lua 模块的远程调试。当用户需要调试远程 Linux 服务器上的 OpenResty/Nginx 进程、查看日志、分析 Core Dump、检查 Lua 模块状态时使用此 skill。
---

# remote-debug Slash Command

远程调试 Skill，支持 C 模块和 Lua 模块的远程调试。

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Windows 本地环境                              │
│  - 执行 /debug 命令                                              │
│  - 查看调试输出和日志                                            │
│  - 分析 core dump 和调用栈                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                        SSH (paramiko)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Linux 远程环境                                │
│  - GDB 调试 C 模块                                               │
│  - Lua 调试工具                                                  │
│  - 日志收集和分析                                                │
│  - Core dump 处理                                                │
└─────────────────────────────────────────────────────────────────┘
```

## 用法

```
/debug log [options]              # 日志调试
/debug c [options]                # C 模块调试
/debug lua [options]              # Lua 模块调试
/debug status                     # 调试状态概览
```

## 日志调试 (log)

```
/debug log --type <type>          # error|access|stream (默认 error)
/debug log --level <level>        # debug|info|warn|error
/debug log --follow               # 实时跟踪 (tail -f) - 后台运行
/debug log --grep <pattern>       # 关键词过滤
/debug log --lines <n>            # 显示行数 (默认 50)
```

示例:
```
/debug log                          # 查看最近的 error 日志
/debug log --type access --lines 100
/debug log --follow                 # 实时跟踪 error.log
/debug log --grep "lua"             # 过滤包含 "lua" 的日志
```

## C 模块调试 (c)

```
/debug c --attach                  # 附加到运行进程（交互模式）
/debug c --bt                      # 显示所有线程调用栈
/debug c --info                    # 查看进程信息（内存、线程数等）
/debug c --core [dir]              # 分析 core dump（可选指定目录）
```

示例:
```
/debug c --info                     # 查看 nginx 进程信息
/debug c --bt                       # 显示所有线程调用栈
/debug c --core                     # 分析最近的 core dump
/debug c --core /var/crash          # 指定目录搜索 core dump
```

### 在线调试风险

**警告：GDB 附加会暂停进程执行，影响生产流量**

- 建议在低流量或测试环境使用
- 使用 `--bt` 快速查看后立即 detach
- 不要在生产环境设置断点

### Core Dump 配置

远程服务器需要配置 core dump：

```bash
# 查看当前配置
cat /proc/sys/kernel/core_pattern

# 临时启用（需要 root）
echo "/var/core/core.%e.%p" | sudo tee /proc/sys/kernel/core_pattern
ulimit -c unlimited
```

## Lua 模块调试 (lua)

```
/debug lua --errors                # 查看最近 Lua 错误
/debug lua --modules               # 查看已加载模块
/debug lua --eval <code>           # 执行 Lua 代码片段
/debug lua --dict <name>           # 查看共享字典内容
```

示例:
```
/debug lua --errors                 # 查看最近的 Lua 错误
/debug lua --eval "print(ngx.now())"
/debug lua --dict cache             # 查看 cache 共享字典
```

## 状态概览 (status)

```
/debug status                       # 显示调试状态概览
```

输出包括：
- 进程状态 (PID, 内存, CPU)
- 网络连接状态
- 日志文件位置
- Core dump 配置

## 流程

1. 解析用户命令和参数
2. 通过 SSH 连接远程服务器
3. 执行 `tools/bin/debug` Python 脚本
4. 远程执行对应的调试脚本
5. 返回格式化的调试输出

## 相关文件

| 文件 | 说明 |
|------|------|
| `tools/bin/debug` | Python CLI 主程序（本地执行）|
| `tools/scripts/debug/log.sh` | 日志调试脚本（远程执行）|
| `tools/scripts/debug/gdb.sh` | GDB 调试脚本（远程执行）|
| `tools/scripts/debug/lua.sh` | Lua 调试脚本（远程执行）|
| `tools/config/dev.yaml` | 项目配置（复用远程服务器信息）|

## 参考

- [GDB 常用命令参考](references/gdb.md)
- [Lua 调试技巧](references/lua-debug.md)