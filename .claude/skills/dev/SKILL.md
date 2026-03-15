---
name: dev
description: 统一开发命令入口，零 Token 消耗执行 build/test/verify/clean 等工程任务。当用户需要构建项目、运行测试、验证代码、清理构建产物、查看项目状态、同步代码到远程服务器时使用此 skill。
---

# dev Slash Command

统一开发命令入口，零 Token 消耗执行 build/test/verify/clean 等工程任务。

## 用法

```
/dev all [module]              # 执行完整流水线 (sync → build → test)
/dev all [module] -c           # 失败时继续执行后续步骤
/dev build [module]            # 编译指定模块或全部
/dev test [module]             # 测试指定模块或全部
/dev test --dt [file]          # 运行 Test::Nginx 测试用例
/dev run                       # 启动服务
/dev stop                      # 停止服务
/dev sync                      # 同步代码到远程服务器
/dev status                    # 查看项目状态
/dev analyze <type> [file]     # 分析错误输出
```

## Pipeline 流水线

`/dev all` 执行完整开发流程:

```
sync → build → test
  │       │      │
  └───────┴──────┴── 失败时自动分析错误
```

失败时会:
1. 匹配预制的 YAML 错误规则
2. 输出修复建议
3. 提示调用对应的 `/fix-*` skill

### 参数

- `module`: 指定模块名，不指定则执行全部模块
- `-c, --continue-on-error`: 失败时继续执行后续步骤

### 服务管理

- `/dev run`: 启动本地开发服务（前台运行）
- `/dev stop`: 停止本地开发服务

服务启动/停止的具体实现由 `tools/scripts/run.sh` 和 `tools/scripts/stop.sh` 封装。

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
2. 执行 `tools/bin/dev` 脚本
3. 如果失败，输出结构化错误并建议修复 Skill

## 相关文件

| 文件 | 说明 |
|------|------|
| `tools/bin/dev` | Python CLI 主程序 |
| `tools/scripts/*.sh` | Shell 脚本 |
| `tools/config/dev.yaml` | 项目配置 |
| `tools/results/*.json` | 构建结果 |
| `tools/fixers/**/*.yaml` | 错误规则定义 |
| `test/dt/*.t` | Test::Nginx 测试用例 |