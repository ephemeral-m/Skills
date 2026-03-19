---
name: dev
description: 统一开发命令入口，零 Token 消耗执行 build/test/start/stop 等工程任务。当用户需要构建项目、运行测试、启动/停止服务时使用此 skill。
---

# dev Slash Command

统一开发命令入口，通过 SSH 远程执行构建、测试、服务管理任务。

## 用法

```
/dev build          # 编译构建（远程执行）
/dev test           # 运行测试（远程执行）
/dev start          # 启动服务（远程执行）
/dev stop           # 停止服务（远程执行）
```

## 架构

```
┌─────────────────────────────────────────────────┐
│              Windows 本地环境                    │
│  - 执行 /dev 命令                                │
│  - 使用系统自带 ssh 命令                         │
└─────────────────────────────────────────────────┘
                        │
                   ssh (OpenSSH)
                        │
                        ▼
┌─────────────────────────────────────────────────┐
│              Linux 远程环境                      │
│  - tools/scripts/build.sh                       │
│  - tools/scripts/test.sh                        │
│  - tools/scripts/start.sh                       │
│  - tools/scripts/stop.sh                        │
└─────────────────────────────────────────────────┘
```

## 前提条件

1. Windows 已安装 OpenSSH 客户端（Windows 10/11 默认自带）
2. 已配置 SSH 密钥认证，或密码存储在配置文件中
3. 远程服务器已部署 Shell 脚本

## 流程

1. 读取配置文件 `tools/config/dev.yaml`
2. 构造 SSH 命令
3. 在远程服务器执行对应的 Shell 脚本
4. 实时输出结果并返回退出码

## 配置文件

`tools/config/dev.yaml`:

```yaml
remote:
  host: 192.168.168.218
  port: 22
  user: m30020610
  # 密码认证（不推荐，建议使用 SSH 密钥）
  password: "123456"
  # 工作目录
  workdir: /home/m30020610/Skills

scripts:
  build: bash tools/scripts/build.sh
  test: bash tools/scripts/test.sh
  start: bash tools/scripts/start.sh
  stop: bash tools/scripts/stop.sh
```

## 相关文件

| 文件 | 说明 |
|------|------|
| `tools/bin/dev` | CLI 入口（本地执行）|
| `tools/scripts/build.sh` | 构建脚本（远程执行）|
| `tools/scripts/test.sh` | 测试脚本（远程执行）|
| `tools/scripts/start.sh` | 启动脚本（远程执行）|
| `tools/scripts/stop.sh` | 停止脚本（远程执行）|
| `tools/config/dev.yaml` | 配置文件 |