# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 语言偏好

始终使用中文与用户交流沟通。

## 项目概述

本仓库包含两部分内容：

1. **OpenResty 1.29.2.1 源码** - 位于 `src/` 目录，详细说明见 `src/CLAUDE.md`
2. **自定义 Claude Code Skills** - 位于 `.claude/skills/` 目录

## 自定义 Skills

| Skill | 用途 |
|-------|------|
| `openresty-lua-plugins` | 生成基于 OpenResty 的 HTTP/TCP/UDP Lua 插件 |
| `sync` | 生成 VS Code SFTP 配置，同步文件到远程服务器 |
| `code-review` | 系统性代码审查 |
| `code-reactor` | 代码重构和改进 |
| `document-ar-docx` | Word 文档处理 |
| `jenkins-pipeline` | Jenkins CI/CD 流水线配置 |
| `monitor-observablility` | 监控和可观测性实现 |

使用方式：`/openresty-lua-plugins`、`/sync`、`/code-review` 等。