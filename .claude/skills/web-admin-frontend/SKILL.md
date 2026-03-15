---
name: web-admin-frontend
description: Web-Admin 前端到后端的架构设计和开发指南。当用户需要开发 web-admin 前端功能、添加新页面、设计表单、实现配置管理界面时使用此 skill。此 skill 定义了前端与后端的数据流、API 规范、组件设计模式。
---

# Web-Admin 前端架构设计指南

> **跨平台开发模式**: Windows 开发 + Linux 远程运行，详见 `/dev` skill 或项目 CLAUDE.md

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                    Web Admin Console (8080/8081)                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Frontend (Vue 3 + Element Plus)                          │  │
│  │  - 组件化页面结构                                          │  │
│  │  - API 调用层封装                                          │  │
│  │  - 状态管理 (Pinia)                                        │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Backend (OpenResty + Lua API)                            │  │
│  │  - /api/config/* CRUD 操作                                 │  │
│  │  - /api/deploy/* 部署控制                                  │  │
│  │  - /api/status/* 状态监控                                  │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 LoadBalance OpenResty (80/443)                  │
│  - nginx.conf (自动生成)                                        │
│  - lua-plugins/* (插件集成)                                     │
└─────────────────────────────────────────────────────────────────┘
```

## 目录结构

```
src/
├── web-admin/
│   ├── frontend/                  # 前端源码
│   │   ├── src/
│   │   │   ├── views/             # 页面组件
│   │   │   │   ├── config/        # 配置管理页面
│   │   │   │   ├── deploy/        # 部署管理页面
│   │   │   │   └── monitor/       # 监控页面
│   │   │   ├── components/        # 通用组件
│   │   │   │   ├── forms/         # 表单组件
│   │   │   │   └── tables/        # 表格组件
│   │   │   ├── api/               # API 调用层
│   │   │   │   ├── config.ts      # 配置 API
│   │   │   │   ├── deploy.ts      # 部署 API
│   │   │   │   └── index.ts       # API 导出
│   │   │   ├── stores/            # Pinia 状态管理
│   │   │   ├── types/             # TypeScript 类型定义
│   │   │   └── utils/             # 工具函数
│   │   └── package.json
│   │
│   ├── backend/                   # 后端 API
│   │   ├── nginx.conf             # 控制台 nginx 配置
│   │   └── lualib/admin/
│   │       ├── api.lua            # API 入口路由
│   │       ├── config.lua         # 配置 CRUD
│   │       ├── storage.lua        # JSON 存储
│   │       ├── generator.lua      # 配置生成器
│   │       ├── deploy.lua         # 部署控制
│   │       └── monitor.lua        # 监控模块
│   │
│   └── data/configs/              # JSON 配置存储
│       ├── http.json
│       ├── stream.json
│       ├── upstream.json
│       └── location.json
│
├── loadbalance/                  # 负载均衡实例 (端口 80/443)
│   ├── nginx.conf                 # 主配置
│   ├── conf.d/                    # 自动生成的配置
│   └── deploy_history/            # 部署历史
│
└── lua-plugins/                   # Lua 插件
```

## 数据流设计

### 1. 配置管理流程

```
用户操作 (前端)
      │
      ▼
┌─────────────────┐
│  表单验证       │  ← 前端验证 + 后端验证
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  API 调用       │  ← POST /api/config/:domain
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  JSON 存储      │  ← storage.lua 保存到文件
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  版本管理       │  ← 自动备份旧版本
└─────────────────┘
```

### 2. 部署流程

```
用户点击"应用配置"
      │
      ▼
POST /api/deploy/apply
      │
      ├── 1. 读取 JSON 配置
      ├── 2. 生成 nginx 配置 (generator.lua)
      ├── 3. 备份当前配置
      ├── 4. 写入新配置
      ├── 5. nginx -t 验证
      ├── 6. nginx -s reload
      │
      ▼
返回结果 { success, message, backup_id }
```

## API 规范

### 配置 CRUD

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | `/api/config/:domain` | 获取配置列表 |
| GET | `/api/config/:domain/:id` | 获取单个配置 |
| POST | `/api/config/:domain` | 创建配置 |
| PUT | `/api/config/:domain/:id` | 更新配置 |
| DELETE | `/api/config/:domain/:id` | 删除配置 |
| POST | `/api/config/:domain/validate` | 验证配置 |
| GET | `/api/config/:domain/history` | 配置历史 |
| POST | `/api/config/:domain/rollback` | 回滚配置 |

### 部署控制

| 方法 | 端点 | 说明 |
|------|------|------|
| POST | `/api/deploy/preview` | 预览生成的配置 |
| POST | `/api/deploy/apply` | 应用配置 |
| GET | `/api/deploy/status` | 部署状态 |
| GET | `/api/deploy/history` | 部署历史 |
| POST | `/api/deploy/rollback` | 回滚版本 |

### 响应格式

```typescript
// 成功响应
interface SuccessResponse<T> {
  id?: string;
  message: string;
  data?: T;
}

// 错误响应
interface ErrorResponse {
  error: string;
  message?: string;
}

// 列表响应
interface ListResponse<T> {
  version: number;
  updated_at: string;
  items: T[];
}
```

## 前端组件设计

### 1. 表单组件模式

```vue
<!-- src/components/forms/ConfigForm.vue -->
<template>
  <el-form
    ref="formRef"
    :model="formData"
    :rules="formRules"
    label-width="120px"
  >
    <el-form-item label="名称" prop="name">
      <el-input v-model="formData.name" />
    </el-form-item>

    <!-- 动态表单项 -->
    <el-form-item
      v-for="field in dynamicFields"
      :key="field.key"
      :label="field.label"
      :prop="field.key"
    >
      <component
        :is="field.component"
        v-model="formData[field.key]"
        v-bind="field.props"
      />
    </el-form-item>

    <el-form-item>
      <el-button type="primary" @click="handleSubmit">保存</el-button>
      <el-button @click="handleReset">重置</el-button>
    </el-form-item>
  </el-form>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'

// 表单数据
const formData = reactive({ ...initialData })
const formRef = ref<FormInstance>()

// 验证规则
const formRules: FormRules = {
  name: [
    { required: true, message: '请输入名称', trigger: 'blur' }
  ]
}

// 提交处理
const handleSubmit = async () => {
  const valid = await formRef.value?.validate()
  if (!valid) return

  try {
    await props.api.save(formData)
    ElMessage.success('保存成功')
    emit('saved')
  } catch (error) {
    ElMessage.error('保存失败')
  }
}
</script>
```

### 2. 表格组件模式

```vue
<!-- src/components/tables/ConfigTable.vue -->
<template>
  <el-table :data="tableData" v-loading="loading">
    <el-table-column prop="id" label="ID" />
    <el-table-column prop="name" label="名称" />
    <el-table-column label="操作" width="200">
      <template #default="{ row }">
        <el-button size="small" @click="handleEdit(row)">编辑</el-button>
        <el-button size="small" type="danger" @click="handleDelete(row)">
          删除
        </el-button>
      </template>
    </el-table-column>
  </el-table>
</template>
```

### 3. API 调用封装

```typescript
// src/api/config.ts
import { request } from '@/utils/request'

export interface UpstreamConfig {
  id: string
  servers: Array<{
    host: string
    port: number
    weight?: number
  }>
  balance?: string
  keepalive?: number
}

export const configApi = {
  // 获取配置列表
  list: (domain: string) =>
    request.get(`/api/config/${domain}`),

  // 获取单个配置
  get: (domain: string, id: string) =>
    request.get(`/api/config/${domain}/${id}`),

  // 创建配置
  create: (domain: string, data: any) =>
    request.post(`/api/config/${domain}`, data),

  // 更新配置
  update: (domain: string, id: string, data: any) =>
    request.put(`/api/config/${domain}/${id}`, data),

  // 删除配置
  delete: (domain: string, id: string) =>
    request.delete(`/api/config/${domain}/${id}`),

  // 验证配置
  validate: (domain: string, data: any) =>
    request.post(`/api/config/${domain}/validate`, data)
}
```

### 4. 状态管理

```typescript
// src/stores/config.ts
import { defineStore } from 'pinia'
import { configApi } from '@/api/config'

export const useConfigStore = defineStore('config', {
  state: () => ({
    upstreams: [] as UpstreamConfig[],
    loading: false,
    error: null as string | null
  }),

  actions: {
    async fetchUpstreams() {
      this.loading = true
      try {
        const data = await configApi.list('upstream')
        this.upstreams = data.items
      } catch (error) {
        this.error = '获取配置失败'
      } finally {
        this.loading = false
      }
    },

    async saveUpstream(config: UpstreamConfig) {
      if (config.id) {
        await configApi.update('upstream', config.id, config)
      } else {
        await configApi.create('upstream', config)
      }
      await this.fetchUpstreams()
    }
  }
})
```

## 配置数据模型

### Upstream 配置

```typescript
interface UpstreamConfig {
  id: string                      // upstream 名称
  servers: ServerConfig[]         // 服务器列表
  balance?: 'round_robin' | 'least_conn' | 'ip_hash'  // 负载均衡
  keepalive?: number              // 保活连接数
  health_check?: {
    enabled: boolean
    interval: string              // 如 "5s"
    fails: number
    passes: number
    uri: string
  }
}

interface ServerConfig {
  host: string
  port: number
  weight?: number
  backup?: boolean
  max_fails?: number
  fail_timeout?: string
}
```

### Location 配置

```typescript
interface LocationConfig {
  id: string
  path: string                    // location 路径
  location_type?: '' | '=' | '^~' | '~' | '~*'  // location 类型
  proxy_pass?: string             // 代理目标
  proxy_set_header?: Record<string, string>
  proxy_timeout?: {
    connect?: string
    send?: string
    read?: string
  }
  root?: string                   // 静态文件根目录
  plugins?: string[]              // 启用的插件列表
  rate_limit?: {
    enabled: boolean
    rate: string
    burst: number
  }
}
```

## 执行步骤

### 开发新功能时的流程

1. **确定数据模型**
   - 在 `types/` 下定义 TypeScript 接口
   - 在后端 `config.lua` 添加验证规则

2. **实现后端 API**
   - 确认已有 CRUD 端点是否满足需求
   - 如需新端点，在 `api.lua` 中添加路由

3. **实现前端组件**
   - 创建表单组件 (编辑/新增)
   - 创建表格组件 (列表展示)
   - 创建页面组件 (组合表单和表格)

4. **添加 API 调用**
   - 在 `api/` 下添加调用函数
   - 处理加载状态和错误

5. **测试验证**
   - 前端表单验证
   - API 调用测试
   - 配置生成验证

## 设计原则

### 1. 配置优先，代码在后

```
JSON 配置 → 配置生成器 → nginx.conf → 重载生效
```

前端只负责修改 JSON，后端负责生成 nginx 配置。

### 2. 分离关注点

| 层级 | 职责 |
|------|------|
| 前端 | 用户交互、表单验证、状态展示 |
| 后端 API | 配置 CRUD、业务逻辑 |
| 配置生成器 | JSON → nginx.conf 转换 |
| 生产实例 | 实际流量转发 |

### 3. 版本控制

- 每次配置变更自动备份
- 支持一键回滚
- 保留历史版本

### 4. 验证优先

- 前端验证：表单字段格式
- 后端验证：业务规则校验
- 配置验证：`nginx -t` 预检

## 详细文档

- `references/components.md` - 组件开发详细指南
- `references/api-design.md` - API 设计规范
- `references/types.md` - TypeScript 类型定义

## 关键文件

| 文件 | 说明 |
|------|------|
| `src/web-admin/backend/lualib/admin/api.lua` | API 路由入口 |
| `src/web-admin/backend/lualib/admin/config.lua` | 配置 CRUD 逻辑 |
| `src/web-admin/backend/lualib/admin/generator.lua` | 配置生成器 |
| `src/web-admin/backend/lualib/admin/deploy.lua` | 部署控制 |
| `src/web-admin/data/configs/*.json` | JSON 配置存储 |
| `src/loadbalance/nginx.conf` | 负载均衡主配置 |