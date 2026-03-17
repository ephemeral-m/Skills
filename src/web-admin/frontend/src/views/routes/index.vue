<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建路由规则
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
        <el-table-column prop="id" label="规则 ID" width="180" />
        <el-table-column prop="path" label="路径" width="200">
          <template #default="{ row }">
            <el-tag type="primary">{{ row.path }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="后端服务器组" min-width="200">
          <template #default="{ row }">
            <el-tag v-if="row.server_group_ref" type="success">
              {{ row.server_group_ref }}
            </el-tag>
            <span v-else class="text-muted">未配置</span>
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
              被 {{ row.referenced_by.length }} 个监听器引用
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
              title="确定要删除此路由规则吗？"
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
      :title="isEdit ? '编辑路由规则' : '新建路由规则'"
      width="600px"
    >
      <el-form :model="editForm" label-width="140px" ref="formRef">
        <el-form-item label="规则 ID" prop="id" :rules="[{ required: true, message: '请输入 ID' }]">
          <el-input v-model="editForm.id" :disabled="isEdit" placeholder="api_route" />
        </el-form-item>
        <el-form-item label="路径" prop="path" :rules="[{ required: true, message: '请输入路径' }]">
          <el-input v-model="editForm.path" placeholder="/api/v1/" />
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
            :rows="6"
            placeholder="每行一条 nginx 指令，例如:&#10;proxy_http_version 1.1&#10;proxy_set_header Connection &#34;&#34;&#10;client_max_body_size 100m"
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

const DOMAIN = 'routes'

const loading = ref(false)
const configItems = ref([])
const serverGroups = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  path: '',
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
    path: '',
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

.directives-preview {
  color: #606266;
  font-size: 13px;
}
</style>