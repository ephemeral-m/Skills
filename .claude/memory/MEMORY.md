# 项目记忆

本文件记录在开发过程中发现的重要信息，持久化保存以供后续会话参考。

> **注意**: 此文件位于项目目录下，便于团队成员共享。所有开发者都应遵循相同的开发规范。

## 核心设计理念

### Windows 开发 + Linux 远程运行

```
┌─────────────────────────────────────────────────────────────────┐
│                    Windows 开发环境                              │
│  - 代码编辑 (IDE/编辑器)                                         │
│  - Git 版本管理                                                  │
│  - Python dev CLI (通过 SSH 控制远程)                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                        SSH (paramiko)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Linux 远程运行环境                            │
│  - OpenResty 构建和运行                                          │
│  - 所有 Shell 脚本执行                                           │
│  - 服务启动/停止/测试                                             │
│  - 生产流量转发                                                   │
└─────────────────────────────────────────────────────────────────┘
```

**关键原则：**

1. **所有脚本在 Linux 上执行** - Shell 脚本、构建、测试全部在远程 Linux 运行
2. **dev CLI 是桥梁** - Python 脚本通过 SSH 连接远程执行命令
3. **代码同步后生效** - 修改代码后必须 `dev sync` 同步到远程
4. **路径差异** - 本地使用 Windows 路径，远程使用 Linux 路径
5. **编码差异** - 同步时需指定 UTF-8 编码处理中文文件名

**注意事项：**

- Windows 本地不要直接运行 Shell 脚本（`bash scripts/start.sh` 在 Windows 上会失败）
- 使用 `/dev` 命令或 `python tools/bin/dev` 来执行远程操作
- 脚本中的命令检查（如 `has_cmd`）在 Linux 环境执行
- 文件权限问题在 Linux 环境处理

## 项目结构

```
D:\Coding\Code\Dev\Skills\
├── src/
│   ├── openresty/          # OpenResty 1.29.2.1 源码
│   ├── loadbalance/        # 负载均衡 OpenResty 实例
│   │   ├── nginx.conf      # 主配置
│   │   ├── conf.d/         # 自动生成的配置片段
│   │   ├── logs/           # 日志目录
│   │   └── deploy_history/ # 部署历史备份
│   ├── lua-plugins/        # Lua 插件目录
│   ├── web-admin/          # Web 管理界面
│   │   ├── frontend/       # Vue 3 + Element Plus
│   │   ├── backend/        # OpenResty + Lua API
│   │   │   └── lualib/admin/
│   │   │       ├── generator.lua  # 配置生成器
│   │   │       └── deploy.lua     # 部署控制
│   │   └── data/           # JSON 配置存储
│   └── ngx-modules/        # Nginx C 模块
├── tools/
│   ├── bin/dev             # Python CLI
│   ├── scripts/            # Shell 脚本
│   │   ├── start.sh         # 启动服务 (web-admin + loadbalance)
│   │   └── stop.sh         # 停止服务
│   ├── config/dev.yaml     # 配置文件
│   └── fixers/             # 错误修复规则
└── .claude/
    ├── skills/             # Skills 定义
    ├── memory/             # 项目记忆 (本文件)
    └── feedback/           # 反馈机制
```

## 关键路径

| 路径 | 说明 |
|------|------|
| `build/openresty/nginx/sbin/nginx` | Nginx 二进制 |
| `src/web-admin/backend/logs/` | Web-admin 日志目录 |
| `src/web-admin/data/configs/` | JSON 配置存储 |
| `src/loadbalance/nginx.conf` | 负载均衡主配置 |
| `src/loadbalance/conf.d/` | 自动生成的配置片段 |

## 远程服务器

- **地址**: 192.168.5.14
- **用户**: root
- **工作目录**: /home/mxp/Skills

## 已解决的问题

### 1. Nginx 路由优先级
**问题**: `/api` 请求返回 504
**原因**: `location /api/` 定义在 `location /` 之后
**解决**: 将 `location /api/` 移到 `location /` 之前

### 2. ngx.start_time() 不存在
**问题**: `attempt to call field 'start_time' (a nil value)`
**原因**: ngx_lua 没有 `ngx.start_time()` 函数
**解决**: 使用 `ngx.shared.status` 存储启动时间

### 3. nobody 用户权限
**问题**: `/api/config/*` 返回 Permission denied
**原因**: nginx worker 以 nobody 用户运行，无法访问 /home/mxp
**解决**: `chmod o+rx /home/mxp`

### 4. Bash set -e 与 ((var++))
**问题**: 脚本意外退出
**原因**: `((var++))` 当 var=0 时返回退出码 1
**解决**: 使用 `var=$((var + 1))`

### 5. tarfile UTF-8 编码
**问题**: 同步后中文文件名乱码
**解决**: `tarfile.open(..., encoding='utf-8')`

### 6. 部署配置成功但服务未生效
**问题**: 通过前端添加 stream 配置，API 返回成功但端口未监听
**原因**: 配置保存成功，但 nginx 重载失败
**失败原因**:
- stream 配置引用的 upstream 不存在
- http.conf 中引用的日志目录不存在 (`/var/log/nginx/`)
**解决**:
- 先创建对应的 upstream 配置
- 创建缺失的目录 (`mkdir -p /var/log/nginx /var/www/html`)
**验证**: 使用 `ss -tlnp | grep <port>` 确认端口监听

### 7. dev 命令对称性
**问题**: `/dev run` 和 `/dev stop` 命令不对称
**解决**: 改为 `/dev start` 和 `/dev stop`

### 8. generator.lua 表混合使用导致 deploy 失败
**问题**: 通过前端创建 stream 配置后，调用 `/api/deploy/apply` 报错 `attempt to concatenate a userdata value`
**原因**: `generator.lua` 中 `result.upstreams` 同时用作数组（存配置字符串）和字典（存对象引用）
**解决**: 分离为两个独立的表：
- `upstream_configs`: 数组，存储配置字符串
- `upstream_refs`: 字典，存储对象引用（用于查找）
**文件**: `src/web-admin/backend/lualib/admin/generator.lua`, `deploy.lua`

## 开发命令

```bash
/dev sync          # 同步代码到远程
/dev build         # 构建 OpenResty
/dev start         # 启动服务 (web-admin + loadbalance)
/dev stop          # 停止服务
/dev test --dt     # 运行测试
```

## 服务端口

| 端口 | 服务 |
|------|------|
| 80 | 负载均衡 OpenResty (HTTP 转发) |
| 443 | 负载均衡 OpenResty HTTPS |
| 3306 | Stream TCP 代理 (MySQL) |
| 53 | Stream UDP 代理 (DNS) |
| 7777 | Stream TCP 代理 (测试) |
| 8080 | Web-admin API + 开发前端代理 |
| 8081 | 生产前端 |
| 5173 | Vite 开发服务器 |

## 部署 API 端点

| 端点 | 说明 |
|------|------|
| `POST /api/deploy/preview` | 预览生成的 nginx 配置 |
| `POST /api/deploy/apply` | 应用配置并重载负载均衡实例 |
| `GET /api/deploy/status` | 获取部署状态 |
| `GET /api/deploy/history` | 获取部署历史 |
| `POST /api/deploy/rollback` | 回滚到指定版本 |