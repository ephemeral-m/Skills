<template>
  <div class="wizard-page">
    <el-card>
      <template #header>
        <span>配置创建向导</span>
      </template>

      <!-- 步骤条 -->
      <el-steps :active="currentStep" finish-status="success" align-center>
        <el-step title="选择类型" />
        <el-step title="基本信息" />
        <el-step title="详细配置" />
        <el-step title="确认创建" />
      </el-steps>

      <!-- 步骤内容 -->
      <div class="step-content">
        <!-- Step 1: 选择类型 -->
        <div v-show="currentStep === 0" class="type-selector">
          <el-radio-group v-model="configType" @change="resetForm">
            <el-radio-button label="upstream">
              <el-icon><Link /></el-icon>
              Upstream 负载均衡
            </el-radio-button>
            <el-radio-button label="location">
              <el-icon><Position /></el-icon>
              Location 路由
            </el-radio-button>
            <el-radio-button label="http">
              <el-icon><Document /></el-icon>
              HTTP 服务器
            </el-radio-button>
            <el-radio-button label="stream">
              <el-icon><Connection /></el-icon>
              Stream 代理
            </el-radio-button>
          </el-radio-group>
        </div>

        <!-- Step 2: 基本信息 -->
        <div v-show="currentStep === 1">
          <el-form :model="formData" label-width="120px" :rules="rules" ref="formRef">
            <!-- Upstream 基本信息表单 -->
            <template v-if="configType === 'upstream'">
              <el-form-item label="Upstream ID" prop="id">
                <el-input v-model="formData.id" placeholder="backend_api" />
              </el-form-item>
              <el-form-item label="负载均衡" prop="balance">
                <el-select v-model="formData.balance" style="width: 100%">
                  <el-option label="轮询 (Round Robin)" value="round_robin" />
                  <el-option label="最少连接 (Least Conn)" value="least_conn" />
                  <el-option label="IP 哈希 (IP Hash)" value="ip_hash" />
                </el-select>
              </el-form-item>
              <el-form-item label="服务器列表">
                <div v-for="(server, index) in formData.servers" :key="index" class="server-item">
                  <el-input v-model="server.host" placeholder="主机地址" style="width: 150px" />
                  <el-input-number v-model="server.port" :min="1" :max="65535" placeholder="端口" style="width: 120px" />
                  <el-input-number v-model="server.weight" :min="1" :max="100" placeholder="权重" style="width: 100px" />
                  <el-button type="danger" :icon="Delete" circle @click="removeServer(index)" />
                </div>
                <el-button type="primary" plain @click="addServer">
                  <el-icon><Plus /></el-icon> 添加服务器
                </el-button>
              </el-form-item>
            </template>

            <!-- Location 基本信息表单 -->
            <template v-else-if="configType === 'location'">
              <el-form-item label="路径" prop="path">
                <el-input v-model="formData.path" placeholder="/api/" />
              </el-form-item>
              <el-form-item label="代理地址" prop="proxy_pass">
                <el-input v-model="formData.proxy_pass" placeholder="http://backend_api" />
              </el-form-item>
            </template>

            <!-- HTTP 基本信息表单 -->
            <template v-else-if="configType === 'http'">
              <el-form-item label="服务器名称" prop="server_name">
                <el-input v-model="formData.server_name" placeholder="example.com" />
              </el-form-item>
              <el-form-item label="监听端口">
                <el-input-number v-model="formData.listen_port" :min="1" :max="65535" />
              </el-form-item>
              <el-form-item label="SSL">
                <el-switch v-model="formData.ssl" />
              </el-form-item>
            </template>

            <!-- Stream 基本信息表单 -->
            <template v-else-if="configType === 'stream'">
              <el-form-item label="监听端口" prop="listen">
                <el-input-number v-model="formData.listen" :min="1" :max="65535" />
              </el-form-item>
              <el-form-item label="协议">
                <el-radio-group v-model="formData.protocol">
                  <el-radio label="tcp">TCP</el-radio>
                  <el-radio label="udp">UDP</el-radio>
                </el-radio-group>
              </el-form-item>
              <el-form-item label="代理目标" prop="proxy_pass">
                <el-input v-model="formData.proxy_pass" placeholder="backend_mysql" />
              </el-form-item>
            </template>
          </el-form>
        </div>

        <!-- Step 3: 详细配置 -->
        <div v-show="currentStep === 2">
          <el-form :model="formData" label-width="140px">
            <!-- Upstream 详细配置 -->
            <template v-if="configType === 'upstream'">
              <el-divider content-position="left">健康检查</el-divider>
              <el-form-item label="启用健康检查">
                <el-switch v-model="formData.health_check.enabled" />
              </el-form-item>
              <template v-if="formData.health_check.enabled">
                <el-form-item label="检查间隔">
                  <el-input v-model="formData.health_check.interval" placeholder="5s" />
                </el-form-item>
                <el-form-item label="失败阈值">
                  <el-input-number v-model="formData.health_check.fails" :min="1" :max="10" />
                </el-form-item>
                <el-form-item label="恢复阈值">
                  <el-input-number v-model="formData.health_check.passes" :min="1" :max="10" />
                </el-form-item>
              </template>
              <el-divider content-position="left">连接配置</el-divider>
              <el-form-item label="保持连接数">
                <el-input-number v-model="formData.keepalive" :min="0" :max="1000" />
              </el-form-item>
            </template>

            <!-- Location 详细配置 -->
            <template v-else-if="configType === 'location'">
              <el-divider content-position="left">请求头设置</el-divider>
              <el-form-item label="Host">
                <el-input v-model="formData.proxy_set_header.Host" placeholder="$host" />
              </el-form-item>
              <el-form-item label="X-Real-IP">
                <el-input v-model="formData.proxy_set_header['X-Real-IP']" placeholder="$remote_addr" />
              </el-form-item>
              <el-form-item label="X-Forwarded-For">
                <el-input v-model="formData.proxy_set_header['X-Forwarded-For']" placeholder="$proxy_add_x_forwarded_for" />
              </el-form-item>
              <el-divider content-position="left">限流配置</el-divider>
              <el-form-item label="启用限流">
                <el-switch v-model="formData.rate_limit.enabled" />
              </el-form-item>
              <template v-if="formData.rate_limit.enabled">
                <el-form-item label="请求速率">
                  <el-input v-model="formData.rate_limit.rate" placeholder="100r/s" />
                </el-form-item>
                <el-form-item label="突发容量">
                  <el-input-number v-model="formData.rate_limit.burst" :min="1" :max="1000" />
                </el-form-item>
              </template>
            </template>

            <!-- HTTP 详细配置 -->
            <template v-else-if="configType === 'http'">
              <el-divider content-position="left">路径配置</el-divider>
              <el-form-item label="根目录">
                <el-input v-model="formData.root" placeholder="/var/www/html" />
              </el-form-item>
              <el-form-item label="索引文件">
                <el-input v-model="formData.index" placeholder="index.html index.htm" />
              </el-form-item>
              <template v-if="formData.ssl">
                <el-divider content-position="left">SSL 配置</el-divider>
                <el-form-item label="证书路径">
                  <el-input v-model="formData.certificate" placeholder="/etc/nginx/ssl/example.crt" />
                </el-form-item>
                <el-form-item label="私钥路径">
                  <el-input v-model="formData.certificate_key" placeholder="/etc/nginx/ssl/example.key" />
                </el-form-item>
              </template>
            </template>

            <!-- Stream 详细配置 -->
            <template v-else-if="configType === 'stream'">
              <el-divider content-position="left">超时配置</el-divider>
              <el-form-item label="连接超时">
                <el-input v-model="formData.timeout.connect" placeholder="5s" />
              </el-form-item>
              <el-form-item label="读取超时">
                <el-input v-model="formData.timeout.read" placeholder="30s" />
              </el-form-item>
              <el-form-item label="发送超时">
                <el-input v-model="formData.timeout.send" placeholder="30s" />
              </el-form-item>
            </template>
          </el-form>
        </div>

        <!-- Step 4: 确认 -->
        <div v-show="currentStep === 3" class="confirm-content">
          <el-alert
            title="请确认以下配置信息"
            type="info"
            :closable="false"
            show-icon
            style="margin-bottom: 20px;"
          />
          <el-descriptions :column="2" border>
            <el-descriptions-item label="配置类型">{{ configType }}</el-descriptions-item>
            <el-descriptions-item label="配置 ID">{{ formData.id || formData.path || formData.server_name || '-' }}</el-descriptions-item>
            <el-descriptions-item label="详细配置" :span="2">
              <pre>{{ JSON.stringify(formData, null, 2) }}</pre>
            </el-descriptions-item>
          </el-descriptions>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="step-actions">
        <el-button v-if="currentStep > 0" @click="prevStep">上一步</el-button>
        <el-button v-if="currentStep < 3" type="primary" @click="nextStep">下一步</el-button>
        <el-button v-if="currentStep === 3" type="success" @click="submitForm">创建配置</el-button>
      </div>
    </el-card>
  </div>
</template>

<script setup>
import { ref, reactive } from 'vue'
import { configApi } from '@/api/config'
import { ElMessage } from 'element-plus'
import { Delete, Plus } from '@element-plus/icons-vue'

const currentStep = ref(0)
const configType = ref('upstream')
const formRef = ref(null)

// 表单数据
const formData = reactive(getDefaultFormData())

// 表单验证规则
const rules = {
  id: [{ required: true, message: '请输入 ID', trigger: 'blur' }],
  path: [{ required: true, message: '请输入路径', trigger: 'blur' }],
  server_name: [{ required: true, message: '请输入服务器名称', trigger: 'blur' }],
  listen: [{ required: true, message: '请输入监听端口', trigger: 'blur' }]
}

// 获取默认表单数据
function getDefaultFormData() {
  return {
    // Upstream
    id: '',
    balance: 'round_robin',
    servers: [{ host: '', port: 8080, weight: 1 }],
    keepalive: 32,
    health_check: {
      enabled: false,
      interval: '5s',
      fails: 3,
      passes: 2
    },
    // Location
    path: '',
    proxy_pass: '',
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
    // HTTP
    server_name: '',
    listen_port: 80,
    ssl: false,
    root: '/var/www/html',
    index: 'index.html index.htm',
    // Stream
    listen: null,
    protocol: 'tcp',
    timeout: {
      connect: '5s',
      read: '30s',
      send: '30s'
    }
  }
}

// 重置表单
function resetForm() {
  Object.assign(formData, getDefaultFormData())
}

// 添加服务器
function addServer() {
  formData.servers.push({ host: '', port: 8080, weight: 1 })
}

// 移除服务器
function removeServer(index) {
  formData.servers.splice(index, 1)
}

// 上一步
function prevStep() {
  currentStep.value--
}

// 下一步
async function nextStep() {
  if (currentStep.value === 1) {
    // 验证表单
    try {
      await formRef.value?.validate()
    } catch {
      return
    }
  }
  currentStep.value++
}

// 提交表单
async function submitForm() {
  try {
    await configApi.create(configType.value, formData)
    ElMessage.success('配置创建成功')
    currentStep.value = 0
    resetForm()
  } catch (e) {
    ElMessage.error('创建失败: ' + e.message)
  }
}
</script>

<style scoped>
.wizard-page {
  max-width: 900px;
  margin: 0 auto;
}

.step-content {
  margin: 40px 0;
  min-height: 300px;
}

.type-selector {
  display: flex;
  justify-content: center;
}

.type-selector :deep(.el-radio-button__inner) {
  padding: 20px 30px;
}

.server-item {
  display: flex;
  gap: 10px;
  margin-bottom: 10px;
  align-items: center;
}

.step-actions {
  display: flex;
  justify-content: center;
  gap: 10px;
  padding-top: 20px;
  border-top: 1px solid #eee;
}

.confirm-content pre {
  background: #f5f7fa;
  padding: 10px;
  border-radius: 4px;
  font-size: 12px;
  overflow-x: auto;
}
</style>