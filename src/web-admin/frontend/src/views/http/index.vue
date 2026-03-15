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
        <el-table-column prop="id" label="ID" width="180" />
        <el-table-column prop="server_name" label="服务器名称" min-width="150">
          <template #default="{ row }">
            {{ row.server_name || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="监听端口" width="200">
          <template #default="{ row }">
            <template v-if="row.listen && Array.isArray(row.listen)">
              <el-tag v-for="(l, i) in row.listen" :key="i" size="small" style="margin-right: 4px;">
                {{ l.port }}{{ l.ssl ? ' (SSL)' : '' }}
              </el-tag>
            </template>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column prop="root" label="根目录" min-width="180">
          <template #default="{ row }">
            {{ row.root || '-' }}
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
        <el-form-item label="服务器名称" prop="server_name">
          <el-input v-model="editForm.server_name" />
        </el-form-item>
        <el-form-item label="监听配置">
          <div v-for="(listen, index) in editForm.listen" :key="index" class="listen-item">
            <el-input-number v-model="listen.port" :min="1" :max="65535" placeholder="端口" />
            <el-switch v-model="listen.ssl" active-text="SSL" inactive-text="TCP" />
            <el-button type="danger" :icon="Delete" circle @click="editForm.listen.splice(index, 1)" />
          </div>
          <el-button type="primary" plain @click="editForm.listen.push({ port: 80, ssl: false })">
            添加监听端口
          </el-button>
        </el-form-item>
        <el-form-item label="根目录">
          <el-input v-model="editForm.root" />
        </el-form-item>
        <el-form-item label="索引文件">
          <el-input v-model="editForm.index" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editDialogVisible = false">取消</el-button>
        <el-button type="primary" @click="saveItem">保存</el-button>
      </template>
    </el-dialog>

    <!-- 历史版本对话框 -->
    <el-dialog v-model="historyDialogVisible" title="历史版本" width="500px">
      <el-table :data="historyVersions" v-loading="historyLoading">
        <el-table-column prop="version" label="版本号" width="100" />
        <el-table-column label="操作" width="100">
          <template #default="{ row }">
            <el-popconfirm
              title="确定要回滚到此版本吗？"
              @confirm="rollbackTo(row.version)"
            >
              <template #reference>
                <el-button type="primary" text>回滚</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { configApi } from '@/api/config'
import { ElMessage } from 'element-plus'
import { Delete } from '@element-plus/icons-vue'

const DOMAIN = 'http'

const loading = ref(false)
const configItems = ref([])
const editDialogVisible = ref(false)
const historyDialogVisible = ref(false)
const historyLoading = ref(false)
const historyVersions = ref([])
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  server_name: '',
  listen: [{ port: 80, ssl: false }],
  root: '/var/www/html',
  index: 'index.html index.htm'
})

// 加载数据
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

// 显示创建对话框
const showCreateDialog = () => {
  isEdit.value = false
  Object.assign(editForm, {
    id: '',
    server_name: '',
    listen: [{ port: 80, ssl: false }],
    root: '/var/www/html',
    index: 'index.html index.htm'
  })
  editDialogVisible.value = true
}

// 编辑项目
const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, item)
  editDialogVisible.value = true
}

// 保存项目
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

// 删除项目
const deleteItem = async (id) => {
  try {
    await configApi.delete(DOMAIN, id)
    ElMessage.success('删除成功')
    loadData()
  } catch (e) {
    ElMessage.error('删除失败: ' + e.message)
  }
}

// 显示历史版本
const showHistoryDialog = async () => {
  historyDialogVisible.value = true
  historyLoading.value = true
  try {
    const data = await configApi.history(DOMAIN)
    historyVersions.value = (data.versions || []).map(v => ({ version: v }))
  } catch (e) {
    ElMessage.error('加载历史版本失败: ' + e.message)
  } finally {
    historyLoading.value = false
  }
}

// 回滚
const rollbackTo = async (version) => {
  try {
    await configApi.rollback(DOMAIN, version)
    ElMessage.success('回滚成功')
    historyDialogVisible.value = false
    loadData()
  } catch (e) {
    ElMessage.error('回滚失败: ' + e.message)
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

.listen-item {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 10px;
}
</style>