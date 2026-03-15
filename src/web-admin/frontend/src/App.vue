<template>
  <el-config-provider :locale="zhCn">
    <el-container class="app-container">
      <!-- 侧边栏 -->
      <el-aside width="220px" class="app-aside">
        <div class="logo">
          <el-icon size="24"><Setting /></el-icon>
          <span>配置管理</span>
        </div>
        <el-menu
          :default-active="activeMenu"
          router
          class="app-menu"
        >
          <el-menu-item index="/monitor">
            <el-icon><Monitor /></el-icon>
            <span>监控面板</span>
          </el-menu-item>
          <el-menu-item index="/wizard">
            <el-icon><MagicStick /></el-icon>
            <span>新建向导</span>
          </el-menu-item>
          <el-sub-menu index="config">
            <template #title>
              <el-icon><Document /></el-icon>
              <span>配置管理</span>
            </template>
            <el-menu-item index="/http">HTTP 域</el-menu-item>
            <el-menu-item index="/stream">Stream 域</el-menu-item>
            <el-menu-item index="/upstream">Upstream</el-menu-item>
            <el-menu-item index="/location">Location</el-menu-item>
          </el-sub-menu>
        </el-menu>
      </el-aside>

      <!-- 主内容区 -->
      <el-container>
        <el-header class="app-header">
          <div class="header-left">
            <el-breadcrumb separator="/">
              <el-breadcrumb-item :to="{ path: '/' }">首页</el-breadcrumb-item>
              <el-breadcrumb-item>{{ currentPageTitle }}</el-breadcrumb-item>
            </el-breadcrumb>
          </div>
          <div class="header-right">
            <el-button text @click="refreshData">
              <el-icon><Refresh /></el-icon>
              刷新
            </el-button>
          </div>
        </el-header>
        <el-main class="app-main">
          <router-view />
        </el-main>
      </el-container>
    </el-container>
  </el-config-provider>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import zhCn from 'element-plus/dist/locale/zh-cn.mjs'

const route = useRoute()

const activeMenu = computed(() => {
  return route.path
})

const currentPageTitle = computed(() => {
  const titles = {
    '/monitor': '监控面板',
    '/wizard': '新建向导',
    '/http': 'HTTP 域配置',
    '/stream': 'Stream 域配置',
    '/upstream': 'Upstream 配置',
    '/location': 'Location 配置'
  }
  return titles[route.path] || '配置管理'
})

const refreshData = () => {
  window.location.reload()
}
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body, #app {
  height: 100%;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
}

.app-container {
  height: 100%;
}

.app-aside {
  background: linear-gradient(180deg, #1d3557 0%, #0d1b2a 100%);
  color: #fff;
}

.logo {
  height: 60px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  font-size: 18px;
  font-weight: 600;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.app-menu {
  border-right: none;
  background: transparent;
}

.app-menu .el-menu-item,
.app-menu .el-sub-menu__title {
  color: rgba(255, 255, 255, 0.7);
}

.app-menu .el-menu-item:hover,
.app-menu .el-sub-menu__title:hover {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
}

.app-menu .el-menu-item.is-active {
  background: rgba(65, 184, 131, 0.2);
  color: #41b883;
}

.app-header {
  background: #fff;
  border-bottom: 1px solid #e4e7ed;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
}

.app-main {
  background: #f5f7fa;
  padding: 20px;
}
</style>