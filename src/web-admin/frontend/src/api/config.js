import axios from 'axios'

// 创建 axios 实例
const api = axios.create({
  baseURL: '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// 响应拦截器
api.interceptors.response.use(
  response => response.data,
  error => {
    const message = error.response?.data?.error || error.message || '请求失败'
    return Promise.reject(new Error(message))
  }
)

// 配置管理 API
export const configApi = {
  // 获取配置列表
  list(domain) {
    return api.get(`/config/${domain}`)
  },

  // 获取单个配置
  get(domain, id) {
    return api.get(`/config/${domain}/${id}`)
  },

  // 创建配置
  create(domain, data) {
    return api.post(`/config/${domain}`, data)
  },

  // 更新配置
  update(domain, id, data) {
    return api.put(`/config/${domain}/${id}`, data)
  },

  // 删除配置
  delete(domain, id) {
    return api.delete(`/config/${domain}/${id}`)
  },

  // 验证配置
  validate(domain, data) {
    return api.post(`/config/${domain}/validate`, data)
  }
}

// 监控状态 API
export const statusApi = {
  // 获取 Nginx 状态
  nginx() {
    return api.get('/status/nginx')
  },

  // 获取连接统计
  connections() {
    return api.get('/status/connections')
  },

  // 获取共享字典状态
  dict() {
    return api.get('/status/dict')
  },

  // 获取缓存状态
  cache() {
    return api.get('/status/cache')
  },

  // 获取请求统计
  requests() {
    return api.get('/status/requests')
  },

  // 获取所有状态
  all() {
    return api.get('/status/all')
  },

  // 获取 Loadbalance 模块信息
  loadbalance() {
    return api.get('/status/loadbalance')
  },

  // 获取转发规则配置状态
  forwardRules() {
    return api.get('/status/forward-rules')
  }
}

// 部署 API
export const deployApi = {
  // 预览配置
  preview() {
    return api.post('/deploy/preview', {})
  },

  // 应用配置
  apply() {
    return api.post('/deploy/apply', {})
  },

  // 获取部署状态
  status() {
    return api.get('/deploy/status')
  }
}

// API 信息
export const apiInfo = {
  get() {
    return api.get('/')
  }
}

export default api