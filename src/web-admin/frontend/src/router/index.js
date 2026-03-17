import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  {
    path: '/',
    redirect: '/monitor'
  },
  {
    path: '/monitor',
    name: 'Monitor',
    component: () => import('@/views/monitor/index.vue'),
    meta: { title: '监控面板' }
  },
  // 监听器
  {
    path: '/listeners/http',
    name: 'HttpListener',
    component: () => import('@/views/listeners/http/index.vue'),
    meta: { title: 'HTTP 监听器' }
  },
  {
    path: '/listeners/tcp',
    name: 'TcpListener',
    component: () => import('@/views/listeners/tcp/index.vue'),
    meta: { title: 'TCP 监听器' }
  },
  // 路由规则
  {
    path: '/routes',
    name: 'Routes',
    component: () => import('@/views/routes/index.vue'),
    meta: { title: '路由规则' }
  },
  // 后端服务器组
  {
    path: '/server-groups',
    name: 'ServerGroups',
    component: () => import('@/views/server-groups/index.vue'),
    meta: { title: '后端服务器组' }
  },
  // 后端服务器
  {
    path: '/servers',
    name: 'Servers',
    component: () => import('@/views/servers/index.vue'),
    meta: { title: '后端服务器' }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router