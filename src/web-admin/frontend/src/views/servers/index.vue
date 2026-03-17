<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建服务器
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
        <el-table-column prop="id" label="ID" width="150" />
        <el-table-column prop="host" label="主机地址" min-width="150" />
        <el-table-column prop="port" label="端口" width="100">
          <template #default="{ row }">
            <el-tag>{{ row.port }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="weight" label="权重" width="80">
          <template #default="{ row }">
            {{ row.weight || 1 }}
          </template>
        </el-table-column>
        <el-table-column label="引用状态" min-width="120">
          <template #default="{ row }">
            <el-tag v-if="row.referenced_by && row.referenced_by.length > 0" type="success">
              已被 {{ row.referenced_by.length }} 个组引用
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
              title="确定要删除此服务器吗？"
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
      :title="isEdit ? '编辑服务器' : '新建服务器'"
      width="600px"
    >
      <el-form :model="editForm" label-width="120px" ref="formRef">
        <el-form-item label="ID" prop="id" :rules="[{ required: true, message: '请输入 ID' }]">
          <el-input v-model="editForm.id" :disabled="isEdit" placeholder="backend_server_1" />
        </el-form-item>
        <el-form-item label="主机地址" prop="host" :rules="[{ required: true, message: '请输入主机地址' }]">
          <el-input v-model="editForm.host" placeholder="192.168.1.100 或 backend.example.com" />
        </el-form-item>
        <el-form-item label="端口" prop="port" :rules="[{ required: true, message: '请输入端口' }]">
          <el-input-number v-model="editForm.port" :min="1" :max="65535" style="width: 100%" />
        </el-form-item>
        <el-form-item label="权重">
          <el-input-number v-model="editForm.weight" :min="1" :max="100" style="width: 100%" />
        </el-form-item>
        <el-divider content-position="left">Nginx 自定义配置</el-divider>
        <el-form-item label="自定义指令">
          <el-input
            v-model="editForm.custom_directives"
            type="textarea"
            :rows="4"
            placeholder="每行一条 nginx 指令，例如:&#10;max_fails=3&#10;fail_timeout=30s"
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

const DOMAIN = 'servers'

const loading = ref(false)
const configItems = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  host: '',
  port: 8080,
  weight: 1,
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

const showCreateDialog = () => {
  isEdit.value = false
  Object.assign(editForm, {
    id: '',
    host: '',
    port: 8080,
    weight: 1,
    custom_directives: ''
  })
  editDialogVisible.value = true
}

const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, {
    ...item,
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
</style>