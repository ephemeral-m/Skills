---
name: dev
description: 统一开发命令入口，零 Token 消耗执行 build/test/start/stop 等工程任务。当用户需要构建项目、运行测试、启动/停止服务、查看项目状态、同步代码到远程服务器时使用此 skill。
---

# dev Slash Command

统一开发命令入口，零 Token 消耗执行 build/test/start/stop 等工程任务。

## 跨平台开发模式

```
┌─────────────────────────────────────────────────────────────────┐
│                    Windows 本地环境                              │
│  - 代码编辑                                                      │
│  - Git 版本管理                                                  │
│  - 执行 /dev 命令                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                        SSH (paramiko)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Linux 远程环境                                │
│  - 所有 Shell 脚本实际执行                                        │
│  - OpenResty 构建/运行                                           │
│  - 测试/服务管理                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**重要：所有命令都在远程 Linux 服务器上执行，不要在 Windows 本地直接运行 Shell 脚本。**

## 用法

```
/dev all [module]              # 执行完整流水线 (sync → build → start → test)
/dev all [module] -c           # 失败时继续执行后续步骤
/dev build [module]            # 编译指定模块或全部
/dev test [module]             # 测试指定模块或全部
/dev test --dt [file]          # 运行 Test::Nginx 测试用例
/dev start                     # 启动服务（远程）
/dev stop                      # 停止服务（远程）
/dev sync                      # 同步代码到远程服务器
/dev status                    # 查看项目状态
/dev analyze <type> [file]     # 分析错误输出
```

## Pipeline 流水线

`/dev all` 执行完整开发流程:

```
sync → build → start → test
  │       │       │      │
  └───────┴───────┴──────┴── 失败时自动分析错误
```

失败时会:
1. 匹配预制的 YAML 错误规则
2. 输出修复建议
3. 提示调用对应的 `/fix-*` skill

### 参数

- `module`: 指定模块名，不指定则执行全部模块
- `-c, --continue-on-error`: 失败时继续执行后续步骤

### 服务管理

- `/dev start`: 启动远程开发服务 (负载均衡 + web-admin)
- `/dev stop`: 停止远程开发服务

**注意：** 服务启动/停止在远程 Linux 执行，由 `tools/scripts/start.sh` 和 `tools/scripts/stop.sh` 封装。

## 测试说明

- `--dt` 参数运行 `test/dt/` 目录下的 Test::Nginx 测试用例
- 支持多种指定方式：
  - `/dev test --dt` - 运行所有测试
  - `/dev test --dt phone_range_router/basic` - 运行指定插件目录下的测试
  - `/dev test --dt phone_range_router_basic.t` - 兼容旧格式

## 错误分析

渐进式加载错误规则，零 Token 消耗:

| 阶段 | 规则文件 | 说明 |
|------|----------|------|
| compile | `tools/fixers/compile/*.yaml` | 编译错误 |
| runtime | `tools/fixers/runtime/*.yaml` | 运行时错误 |
| test | `tools/fixers/test/*.yaml` | 测试失败 |

使用 `/dev analyze` 手动分析错误输出:
```
/dev analyze compile              # 分析最新的编译结果
/dev analyze runtime test-dt.json # 分析指定文件
```

## 流程

1. 解析用户命令和参数
2. 通过 SSH 连接远程服务器
3. 执行 `tools/bin/dev` Python 脚本
4. 远程执行对应的 Shell 脚本
5. 返回执行结果
6. 如果失败，输出结构化错误并建议修复 Skill

## 常见问题

### 在 Windows 上直接运行脚本失败

```
错误: bash: command not found
原因: 在 Windows 本地运行 Shell 脚本
解决: 使用 /dev 命令在远程执行
```

### 代码修改后不生效

```
原因: 未同步代码到远程
解决: 执行 /dev sync 或 /dev all
```

### 中文文件名乱码

```
原因: Windows/Linux 编码差异
解决: 已在 dev CLI 中使用 UTF-8 编码
```

## 相关文件

| 文件 | 说明 |
|------|------|
| `tools/bin/dev` | Python CLI 主程序（本地执行）|
| `tools/scripts/*.sh` | Shell 脚本（远程执行）|
| `tools/config/dev.yaml` | 项目配置（含远程服务器信息）|
| `tools/results/*.json` | 构建结果 |
| `tools/fixers/**/*.yaml` | 错误规则定义 |
| `test/dt/*.t` | Test::Nginx 测试用例 |

## 远程服务器配置

配置文件 `tools/config/dev.yaml`:

```yaml
remote:
  host: 192.168.168.218
  port: 22
  user: m30020610
  password: 123456
  workdir: /home/m30020610/Skills
```