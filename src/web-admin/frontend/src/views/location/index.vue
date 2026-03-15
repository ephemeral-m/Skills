<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建 Location
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
        <el-table-column prop="id" label="ID" width="120" />
        <el-table-column prop="path" label="路径" width="150">
          <template #default="{ row }">
            <el-tag type="primary">{{ row.path }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="proxy_pass" label="代理目标" min-width="180" />
        <el-table-column label="请求头" min-width="200">
          <template #default="{ row }">
            <div class="headers-preview" v-if="row.proxy_set_header">
              <el-tag v-for="(value, key) in row.proxy_set_header" :key="key" size="small" class="header-tag">
                {{ key }}
              </el-tag>
            </div>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column label="限流" width="100">
          <template #default="{ row }">
            <el-tag :type="row.rate_limit?.enabled ? 'warning' : 'info'" size="small">
              {{ row.rate_limit?.enabled ? row.rate_limit.rate : '未启用' }}
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
      :title="isEdit ? '编辑 Location' : '新建 Location'"
      width="700px"
    >
      <el-form :model="editForm" label-width="120px" ref="formRef">
        <el-form-item label="ID" prop="id">
          <el-input v-model="editForm.id" :disabled="isEdit" />
        </el-form-item>
        <el-form-item label="路径" prop="path" :rules="[{ required: true, message: '请输入路径' }]">
          <el-input v-model="editForm.path" placeholder="/api/" />
        </el-form-item>
        <el-form-item label="代理目标" prop="proxy_pass">
          <el-input v-model="editForm.proxy_pass" placeholder="http://backend_api" />
        </el-form-item>
        <el-form-item label="根目录" v-if="!editForm.proxy_pass">
          <el-input v-model="editForm.root" placeholder="/var/www/static" />
        </el-form-item>

        <el-divider content-position="left">请求头设置</el-divider>
        <el-form-item label="Host">
          <el-input v-model="editForm.proxy_set_header.Host" placeholder="$host" />
        </el-form-item>
        <el-form-item label="X-Real-IP">
          <el-input v-model="editForm.proxy_set_header['X-Real-IP']" placeholder="$remote_addr" />
        </el-form-item>
        <el-form-item label="X-Forwarded-For">
          <el-input v-model="editForm.proxy_set_header['X-Forwarded-For']" placeholder="$proxy_add_x_forwarded_for" />
        </el-form-item>

        <el-divider content-position="left">限流配置</el-divider>
        <el-form-item label="启用限流">
          <el-switch v-model="editForm.rate_limit.enabled" />
        </el-form-item>
        <template v-if="editForm.rate_limit.enabled">
          <el-form-item label="请求速率">
            <el-input v-model="editForm.rate_limit.rate" placeholder="100r/s" />
          </el-form-item>
          <el-form-item label="突发容量">
            <el-input-number v-model="editForm.rate_limit.burst" :min="1" :max="1000" />
          </el-form-item>
        </template>

        <el-divider content-position="left">超时配置</el-divider>
        <el-form-item label="连接超时">
          <el-input v-model="editForm.proxy_timeout.connect" placeholder="60s" />
        </el-form-item>
        <el-form-item label="发送超时">
          <el-input v-model="editForm.proxy_timeout.send" placeholder="60s" />
        </el-form-item>
        <el-form-item label="读取超时">
          <el-input v-model="editForm.proxy_timeout.read" placeholder="60s" />
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

const DOMAIN = 'location'

const loading = ref(false)
const configItems = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  path: '',
  proxy_pass: '',
  root: '',
  proxy_set_header: {
    Host: '$host',
    'X-Real-IP': '$remote_addr',
    'X-Forwarded-For': '$proxy_add_x_forwarded_for'
  },
  rate_limit: {
    enabled: false,
    rate: '100r/s',
    burst: 50
  },
  proxy_timeout: {
    connect: '60s',
    send: '60s',
    read: '60s'
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
    path: '',
    proxy_pass: '',
    root: '',
    proxy_set_header: {
      Host: '$host',
      'X-Real-IP': '$remote_addr',
      'X-Forwarded-For': '$proxy_add_x_forwarded_for'
    },
    rate_limit: { enabled: false, rate: '100r/s', burst: 50 },
    proxy_timeout: { connect: '60s', send: '60s', read: '60s' }
  })
  editDialogVisible.value = true
}

const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, JSON.parse(JSON.stringify(item)))
  if (!editForm.rate_limit) {
    editForm.rate_limit = { enabled: false, rate: '100r/s', burst: 50 }
  }
  if (!editForm.proxy_timeout) {
    editForm.proxy_timeout = { connect: '60s', send: '60s', read: '60s' }
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

.headers-preview {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.header-tag {
  margin: 2px;
}
</style>