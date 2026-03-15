<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建 Upstream
          </el-button>
          <el-button @click="loadData">
            <el-icon><Refresh /></el-icon> 刷新
          </el-button>
        </div>
        <div class="toolbar-right">
          <el-button @click="showHistoryDialog">
            <el-icon><Clock /></el-icon> 历史版本
          </el-button>
        </div>
      </div>
    </el-card>

    <!-- 数据表格 -->
    <el-card>
      <el-table :data="configItems" v-loading="loading" style="width: 100%">
        <el-table-column prop="id" label="Upstream ID" width="150" />
        <el-table-column label="负载均衡" width="120">
          <template #default="{ row }">
            <el-tag size="small">{{ getBalanceLabel(row.balance) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="服务器列表" min-width="300">
          <template #default="{ row }">
            <div class="server-list">
              <el-tag
                v-for="(server, index) in row.servers"
                :key="index"
                :type="server.backup ? 'warning' : 'success'"
                size="small"
                class="server-tag"
              >
                {{ server.host }}:{{ server.port }}
                <span v-if="server.weight > 1">(w:{{ server.weight }})</span>
                <span v-if="server.backup">(backup)</span>
              </el-tag>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="健康检查" width="100">
          <template #default="{ row }">
            <el-tag :type="row.health_check?.enabled ? 'success' : 'info'" size="small">
              {{ row.health_check?.enabled ? '已启用' : '未启用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="editItem(row)">
              <el-icon><Edit /></el-icon> 编辑
            </el-button>
            <el-popconfirm
              title="确定要删除此配置吗？"
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
      :title="isEdit ? '编辑 Upstream' : '新建 Upstream'"
      width="700px"
    >
      <el-form :model="editForm" label-width="120px" ref="formRef">
        <el-form-item label="Upstream ID" prop="id" :rules="[{ required: true, message: '请输入 ID' }]">
          <el-input v-model="editForm.id" :disabled="isEdit" placeholder="backend_api" />
        </el-form-item>
        <el-form-item label="负载均衡">
          <el-select v-model="editForm.balance" style="width: 100%">
            <el-option label="轮询 (Round Robin)" value="round_robin" />
            <el-option label="最少连接 (Least Conn)" value="least_conn" />
            <el-option label="IP 哈希 (IP Hash)" value="ip_hash" />
          </el-select>
        </el-form-item>
        <el-form-item label="服务器列表">
          <div class="servers-config">
            <div v-for="(server, index) in editForm.servers" :key="index" class="server-row">
              <el-input v-model="server.host" placeholder="主机地址" style="width: 150px" />
              <el-input-number v-model="server.port" :min="1" :max="65535" placeholder="端口" style="width: 120px" />
              <el-input-number v-model="server.weight" :min="1" :max="100" placeholder="权重" style="width: 100px" />
              <el-checkbox v-model="server.backup">备份</el-checkbox>
              <el-button type="danger" :icon="Delete" circle @click="removeServer(index)" />
            </div>
            <el-button type="primary" plain @click="addServer">
              <el-icon><Plus /></el-icon> 添加服务器
            </el-button>
          </div>
        </el-form-item>
        <el-divider content-position="left">健康检查</el-divider>
        <el-form-item label="启用健康检查">
          <el-switch v-model="editForm.health_check.enabled" />
        </el-form-item>
        <template v-if="editForm.health_check.enabled">
          <el-form-item label="检查间隔">
            <el-input v-model="editForm.health_check.interval" placeholder="5s" />
          </el-form-item>
          <el-form-item label="失败阈值">
            <el-input-number v-model="editForm.health_check.fails" :min="1" :max="10" />
          </el-form-item>
          <el-form-item label="恢复阈值">
            <el-input-number v-model="editForm.health_check.passes" :min="1" :max="10" />
          </el-form-item>
        </template>
        <el-divider content-position="left">连接配置</el-divider>
        <el-form-item label="保持连接数">
          <el-input-number v-model="editForm.keepalive" :min="0" :max="1000" />
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
import { ref, reactive, onMounted } from 'vue'
import { configApi } from '@/api/config'
import { ElMessage } from 'element-plus'
import { Delete, Plus } from '@element-plus/icons-vue'

const DOMAIN = 'upstream'

const loading = ref(false)
const configItems = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  balance: 'round_robin',
  servers: [{ host: '', port: 8080, weight: 1, backup: false }],
  keepalive: 32,
  health_check: {
    enabled: false,
    interval: '5s',
    fails: 3,
    passes: 2
  }
})

const getBalanceLabel = (balance) => {
  const labels = {
    round_robin: '轮询',
    least_conn: '最少连接',
    ip_hash: 'IP 哈希'
  }
  return labels[balance] || balance
}

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

const showCreateDialog = () => {
  isEdit.value = false
  Object.assign(editForm, {
    id: '',
    balance: 'round_robin',
    servers: [{ host: '', port: 8080, weight: 1, backup: false }],
    keepalive: 32,
    health_check: { enabled: false, interval: '5s', fails: 3, passes: 2 }
  })
  editDialogVisible.value = true
}

const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, JSON.parse(JSON.stringify(item)))
  editForm.servers.forEach(s => {
    if (s.backup === undefined) s.backup = false
  })
  editDialogVisible.value = true
}

const addServer = () => {
  editForm.servers.push({ host: '', port: 8080, weight: 1, backup: false })
}

const removeServer = (index) => {
  editForm.servers.splice(index, 1)
}

const saveItem = async () => {
  try {
    await formRef.value?.validate()
    if (isEdit.value) {
      await configApi.update(DOMAIN, editForm.id, editForm)
      ElMessage.success('更新成功')
    } else {
      await configApi.create(DOMAIN, editForm)
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

onMounted(() => {
  loadData()
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

.servers-config {
  width: 100%;
}

.server-row {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 10px;
}
</style>