<template>
  <div class="config-page">
    <!-- 操作栏 -->
    <el-card class="toolbar-card">
      <div class="toolbar">
        <div class="toolbar-left">
          <el-button type="primary" @click="showCreateDialog">
            <el-icon><Plus /></el-icon> 新建 HTTP 监听器
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
        <el-table-column prop="id" label="监听器 ID" width="150" />
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
        <el-table-column label="路由规则" min-width="200">
          <template #default="{ row }">
            <div v-if="row.route_refs && row.route_refs.length > 0" class="route-list">
              <el-tag
                v-for="routeId in row.route_refs"
                :key="routeId"
                type="success"
                size="small"
                class="route-tag"
              >
                {{ routeId }}
              </el-tag>
            </div>
            <span v-else class="text-muted">未配置路由</span>
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
      :title="isEdit ? '编辑 HTTP 监听器' : '新建 HTTP 监听器'"
      width="750px"
    >
      <el-form :model="editForm" label-width="120px" ref="formRef">
        <el-form-item label="监听器 ID" prop="id" :rules="[{ required: true, message: '请输入 ID' }]">
          <el-input v-model="editForm.id" :disabled="isEdit" placeholder="http_server_1" />
        </el-form-item>
        <el-form-item label="服务器名称" prop="server_name">
          <el-input v-model="editForm.server_name" placeholder="example.com" />
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
        <el-form-item label="路由规则">
          <el-transfer
            v-model="editForm.route_refs"
            :data="availableRoutes"
            :titles="['可选路由', '已选路由']"
            :props="{
              key: 'id',
              label: 'display'
            }"
            filterable
            filter-placeholder="搜索路由规则"
          />
        </el-form-item>

        <el-divider content-position="left">Nginx 自定义配置</el-divider>
        <el-form-item label="自定义指令">
          <el-input
            v-model="editForm.custom_directives"
            type="textarea"
            :rows="6"
            placeholder="每行一条 nginx 指令，例如:&#10;client_max_body_size 50m&#10;gzip on&#10;gzip_types text/plain application/json"
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
import { Delete } from '@element-plus/icons-vue'

const DOMAIN = 'listeners-http'

const loading = ref(false)
const configItems = ref([])
const allRoutes = ref([])
const editDialogVisible = ref(false)
const isEdit = ref(false)
const formRef = ref(null)

const editForm = reactive({
  id: '',
  server_name: '',
  listen: [{ port: 80, ssl: false }],
  route_refs: [],
  custom_directives: ''
})

// 可用路由列表
const availableRoutes = computed(() => {
  return allRoutes.value.map(r => ({
    id: r.id,
    display: `${r.id} (${r.path})`
  }))
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

const loadRoutes = async () => {
  try {
    const data = await configApi.list('routes')
    allRoutes.value = data.items || []
  } catch (e) {
    console.error('加载路由规则失败:', e)
  }
}

const showCreateDialog = () => {
  isEdit.value = false
  Object.assign(editForm, {
    id: '',
    server_name: '',
    listen: [{ port: 80, ssl: false }],
    route_refs: [],
    custom_directives: ''
  })
  editDialogVisible.value = true
}

const editItem = (item) => {
  isEdit.value = true
  Object.assign(editForm, {
    ...item,
    listen: item.listen || [{ port: 80, ssl: false }],
    route_refs: item.route_refs || [],
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
  await loadRoutes()
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

.listen-item {
  display: flex;
  gap: 10px;
  align-items: center;
  margin-bottom: 10px;
}

.route-list {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.route-tag {
  margin: 2px;
}

.text-muted {
  color: #909399;
}
</style>