<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建 TCP 监听器
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
        <el-table-column prop="id" label="监听器 ID" width="180" />
        <el-table-column label="监听" width="120">
          <template #default="{ row }">
            <el-tag>{{ row.listen }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="protocol" label="协议" width="100">
          <template #default="{ row }">
            <el-tag :type="row.protocol === 'tcp' ? 'primary' : 'warning'" size="small">
              {{ row.protocol?.toUpperCase() }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="后端服务器组" min-width="180">
          <template #default="{ row }">
            <el-tag v-if="row.server_group_ref" type="success">
              {{ row.server_group_ref }}
            </el-tag>
            <span v-else class="text-muted">未配置</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="editItem(row)">
              <el-icon><Edit /></el-icon> 编辑
            </el-button>
            <el-popconfirm
              title="确定要删除此监听器吗？"
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
      :title="isEdit ? '编辑 TCP 监听器' : '新建 TCP 监听器'"
      width="600px"
    >
      <el-form :model="editForm" label-width="140px" ref="formRef">
        <el-form-item label="监听器 ID" prop="id" :rules="[{ required: true, message: '请输入 ID' }]">
          <el-input v-model="editForm.id" :disabled="isEdit" placeholder="tcp_mysql_proxy" />
        </el-form-item>
        <el-form-item label="监听端口" prop="listen" :rules="[{ required: true, message: '请输入监听端口' }]">
          <el-input v-model="editForm.listen" placeholder="3306 或 53 udp" />
        </el-form-item>
        <el-form-item label="协议">
          <el-radio-group v-model="editForm.protocol">
            <el-radio label="tcp">TCP</el-radio>
            <el-radio label="udp">UDP</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="后端服务器组" prop="server_group_ref">
          <el-select v-model="editForm.server_group_ref" placeholder="选择服务器组" style="width: 100%" clearable>
            <el-option
              v-for="group in serverGroups"
              :key="group.id"
              :label="group.id"
              :value="group.id"
            />
          </el-select>
        </el-form-item>

        <el-divider content-position="left">Nginx 自定义配置</el-divider>
        <el-form-item label="自定义指令">
          <el-input
            v-model="editForm.custom_directives"
            type="textarea"
            :rows="4"
            placeholder="每行一条 nginx 指令，例如:&#10;proxy_buffer_size 16k&#10;proxy_connect_timeout 5s"
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
import { ref, reactive, onMounted } from 'vue'
import { configApi } from '@/api/config'
import { ElMessage } from 'element-plus'

const DOMAIN = 'listeners-tcp'

const loading = ref(false)
const configItems = ref([])
const serverGroups = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  listen: '',
  protocol: 'tcp',
  server_group_ref: '',
  custom_directives: ''
})

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

const loadServerGroups = async () => {
  try {
    const data = await configApi.list('server-groups')
    serverGroups.value = data.items || []
  } catch (e) {
    console.error('加载服务器组失败:', e)
  }
}

const showCreateDialog = () => {
  isEdit.value = false
  Object.assign(editForm, {
    id: '',
    listen: '',
    protocol: 'tcp',
    server_group_ref: '',
    custom_directives: ''
  })
  editDialogVisible.value = true
}

const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, {
    ...item,
    server_group_ref: item.server_group_ref || '',
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
  await loadServerGroups()
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

.text-muted {
  color: #909399;
}
</style>