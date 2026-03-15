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
  {
    path: '/wizard',
    name: 'Wizard',
    component: () => import('@/views/wizard/index.vue'),
    meta: { title: '新建向导' }
  },
  {
    path: '/http',
    name: 'HttpConfig',
    component: () => import('@/views/http/index.vue'),
    meta: { title: 'HTTP 域配置' }
  },
  {
    path: '/stream',
    name: 'StreamConfig',
    component: () => import('@/views/stream/index.vue'),
    meta: { title: 'Stream 域配置' }
  },
  {
    path: '/upstream',
    name: 'UpstreamConfig',
    component: () => import('@/views/upstream/index.vue'),
    meta: { title: 'Upstream 配置' }
  },
  {
    path: '/location',
    name: 'LocationConfig',
    component: () => import('@/views/location/index.vue'),
    meta: { title: 'Location 配置' }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router