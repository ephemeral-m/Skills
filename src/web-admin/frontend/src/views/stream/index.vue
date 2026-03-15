<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建配置
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
        <el-table-column prop="id" label="ID" width="150" />
        <el-table-column label="监听" width="150">
          <template #default="{ row }">
            <el-tag>{{ row.listen }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="protocol" label="协议" width="80">
          <template #default="{ row }">
            <el-tag :type="row.protocol === 'tcp' ? 'primary' : 'warning'" size="small">
              {{ row.protocol?.toUpperCase() }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="proxy_pass" label="代理目标" min-width="150" />
        <el-table-column label="超时配置" min-width="200">
          <template #default="{ row }">
            <span v-if="row.timeout">
              连接: {{ row.timeout.connect || '-' }} |
              读: {{ row.timeout.read || '-' }} |
              写: {{ row.timeout.send || '-' }}
            </span>
            <span v-else>-</span>
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
      :title="isEdit ? '编辑配置' : '新建配置'"
      width="600px"
    >
      <el-form :model="editForm" label-width="120px" ref="formRef">
        <el-form-item label="ID" prop="id" :rules="[{ required: true, message: '请输入 ID' }]">
          <el-input v-model="editForm.id" :disabled="isEdit" />
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
        <el-form-item label="代理目标" prop="proxy_pass">
          <el-input v-model="editForm.proxy_pass" placeholder="upstream_name 或 host:port" />
        </el-form-item>
        <el-divider content-position="left">超时配置</el-divider>
        <el-form-item label="连接超时">
          <el-input v-model="editForm.timeout.connect" placeholder="5s" />
        </el-form-item>
        <el-form-item label="读取超时">
          <el-input v-model="editForm.timeout.read" placeholder="30s" />
        </el-form-item>
        <el-form-item label="发送超时">
          <el-input v-model="editForm.timeout.send" placeholder="30s" />
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

const DOMAIN = 'stream'

const loading = ref(false)
const configItems = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  listen: '',
  protocol: 'tcp',
  proxy_pass: '',
  timeout: {
    connect: '5s',
    read: '30s',
    send: '30s'
  }
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
    listen: '',
    protocol: 'tcp',
    proxy_pass: '',
    timeout: { connect: '5s', read: '30s', send: '30s' }
  })
  editDialogVisible.value = true
}

const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, item)
  if (!editForm.timeout) {
    editForm.timeout = { connect: '5s', read: '30s', send: '30s' }
  }
  editDialogVisible.value = true
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
</style>