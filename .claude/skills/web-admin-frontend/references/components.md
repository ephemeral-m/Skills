# 组件开发详细指南

## 表单组件开发

### 基础表单结构

```vue
<template>
  <el-form
    ref="formRef"
    :model="formData"
    :rules="formRules"
    :label-width="labelWidth"
    :label-position="labelPosition"
  >
    <slot :formData="formData" />
  </el-form>
</template>

<script setup lang="ts">
import { ref, reactive, provide } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'

interface Props {
  initialData?: Record<string, any>
  labelWidth?: string
  labelPosition?: 'left' | 'right' | 'top'
}

const props = withDefaults(defineProps<Props>(), {
  labelWidth: '120px',
  labelPosition: 'right'
})

const emit = defineEmits<{
  submit: [data: any]
  cancel: []
}>()

const formRef = ref<FormInstance>()
const formData = reactive({ ...props.initialData })

// 暴露验证方法
const validate = async () => {
  return formRef.value?.validate()
}

// 暴露重置方法
const reset = () => {
  formRef.value?.resetFields()
}

defineExpose({ validate, reset })
</script>
```

### 动态表单字段

```vue
<template>
  <div class="dynamic-fields">
    <div
      v-for="(item, index) in items"
      :key="index"
      class="dynamic-field-item"
    >
      <el-row :gutter="16">
        <el-col :span="10">
          <el-form-item :label="fieldLabel" :prop="`${propPath}.${index}.key`">
            <el-input v-model="item.key" placeholder="键" />
          </el-form-item>
        </el-col>
        <el-col :span="10">
          <el-form-item label="值" :prop="`${propPath}.${index}.value`">
            <el-input v-model="item.value" placeholder="值" />
          </el-form-item>
        </el-col>
        <el-col :span="4">
          <el-button type="danger" @click="removeItem(index)">
            删除
          </el-button>
        </el-col>
      </el-row>
    </div>

    <el-button type="primary" plain @click="addItem">
      添加 {{ fieldLabel }}
    </el-button>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'

interface Props {
  modelValue: Array<{ key: string; value: string }>
  fieldLabel?: string
  propPath?: string
}

const props = withDefaults(defineProps<Props>(), {
  fieldLabel: '字段',
  propPath: 'items'
})

const emit = defineEmits<{
  'update:modelValue': [value: typeof items.value]
}>()

const items = ref([...props.modelValue])

watch(items, (newVal) => {
  emit('update:modelValue', newVal)
}, { deep: true })

const addItem = () => {
  items.value.push({ key: '', value: '' })
}

const removeItem = (index: number) => {
  items.value.splice(index, 1)
}
</script>
```

### 表格组件开发

```vue
<template>
  <div class="config-table">
    <!-- 工具栏 -->
    <div class="table-toolbar">
      <el-button type="primary" @click="handleCreate">
        新增
      </el-button>
      <el-button @click="handleRefresh">
        刷新
      </el-button>
    </div>

    <!-- 表格 -->
    <el-table
      :data="data"
      v-loading="loading"
      :border="true"
      :stripe="true"
      @selection-change="handleSelectionChange"
    >
      <el-table-column type="selection" width="50" />
      <el-table-column prop="id" label="ID" width="150" />
      <el-table-column prop="name" label="名称" />
      <el-table-column label="操作" width="200" fixed="right">
        <template #default="{ row }">
          <el-button size="small" @click="handleEdit(row)">
            编辑
          </el-button>
          <el-popconfirm
            title="确定删除？"
            @confirm="handleDelete(row)"
          >
            <template #reference>
              <el-button size="small" type="danger">
                删除
              </el-button>
            </template>
          </el-popconfirm>
        </template>
      </el-table-column>
    </el-table>

    <!-- 分页 -->
    <el-pagination
      v-model:current-page="currentPage"
      v-model:page-size="pageSize"
      :total="total"
      :page-sizes="[10, 20, 50, 100]"
      layout="total, sizes, prev, pager, next"
      @size-change="handleSizeChange"
      @current-change="handleCurrentChange"
    />
  </div>
</template>
```

## 页面组件开发

### 配置管理页面模板

```vue
<template>
  <div class="config-page">
    <!-- 页面标题 -->
    <el-page-header @back="goBack">
      <template #content>
        <span class="page-title">{{ pageTitle }}</span>
      </template>
    </el-page-header>

    <!-- 主内容区 -->
    <el-tabs v-model="activeTab">
      <!-- 列表视图 -->
      <el-tab-pane label="列表" name="list">
        <ConfigTable
          :data="configList"
          :loading="loading"
          @edit="handleEdit"
          @delete="handleDelete"
          @create="handleCreate"
        />
      </el-tab-pane>

      <!-- 配置预览 -->
      <el-tab-pane label="配置预览" name="preview">
        <ConfigPreview :config="generatedConfig" />
      </el-tab-pane>
    </el-tabs>

    <!-- 编辑对话框 -->
    <el-dialog
      v-model="dialogVisible"
      :title="dialogTitle"
      width="600px"
      destroy-on-close
    >
      <ConfigForm
        ref="formRef"
        :initial-data="editingItem"
        @submit="handleSubmit"
        @cancel="handleCancel"
      />
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { configApi } from '@/api/config'
import ConfigTable from '@/components/tables/ConfigTable.vue'
import ConfigForm from '@/components/forms/ConfigForm.vue'

const router = useRouter()
const activeTab = ref('list')
const dialogVisible = ref(false)
const editingItem = ref(null)
const configList = ref([])
const loading = ref(false)

// 获取配置列表
const fetchConfig = async () => {
  loading.value = true
  try {
    const data = await configApi.list('upstream')
    configList.value = data.items
  } catch (error) {
    ElMessage.error('获取配置失败')
  } finally {
    loading.value = false
  }
}

// 处理编辑
const handleEdit = (item: any) => {
  editingItem.value = { ...item }
  dialogVisible.value = true
}

// 处理提交
const handleSubmit = async (data: any) => {
  try {
    if (editingItem.value?.id) {
      await configApi.update('upstream', editingItem.value.id, data)
    } else {
      await configApi.create('upstream', data)
    }
    ElMessage.success('保存成功')
    dialogVisible.value = false
    fetchConfig()
  } catch (error) {
    ElMessage.error('保存失败')
  }
}

onMounted(() => {
  fetchConfig()
})
</script>
```

## 部署页面组件

```vue
<template>
  <div class="deploy-page">
    <!-- 状态卡片 -->
    <el-row :gutter="16">
      <el-col :span="6">
        <el-card>
          <template #header>
            <span>Nginx 状态</span>
          </template>
          <div class="status-value">
            <el-tag :type="status.nginx_running ? 'success' : 'danger'">
              {{ status.nginx_running ? '运行中' : '已停止' }}
            </el-tag>
          </div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <template #header>
            <span>配置版本</span>
          </template>
          <div class="status-value">{{ status.last_deploy || '-' }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <template #header>
            <span>Upstream 数量</span>
          </template>
          <div class="status-value">{{ status.config_stats?.upstreams || 0 }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <template #header>
            <span>Location 数量</span>
          </template>
          <div class="status-value">{{ status.config_stats?.locations || 0 }}</div>
        </el-card>
      </el-col>
    </el-row>

    <!-- 操作按钮 -->
    <el-card class="action-card">
      <el-button type="primary" @click="handlePreview" :loading="previewLoading">
        预览配置
      </el-button>
      <el-button type="success" @click="handleApply" :loading="applyLoading">
        应用配置
      </el-button>
      <el-button @click="fetchStatus">
        刷新状态
      </el-button>
    </el-card>

    <!-- 配置预览 -->
    <el-card v-if="previewConfig">
      <template #header>
        <span>生成的配置</span>
      </template>
      <pre class="config-preview">{{ previewConfig }}</pre>
    </el-card>

    <!-- 部署历史 -->
    <el-card>
      <template #header>
        <span>部署历史</span>
      </template>
      <el-table :data="history" v-loading="historyLoading">
        <el-table-column prop="version" label="版本" />
        <el-table-column prop="timestamp" label="时间" />
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button size="small" @click="handleRollback(row.version)">
              回滚
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { deployApi } from '@/api/deploy'

const status = ref<any>({})
const history = ref<any[]>([])
const previewConfig = ref('')
const previewLoading = ref(false)
const applyLoading = ref(false)
const historyLoading = ref(false)

// 获取状态
const fetchStatus = async () => {
  status.value = await deployApi.status()
}

// 预览配置
const handlePreview = async () => {
  previewLoading.value = true
  try {
    const result = await deployApi.preview()
    previewConfig.value = result.full
  } finally {
    previewLoading.value = false
  }
}

// 应用配置
const handleApply = async () => {
  await ElMessageBox.confirm(
    '确定要应用当前配置到生产实例吗？',
    '确认操作'
  )

  applyLoading.value = true
  try {
    const result = await deployApi.apply()
    if (result.success) {
      ElMessage.success('配置应用成功')
      fetchStatus()
      fetchHistory()
    } else {
      ElMessage.error(result.message)
    }
  } finally {
    applyLoading.value = false
  }
}

// 回滚
const handleRollback = async (version: string) => {
  await ElMessageBox.confirm(
    `确定要回滚到版本 ${version} 吗？`,
    '确认回滚'
  )

  try {
    const result = await deployApi.rollback(version)
    if (result.success) {
      ElMessage.success('回滚成功')
      fetchStatus()
    } else {
      ElMessage.error(result.message)
    }
  } catch (error) {
    ElMessage.error('回滚失败')
  }
}

// 获取历史
const fetchHistory = async () => {
  historyLoading.value = true
  try {
    const result = await deployApi.history()
    history.value = result.history
  } finally {
    historyLoading.value = false
  }
}

onMounted(() => {
  fetchStatus()
  fetchHistory()
})
</script>

<style scoped>
.config-preview {
  background: #1e1e1e;
  color: #d4d4d4;
  padding: 16px;
  border-radius: 4px;
  overflow: auto;
  max-height: 400px;
  font-family: 'Fira Code', monospace;
  font-size: 13px;
  line-height: 1.5;
}

.status-value {
  font-size: 24px;
  font-weight: bold;
  text-align: center;
}

.action-card {
  margin: 16px 0;
}
</style>
```