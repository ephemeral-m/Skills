# TypeScript 类型定义

## 配置类型

```typescript
// types/config.ts

// ========== 基础类型 ==========

/**
 * 服务器配置
 */
export interface ServerConfig {
  host: string
  port: number
  weight?: number
  backup?: boolean
  down?: boolean
  max_fails?: number
  fail_timeout?: string
}

/**
 * 健康检查配置
 */
export interface HealthCheckConfig {
  enabled: boolean
  interval?: string
  fails?: number
  passes?: number
  uri?: string
}

/**
 * 代理超时配置
 */
export interface ProxyTimeoutConfig {
  connect?: string
  send?: string
  read?: string
}

/**
 * 限流配置
 */
export interface RateLimitConfig {
  enabled: boolean
  rate: string
  burst: number
}

// ========== Upstream 配置 ==========

/**
 * Upstream 配置
 */
export interface UpstreamConfig {
  id: string
  servers: ServerConfig[]
  balance?: 'round_robin' | 'least_conn' | 'ip_hash'
  keepalive?: number
  health_check?: HealthCheckConfig
}

// ========== Location 配置 ==========

/**
 * Location 类型
 */
export type LocationType = '' | '=' | '^~' | '~' | '~*'

/**
 * Location 配置
 */
export interface LocationConfig {
  id: string
  path: string
  location_type?: LocationType
  proxy_pass?: string
  proxy_http_version?: string
  proxy_set_header?: Record<string, string>
  proxy_timeout?: ProxyTimeoutConfig
  root?: string
  index?: string
  expires?: string
  cache_control?: string
  plugins?: string[]
  rate_limit?: RateLimitConfig
  directives?: string[]
}

// ========== HTTP Server 配置 ==========

/**
 * 监听配置
 */
export interface ListenConfig {
  port: number
  ssl?: boolean
  http2?: boolean
  certificate?: string
  certificate_key?: string
}

/**
 * HTTP Server 配置
 */
export interface HttpServerConfig {
  id: string
  server_name: string
  listen: ListenConfig[] | number
  root?: string
  index?: string
  access_log?: string
  error_log?: string
}

// ========== Stream 配置 ==========

/**
 * Stream 协议类型
 */
export type StreamProtocol = 'tcp' | 'udp'

/**
 * Stream 超时配置
 */
export interface StreamTimeoutConfig {
  connect?: string
  read?: string
  send?: string
}

/**
 * Stream Server 配置
 */
export interface StreamServerConfig {
  id: string
  listen: number | string
  protocol: StreamProtocol
  proxy_pass: string
  timeout?: StreamTimeoutConfig
}

// ========== API 响应类型 ==========

/**
 * 通用成功响应
 */
export interface SuccessResponse<T = any> {
  id?: string
  message: string
  data?: T
}

/**
 * 错误响应
 */
export interface ErrorResponse {
  error: string
  message?: string
}

/**
 * 配置列表响应
 */
export interface ConfigListResponse<T> {
  version: number
  updated_at: string
  items: T[]
}

/**
 * 验证响应
 */
export interface ValidateResponse {
  valid: boolean
  error?: string
}

// ========== 部署相关类型 ==========

/**
 * 部署状态
 */
export interface DeployStatus {
  prod_dir: string
  nginx_running: boolean
  nginx_pid?: number
  config_version?: string
  last_deploy?: string
  available_backups: string[]
  config_stats?: {
    upstreams: number
    http_servers: number
    stream_servers: number
    locations: number
  }
}

/**
 * 部署结果
 */
export interface DeployResult {
  success: boolean
  message: string
  backup_id?: string
  validation?: {
    command: string
    output: string
    success: boolean
  }
  reload?: {
    output: string
    success: boolean
  }
}

/**
 * 部署历史项
 */
export interface DeployHistoryItem {
  version: string
  timestamp: string
}

/**
 * 配置预览结果
 */
export interface PreviewResult {
  upstreams: string
  http_servers: string
  stream_servers: string
  locations: string
  full: string
}

/**
 * 回滚结果
 */
export interface RollbackResult {
  success: boolean
  message: string
  version: string
}
```

## Store 类型

```typescript
// types/store.ts

import type { UpstreamConfig, LocationConfig, HttpServerConfig, StreamServerConfig } from './config'

/**
 * 配置 Store 状态
 */
export interface ConfigState {
  // 配置数据
  upstreams: UpstreamConfig[]
  locations: LocationConfig[]
  httpServers: HttpServerConfig[]
  streamServers: StreamServerConfig[]

  // 加载状态
  loading: {
    upstreams: boolean
    locations: boolean
    http: boolean
    stream: boolean
  }

  // 错误信息
  error: {
    upstreams: string | null
    locations: string | null
    http: string | null
    stream: string | null
  }

  // 最后更新时间
  lastUpdated: string | null
}

/**
 * 部署 Store 状态
 */
export interface DeployState {
  status: DeployStatus | null
  history: DeployHistoryItem[]
  preview: string | null
  loading: boolean
  applying: boolean
}
```

## 表单类型

```typescript
// types/form.ts

import type { FormInstance, FormRules } from 'element-plus'

/**
 * 表单字段配置
 */
export interface FormFieldConfig {
  key: string
  label: string
  type: 'input' | 'select' | 'number' | 'switch' | 'textarea'
  required?: boolean
  default?: any
  options?: Array<{ label: string; value: any }>
  props?: Record<string, any>
  rules?: FormRules[string]
}

/**
 * 表单配置
 */
export interface FormConfig {
  fields: FormFieldConfig[]
  labelWidth?: string
  labelPosition?: 'left' | 'right' | 'top'
}

/**
 * 表单实例
 */
export interface ConfigFormInstance {
  validate: () => Promise<boolean>
  reset: () => void
  getFormData: () => Record<string, any>
  setFormData: (data: Record<string, any>) => void
}
```

## 路由类型

```typescript
// types/router.ts

/**
 * 路由元信息
 */
export interface RouteMeta {
  title: string
  icon?: string
  requiresAuth?: boolean
  breadcrumb?: string[]
}

/**
 * 菜单项
 */
export interface MenuItem {
  key: string
  label: string
  icon?: string
  path?: string
  children?: MenuItem[]
}
```