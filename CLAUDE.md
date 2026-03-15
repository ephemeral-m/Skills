# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 语言偏好

始终使用中文与用户交流沟通。

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

| Skill | 用途 |
|-------|------|
| `openresty-lua-plugins` | 生成基于 OpenResty 的 HTTP/TCP/UDP Lua 插件 |
| `code-review` | 系统性代码审查 |
| `code-reactor` | 代码重构和改进 |
| `document-ar-docx` | Word 文档处理 |
| `jenkins-pipeline` | Jenkins CI/CD 流水线配置 |
| `monitor-observablility` | 监控和可观测性实现 |

使用方式：`/openresty-lua-plugins`、`/code-review` 等。

## 开发指南

### Lua 插件开发
```bash
# 插件目录
cd src/lua-plugins/

# 使用 skill 生成插件
/openresty-lua-plugins
```

### 前端管理模块
```bash
cd src/web-admin/frontend
npm install
npm run dev
```

### Nginx C 模块开发
```bash
cd src/ngx-modules/
# 参考 README.md 进行开发
```