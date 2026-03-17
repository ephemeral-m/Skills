<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建服务器组
          </el-button>
          <el-button @click="loadData">
            <el-icon><Refresh /></el-icon> 刷新
          </el-button>
        </div>
      </div>
    </el-card>

    <!-- 数据表格 -->
    <el-card>
      <el-table :data="configItems" v-loading="loading" style="width: 100%">
        <el-table-column prop="id" label="组 ID" width="180" />
        <el-table-column label="调度算法" width="120">
          <template #default="{ row }">
            <el-tag size="small">{{ getBalanceLabel(row.balance) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="成员服务器" min-width="300">
          <template #default="{ row }">
            <div class="server-list" v-if="row.server_refs && row.server_refs.length > 0">
              <el-tag
                v-for="serverId in row.server_refs"
                :key="serverId"
                type="success"
                size="small"
                class="server-tag"
              >
                {{ getServerDisplay(serverId) }}
              </el-tag>
            </div>
            <span v-else class="text-muted">未配置服务器</span>
          </template>
        </el-table-column>
        <el-table-column label="Nginx 自定义配置" min-width="200">
          <template #default="{ row }">
            <span v-if="row.custom_directives" class="directives-preview">
              {{ row.custom_directives.split('\n').slice(0, 2).join('; ') }}
              {{ row.custom_directives.split('\n').length > 2 ? '...' : '' }}
            </span>
            <span v-else class="text-muted">无</span>
          </template>
        </el-table-column>
        <el-table-column label="引用状态" min-width="120">
          <template #default="{ row }">
            <el-tag v-if="row.referenced_by && row.referenced_by.length > 0" type="success">
              已被引用
            </el-tag>
            <el-tag v-else type="info">未被引用</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="editItem(row)">
              <el-icon><Edit /></el-icon> 编辑
            </el-button>
            <el-popconfirm
              title="确定要删除此服务器组吗？"
              @confirm="deleteItem(row.id)"
            >
              <template #reference>
                <el-button text type="danger">
                  <el-icon><Delete /></el-icon> 删除
                </el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 编辑对话框 -->
    <el-dialog
      v-model="editDialogVisible"
      :title="isEdit ? '编辑服务器组' : '新建服务器组'"
      width="700px"
    >
      <el-form :model="editForm" label-width="140px" ref="formRef">
        <el-form-item label="组 ID" prop="id" :rules="[{ required: true, message: '请输入 ID' }]">
          <el-input v-model="editForm.id" :disabled="isEdit" placeholder="backend_api" />
        </el-form-item>
        <el-form-item label="调度算法">
          <el-select v-model="editForm.balance" style="width: 100%">
            <el-option label="轮询 (Round Robin)" value="round_robin" />
            <el-option label="最少连接 (Least Conn)" value="least_conn" />
            <el-option label="IP 哈希 (IP Hash)" value="ip_hash" />
          </el-select>
        </el-form-item>
        <el-form-item label="成员服务器">
          <el-transfer
            v-model="editForm.server_refs"
            :data="availableServers"
            :titles="['可选服务器', '已选服务器']"
            :props="{
              key: 'id',
              label: 'display'
            }"
            filterable
            filter-placeholder="搜索服务器"
          />
        </el-form-item>

        <el-divider content-position="left">Nginx 自定义配置</el-divider>
        <el-form-item label="自定义指令">
          <el-input
            v-model="editForm.custom_directives"
            type="textarea"
            :rows="4"
            placeholder="每行一条 nginx 指令，例如:&#10;keepalive 32&#10;keepalive_timeout 60s"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveItem">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { configApi } from '@/api/config'
import { ElMessage } from 'element-plus'

const DOMAIN = 'server-groups'

const loading = ref(false)
const configItems = ref([])
const allServers = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  balance: 'round_robin',
  server_refs: [],
  custom_directives: ''
})

// 可用服务器列表（用于穿梭框）
const availableServers = computed(() => {
  return allServers.value.map(s => ({
    id: s.id,
    display: `${s.id} (${s.host}:${s.port})`
  }))
})

// 获取服务器显示名称
const getServerDisplay = (serverId) => {
  const server = allServers.value.find(s => s.id === serverId)
  if (server) {
    return `${server.id}`
  }
  return serverId
}

// 获取调度算法标签
const getBalanceLabel = (balance) => {
  const labels = {
    round_robin: '轮询',
    least_conn: '最少连接',
    ip_hash: 'IP 哈希'
  }
  return labels[balance] || balance
}

// 加载服务器组数据
const loadData = async () => {
  loading.value = true
  try {
    const data = await configApi.list(DOMAIN)
    configItems.value = data.items || []
  } catch (e) {
    ElMessage.error('加载数据失败: ' + e.message)
  } finally {
    loading.value = false
  }
}

// 加载所有后端服务器
const loadServers = async () => {
  try {
    const data = await configApi.list('servers')
    allServers.value = data.items || []
  } catch (e) {
    console.error('加载服务器列表失败:', e)
  }
}

const showCreateDialog = () => {
  isEdit.value = false
  Object.assign(editForm, {
    id: '',
    balance: 'round_robin',
    server_refs: [],
    custom_directives: ''
  })
  editDialogVisible.value = true
}

const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, {
    ...item,
    server_refs: item.server_refs || [],
    custom_directives: item.custom_directives || ''
  })
  editDialogVisible.value = true
}

const saveItem = async () => {
  try {
    await formRef.value?.validate()
    const payload = { ...editForm }
    if (!payload.custom_directives) delete payload.custom_directives

    if (isEdit.value) {
      await configApi.update(DOMAIN, editForm.id, payload)
      ElMessage.success('更新成功')
    } else {
      await configApi.create(DOMAIN, payload)
      ElMessage.success('创建成功')
    }
    editDialogVisible.value = false
    loadData()
  } catch (e) {
    ElMessage.error('保存失败: ' + e.message)
  }
}

const deleteItem = async (id) => {
  try {
    await configApi.delete(DOMAIN, id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    ElMessage.error('删除失败: ' + e.message)
  }
}

onMounted(async () => {
  await loadServers()
  await loadData()
})
</script>

<style scoped>
.toolbar-card {
  margin-bottom: 20px;
}

.toolbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.toolbar-left, .toolbar-right {
  display: flex;
  gap: 10px;
}

.server-list {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.server-tag {
  margin: 2px;
}

.text-muted {
  color: #909399;
}

.directives-preview {
  color: #606266;
  font-size: 13px;
}
</style>