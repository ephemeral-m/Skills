<template>
  <div class="monitor-page">
    <!-- 状态卡片 -->
    <el-row :gutter="20" class="status-cards">
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="card-icon nginx">
            <el-icon size="32"><Service /></el-icon>
          </div>
          <div class="card-content">
            <div class="card-value">{{ nginxStatus.version || '-' }}</div>
            <div class="card-label">Nginx 版本</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="card-icon workers">
            <el-icon size="32"><User /></el-icon>
          </div>
          <div class="card-content">
            <div class="card-value">{{ nginxStatus.worker_processes || '-' }}</div>
            <div class="card-label">Worker 进程</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="card-icon uptime">
            <el-icon size="32"><Timer /></el-icon>
          </div>
          <div class="card-content">
            <div class="card-value">{{ formatUptime(nginxStatus.uptime) }}</div>
            <div class="card-label">运行时间</div>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="status-card">
          <div class="card-icon connections">
            <el-icon size="32"><Connection /></el-icon>
          </div>
          <div class="card-content">
            <div class="card-value">{{ connections.active || 0 }}</div>
            <div class="card-label">活跃连接</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 详细信息 -->
    <el-row :gutter="20">
      <!-- Nginx 信息 -->
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>Nginx 信息</span>
              <el-button text @click="loadNginxStatus">
                <el-icon><Refresh /></el-icon>
              </el-button>
            </div>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="版本">{{ nginxStatus.version }}</el-descriptions-item>
            <el-descriptions-item label="ngx_lua 版本">{{ nginxStatus.ngx_lua_version }}</el-descriptions-item>
            <el-descriptions-item label="Worker 进程数">{{ nginxStatus.worker_processes }}</el-descriptions-item>
            <el-descriptions-item label="当前 Worker ID">{{ nginxStatus.worker_id }}</el-descriptions-item>
            <el-descriptions-item label="PID">{{ nginxStatus.pid }}</el-descriptions-item>
            <el-descriptions-item label="主机名">{{ nginxStatus.hostname }}</el-descriptions-item>
            <el-descriptions-item label="运行目录">{{ nginxStatus.prefix }}</el-descriptions-item>
            <el-descriptions-item label="运行时间">{{ nginxStatus.uptime_human }}</el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>

      <!-- 连接统计 -->
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>连接统计</span>
              <el-button text @click="loadConnections">
                <el-icon><Refresh /></el-icon>
              </el-button>
            </div>
          </template>
          <div class="connection-stats">
            <div class="stat-item">
              <div class="stat-value">{{ connections.accepted }}</div>
              <div class="stat-label">已接受</div>
            </div>
            <div class="stat-item">
              <div class="stat-value">{{ connections.handled }}</div>
              <div class="stat-label">已处理</div>
            </div>
            <div class="stat-item">
              <div class="stat-value">{{ connections.active }}</div>
              <div class="stat-label">活跃</div>
            </div>
            <div class="stat-item">
              <div class="stat-value">{{ connections.requests }}</div>
              <div class="stat-label">总请求数</div>
            </div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 请求统计 -->
    <el-row :gutter="20" style="margin-top: 20px;">
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>请求统计</span>
            </div>
          </template>
          <div class="request-stats">
            <div class="stat-row" v-for="(count, status) in requestStats.by_status" :key="status">
              <span class="stat-label">{{ status }}</span>
              <el-progress
                :percentage="getPercentage(count, requestStats.total)"
                :stroke-width="20"
                :text-inside="true"
              />
            </div>
          </div>
        </el-card>
      </el-col>

      <!-- 配置缓存 -->
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>配置缓存</span>
            </div>
          </template>
          <el-table :data="cacheData" style="width: 100%">
            <el-table-column prop="domain" label="域" width="120" />
            <el-table-column prop="version" label="版本" width="80" />
            <el-table-column prop="items_count" label="配置项数" width="100" />
            <el-table-column prop="updated_at" label="更新时间" />
          </el-table>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { statusApi } from '@/api/config'
import { ElMessage } from 'element-plus'

// 数据
const nginxStatus = ref({})
const connections = ref({})
const requestStats = ref({ by_status: {}, by_method: {} })
const cacheData = ref([])

let refreshTimer = null

// 加载数据
const loadNginxStatus = async () => {
  try {
    nginxStatus.value = await statusApi.nginx()
  } catch (e) {
    ElMessage.error('加载 Nginx 状态失败: ' + e.message)
  }
}

const loadConnections = async () => {
  try {
    connections.value = await statusApi.connections()
  } catch (e) {
    ElMessage.error('加载连接统计失败: ' + e.message)
  }
}

const loadRequestStats = async () => {
  try {
    requestStats.value = await statusApi.requests()
  } catch (e) {
    ElMessage.error('加载请求统计失败: ' + e.message)
  }
}

const loadCache = async () => {
  try {
    const cache = await statusApi.cache()
    cacheData.value = Object.entries(cache).map(([domain, data]) => ({
      domain,
      version: data.version || '-',
      items_count: data.items_count || 0,
      updated_at: data.updated_at || '-'
    }))
  } catch (e) {
    ElMessage.error('加载缓存状态失败: ' + e.message)
  }
}

const loadAll = async () => {
  await Promise.all([
    loadNginxStatus(),
    loadConnections(),
    loadRequestStats(),
    loadCache()
  ])
}

// 格式化运行时间
const formatUptime = (seconds) => {
  if (!seconds) return '-'
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  return `${hours}h ${minutes}m`
}

// 计算百分比
const getPercentage = (count, total) => {
  if (!total) return 0
  return Math.round((count / total) * 100)
}

onMounted(() => {
  loadAll()
  // 每 30 秒刷新一次
  refreshTimer = setInterval(loadAll, 30000)
})

onUnmounted(() => {
  if (refreshTimer) {
    clearInterval(refreshTimer)
  }
})
</script>

<style scoped>
.monitor-page {
  padding: 0;
}

.status-cards {
  margin-bottom: 20px;
}

.status-card {
  display: flex;
  align-items: center;
  padding: 10px;
}

.status-card :deep(.el-card__body) {
  display: flex;
  align-items: center;
  width: 100%;
}

.card-icon {
  width: 64px;
  height: 64px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 16px;
  color: #fff;
}

.card-icon.nginx { background: linear-gradient(135deg, #00b894, #00cec9); }
.card-icon.workers { background: linear-gradient(135deg, #6c5ce7, #a29bfe); }
.card-icon.uptime { background: linear-gradient(135deg, #fdcb6e, #f39c12); }
.card-icon.connections { background: linear-gradient(135deg, #e17055, #d63031); }

.card-content {
  flex: 1;
}

.card-value {
  font-size: 28px;
  font-weight: 600;
  color: #303133;
}

.card-label {
  font-size: 14px;
  color: #909399;
  margin-top: 4px;
}

.info-card {
  height: 100%;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.connection-stats {
  display: flex;
  justify-content: space-around;
  padding: 20px 0;
}

.stat-item {
  text-align: center;
}

.stat-value {
  font-size: 32px;
  font-weight: 600;
  color: #409eff;
}

.stat-label {
  font-size: 14px;
  color: #909399;
  margin-top: 8px;
}

.request-stats {
  padding: 10px 0;
}

.stat-row {
  display: flex;
  align-items: center;
  margin-bottom: 16px;
}

.stat-row .stat-label {
  width: 50px;
  font-weight: 500;
}

.stat-row .el-progress {
  flex: 1;
}
</style>