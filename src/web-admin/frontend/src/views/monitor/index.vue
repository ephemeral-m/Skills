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
            <div class="card-label">Web-Admin 版本</div>
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
          <div class="card-icon lb">
            <el-icon size="32"><Connection /></el-icon>
          </div>
          <div class="card-content">
            <div class="card-value">{{ loadbalanceInfo.loaded ? '运行中' : '未运行' }}</div>
            <div class="card-label">负载均衡状态</div>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 配置统计卡片 -->
    <el-row :gutter="20" class="stats-cards">
      <el-col :span="4">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">{{ forwardRules.stats?.http_rules || 0 }}</div>
          <div class="stat-label">HTTP 监听器</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">{{ forwardRules.stats?.tcp_rules || 0 }}</div>
          <div class="stat-label">TCP/UDP 监听器</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">{{ forwardRules.stats?.routes || 0 }}</div>
          <div class="stat-label">路由规则</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">{{ forwardRules.stats?.server_groups || 0 }}</div>
          <div class="stat-label">服务器组</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">{{ forwardRules.stats?.servers || 0 }}</div>
          <div class="stat-label">后端服务器</div>
        </el-card>
      </el-col>
      <el-col :span="4">
        <el-card shadow="hover" class="stat-card">
          <div class="stat-value">{{ forwardRules.stats?.total_rules || 0 }}</div>
          <div class="stat-label">总规则数</div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 详细信息 -->
    <el-row :gutter="20">
      <!-- Web-Admin 信息 -->
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>Web-Admin 信息</span>
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
            <el-descriptions-item label="运行时间">{{ nginxStatus.uptime_human }}</el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>

      <!-- Loadbalance 模块信息 -->
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>负载均衡模块信息</span>
              <el-button text @click="loadLoadbalanceInfo">
                <el-icon><Refresh /></el-icon>
              </el-button>
            </div>
          </template>
          <el-descriptions :column="1" border>
            <el-descriptions-item label="版本">{{ loadbalanceInfo.version || '-' }}</el-descriptions-item>
            <el-descriptions-item label="状态">
              <el-tag :type="loadbalanceInfo.loaded ? 'success' : 'danger'">
                {{ loadbalanceInfo.loaded ? '运行中' : '未运行' }}
              </el-tag>
              <span v-if="loadbalanceInfo.pid" style="margin-left: 8px; color: #909399;">
                (PID: {{ loadbalanceInfo.pid }})
              </span>
            </el-descriptions-item>
            <el-descriptions-item label="配置目录">{{ loadbalanceInfo.config_dir || '-' }}</el-descriptions-item>
            <el-descriptions-item label="编译参数">
              <div class="compile-args" v-if="loadbalanceInfo.compile_args?.length">
                <el-tag v-for="(arg, i) in loadbalanceInfo.compile_args.slice(0, 8)" :key="i" size="small" class="arg-tag">
                  {{ arg }}
                </el-tag>
                <el-tag v-if="loadbalanceInfo.compile_args.length > 8" size="small" type="info">
                  +{{ loadbalanceInfo.compile_args.length - 8 }} 更多
                </el-tag>
              </div>
              <span v-else>-</span>
            </el-descriptions-item>
          </el-descriptions>
        </el-card>
      </el-col>
    </el-row>

    <!-- 监听器规则 -->
    <el-row :gutter="20" style="margin-top: 20px;">
      <el-col :span="24">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>监听器规则</span>
              <el-button text @click="loadForwardRules">
                <el-icon><Refresh /></el-icon>
              </el-button>
            </div>
          </template>
          <el-table :data="forwardRules.rules || []" style="width: 100%">
            <el-table-column prop="id" label="规则 ID" width="180" />
            <el-table-column label="类型" width="100">
              <template #default="{ row }">
                <el-tag :type="row.type === 'HTTP' ? 'primary' : row.type === 'UDP' ? 'warning' : 'success'" size="small">
                  {{ row.type }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="监听端口" width="150">
              <template #default="{ row }">
                <el-tag v-for="(l, i) in row.listen" :key="i" size="small" style="margin-right: 4px;">
                  {{ l }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="服务器名称" width="150">
              <template #default="{ row }">
                {{ row.server_name || '-' }}
              </template>
            </el-table-column>
            <el-table-column label="后端服务器组" min-width="150">
              <template #default="{ row }">
                <el-tag v-if="row.server_group_ref" size="small" type="success">
                  {{ row.server_group_ref }}
                </el-tag>
                <span v-else style="color: #909399;">-</span>
              </template>
            </el-table-column>
            <el-table-column label="路由规则" min-width="200">
              <template #default="{ row }">
                <div class="route-refs" v-if="row.route_refs?.length">
                  <el-tag v-for="r in row.route_refs" :key="r" size="small" type="info" class="ref-tag">
                    {{ r }}
                  </el-tag>
                </div>
                <span v-else style="color: #909399;">-</span>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="100">
              <template #default="{ row }">
                <el-tag :type="row.status === 'active' ? 'success' : 'warning'" size="small">
                  {{ row.status === 'active' ? '正常' : '缺少后端' }}
                </el-tag>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>
    </el-row>

    <!-- 路由规则详情 -->
    <el-row :gutter="20" style="margin-top: 20px;">
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>路由规则</span>
            </div>
          </template>
          <el-table :data="forwardRules.route_details || []" style="width: 100%" max-height="300">
            <el-table-column prop="id" label="路由 ID" width="120" />
            <el-table-column prop="path" label="路径" width="150" />
            <el-table-column label="后端服务器组" min-width="150">
              <template #default="{ row }">
                <div v-if="row.server_group_ref">
                  <el-tag size="small" type="success">{{ row.server_group_ref }}</el-tag>
                  <span v-if="row.server_count" style="margin-left: 4px; color: #909399;">
                    ({{ row.server_count }} 服务器)
                  </span>
                </div>
                <el-tag v-else-if="row.has_custom" size="small" type="info">自定义配置</el-tag>
                <span v-else style="color: #909399;">-</span>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="80">
              <template #default="{ row }">
                <el-tag :type="row.status === 'active' ? 'success' : 'warning'" size="small">
                  {{ row.status === 'active' ? '正常' : '异常' }}
                </el-tag>
              </template>
            </el-table-column>
          </el-table>
        </el-card>
      </el-col>

      <!-- 服务器组详情 -->
      <el-col :span="12">
        <el-card class="info-card">
          <template #header>
            <div class="card-header">
              <span>服务器组</span>
            </div>
          </template>
          <el-table :data="forwardRules.server_group_details || []" style="width: 100%" max-height="300">
            <el-table-column prop="id" label="组 ID" width="120" />
            <el-table-column label="调度算法" width="120">
              <template #default="{ row }">
                <el-tag size="small">{{ row.balance }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="服务器数量" width="100">
              <template #default="{ row }">
                {{ row.server_count }}
              </template>
            </el-table-column>
            <el-table-column label="服务器列表" min-width="200">
              <template #default="{ row }">
                <div class="server-list" v-if="row.servers?.length">
                  <div v-for="s in row.servers" :key="s.id" class="server-item">
                    {{ s.host }}:{{ s.port }}
                    <span v-if="s.weight !== 1" style="color: #909399;">(w:{{ s.weight }})</span>
                  </div>
                </div>
                <span v-else style="color: #909399;">无服务器</span>
              </template>
            </el-table-column>
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
const loadbalanceInfo = ref({})
const forwardRules = ref({ rules: [], route_details: [], server_group_details: [], stats: {} })

let refreshTimer = null

// 加载数据
const loadNginxStatus = async () => {
  try {
    const response = await statusApi.nginx()
    nginxStatus.value = response.data || response
  } catch (e) {
    ElMessage.error('加载 Web-Admin 状态失败: ' + e.message)
  }
}

const loadLoadbalanceInfo = async () => {
  try {
    const response = await statusApi.loadbalance()
    loadbalanceInfo.value = response.data || {
      version: '-',
      compile_args: [],
      loaded: false
    }
  } catch (e) {
    loadbalanceInfo.value = {
      version: '-',
      compile_args: [],
      loaded: false
    }
  }
}

const loadForwardRules = async () => {
  try {
    const response = await statusApi.forwardRules()
    // API 返回 { success, message, data }，需要提取 data
    forwardRules.value = response.data || { rules: [], route_details: [], server_group_details: [], stats: {} }
  } catch (e) {
    forwardRules.value = { rules: [], route_details: [], server_group_details: [], stats: {} }
  }
}

const loadAll = async () => {
  await Promise.all([
    loadNginxStatus(),
    loadLoadbalanceInfo(),
    loadForwardRules()
  ])
}

// 格式化运行时间
const formatUptime = (seconds) => {
  if (!seconds) return '-'
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  return `${hours}h ${minutes}m`
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

.stats-cards {
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
.card-icon.lb { background: linear-gradient(135deg, #e17055, #d63031); }

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

.stat-card {
  text-align: center;
  padding: 16px;
}

.stat-card :deep(.el-card__body) {
  padding: 16px;
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

.info-card {
  height: 100%;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.compile-args {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.arg-tag {
  margin: 2px;
}

.route-refs {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.ref-tag {
  margin: 2px;
}

.server-list {
  font-size: 12px;
  line-height: 1.6;
}

.server-item {
  padding: 2px 0;
}
</style>