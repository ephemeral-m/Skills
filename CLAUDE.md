# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目记忆

> 项目记忆文件位于 `.claude/memory/MEMORY.md`，记录开发过程中的重要信息和已解决的问题，便于团队成员共享。

## 语言偏好

始终使用中文与用户交流沟通。

## 跨平台开发模式

**核心原则：Windows 开发 + Linux 远程运行**

```
┌─────────────────────────────────────────────────────────────────┐
│                    Windows 本地环境                              │
│  - 代码编辑 (IDE/编辑器)                                         │
│  - Git 版本管理                                                  │
│  - 通过 /dev CLI 控制远程                                        │
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

**重要：所有构建、测试、运行命令都在远程 Linux 服务器上执行，不要在 Windows 本地直接运行 Shell 脚本。**

详细的跨平台开发流程请参考 `/dev` skill。

## 项目概述

本仓库是一个 OpenResty 开发技能库，采用模块化目录结构：

```
src/
├── openresty/       # OpenResty 1.29.2.1 源码及第三方模块
├── lua-plugins/     # Lua 插件模块 (HTTP/TCP/UDP)
├── web-admin/       # 配置管理前端模块 (Vue 3 + Element Plus)
└── ngx-modules/     # Nginx C 模块开发
```

## 模块说明

### 1. openresty/
OpenResty 源码及内置模块，详细说明见 `src/openresty/CLAUDE.md`

### 2. lua-plugins/
基于 OpenResty 的 Lua 插件开发，包含：
- HTTP 代理插件
- TCP/UDP 流代理插件
- API 网关插件

### 3. web-admin/
配置管理前端模块，提供：
- HTTP/Stream/Upstream/Location 配置管理
- 可视化配置向导
- 实时监控面板
- JSON 配置存储

### 4. ngx-modules/
Nginx C 模块开发目录，用于开发高性能原生模块

## 自定义 Skills

### 核心开发
| Skill | 用途 |
|-------|------|
| `dev` | 统一开发入口：build/test/sync/start/stop |
| `openresty-lua-plugins` | 生成 HTTP/TCP/UDP Lua 插件 |
| `web-admin-frontend` | Web-Admin 前端开发指南 |

### 错误修复
| Skill | 用途 |
|-------|------|
| `fix-compile` | 编译错误修复 (C/Lua) |
| `fix-runtime` | 运行时错误修复 |
| `fix-test` | 测试失败修复 |
| `fix-loop` | 自动迭代修复循环 |

### 代码质量
| Skill | 用途 |
|-------|------|
| `code-review` | 系统性代码审查 |
| `code-reactor` | 代码重构和改进 |
| `feedback` | 自动优化反馈机制 |

### DevOps
| Skill | 用途 |
|-------|------|
| `jenkins-pipeline` | CI/CD 流水线配置 |
| `monitor-observablility` | 监控和可观测性 |

使用方式：`/dev all`、`/openresty-lua-plugins` 等。

## 开发指南

| 操作 | 命令 |
|------|------|
| 完整流水线 | `/dev all [module]` |
| 编译模块 | `/dev build [module]` |
| 运行测试 | `/dev test [module]` |
| 同步代码 | `/dev sync` |
| 启动服务 | `/dev start` |
| 停止服务 | `/dev stop` |

详细说明见 `/dev` skill。