---
name: web-admin-frontend
description: Web-Admin 前端到后端的架构设计和开发指南。当用户需要开发 web-admin 前端功能、添加新页面、设计表单、实现配置管理界面时使用此 skill。
---

# Web-Admin 前端架构设计指南

> **跨平台开发模式**: Windows 开发 + Linux 远程运行，详见 `/dev` skill

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                    Web Admin Console (8080/8081)                │
│  Frontend (Vue 3 + Element Plus)  ←→  Backend (OpenResty Lua)  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 LoadBalance OpenResty (80/443)                  │
│  nginx.conf (自动生成) ← lua-plugins/* (插件集成)               │
└─────────────────────────────────────────────────────────────────┘
```

## 目录结构

```
src/web-admin/
├── frontend/           # Vue 3 前端
│   └── src/
│       ├── views/      # 页面组件
│       ├── components/ # 通用组件
│       ├── api/        # API 调用层
│       ├── stores/     # Pinia 状态管理
│       └── types/      # TypeScript 类型
│
├── backend/            # Lua 后端 API
│   └── lualib/admin/
│       ├── api.lua     # API 入口路由
│       ├── config.lua  # 配置 CRUD
│       ├── storage.lua # JSON 存储
│       ├── generator.lua # 配置生成器
│       └── deploy.lua  # 部署控制
│
└── data/configs/       # JSON 配置存储
```

## 数据流

### 配置管理

```
用户操作 → 表单验证 → API 调用 → JSON 存储 → 版本管理
```

### 部署流程

```
POST /api/deploy/apply
  → 读取 JSON 配置
  → 生成 nginx 配置
  → 备份当前配置
  → 写入新配置
  → nginx -s reload
  → 返回结果
```

## API 规范

### 配置 CRUD

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/api/config/:domain` | 获取配置列表 |
| POST | `/api/config/:domain` | 创建配置 |
| PUT | `/api/config/:domain/:id` | 更新配置 |
| DELETE | `/api/config/:domain/:id` | 删除配置 |

### 部署控制

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/api/deploy/preview` | 预览生成的配置 |
| POST | `/api/deploy/apply` | 应用配置 |
| GET | `/api/deploy/status` | 部署状态 |
| POST | `/api/deploy/rollback` | 回滚版本 |

## 开发流程

1. **定义数据模型** - `types/` 下定义 TypeScript 接口
2. **实现后端 API** - 确认 CRUD 端点，必要时添加路由
3. **实现前端组件** - 表单 + 表格 + 页面组件
4. **添加 API 调用** - `api/` 下添加调用函数
5. **端到端验证** - 必须完成全部验证步骤

## 验证清单

```markdown
- [ ] 前端表单正确提交
- [ ] API 返回成功响应
- [ ] JSON 配置文件正确保存
- [ ] 配置预览正确生成
- [ ] 配置应用成功
- [ ] 服务实际生效
```

### 验证命令

```bash
# 检查 API 响应
curl -X POST http://localhost:8080/api/config/stream -d '{"id":"test"}'

# 检查配置保存
cat src/web-admin/data/configs/stream.json

# 应用配置
curl -X POST http://localhost:8080/api/deploy/apply

# 验证服务生效
ss -tlnp | grep <port>
```

## 设计原则

1. **配置优先** - JSON 配置 → 配置生成器 → nginx.conf
2. **分离关注点** - 前端交互 / 后端 API / 配置生成 / 生产实例
3. **版本控制** - 每次变更自动备份，支持一键回滚
4. **验证优先** - 前端验证 + 后端验证 + 配置验证

## 测试用例

位置: `test/dt/web-admin/test_api.sh`

```bash
./test_api.sh all        # 运行所有测试
./test_api.sh upstream   # 运行指定测试
```

## 详细文档

- `references/components.md` - 组件开发详细指南
- `references/api-design.md` - API 设计规范
- `references/types.md` - TypeScript 类型定义