# Claude HTTP Gateway

通过 HTTP API 与 Claude Code CLI 交互的网关服务。

## 功能特性

- **HTTP API 接口** - 标准化的 REST API
- **跨平台支持** - Windows (Git Bash) / Linux / macOS
- **状态查询** - 实时查询 Claude 状态（空闲/处理中/等待授权）
- **授权流程** - 支持 Claude 权限请求的审批
- **详细日志** - 请求/响应完整日志输出
- **对话历史** - 自动记录所有交互
- **并发控制** - 线程安全的请求处理
- **零依赖** - 仅使用 Python 标准库

## 快速开始

### 前置条件

- Python 3.8+
- Claude Code CLI 已安装并配置
- Windows 用户需安装 Git Bash

### 启动服务

```bash
cd src/claude-gateway

# 使用默认工作目录（项目根目录）
python claude-http.py

# 指定工作目录
python claude-http.py /path/to/your/project

# Windows 示例
python claude-http.py D:\Projects\my-app

# 查看帮助
python claude-http.py --help
```

**工作目录说明：**
- 默认使用项目根目录（脚本所在目录的上两级）
- Claude Code 将在指定的工作目录下执行命令和操作文件
- 可以通过 `GET /status` 查看当前工作目录

启动成功输出：

```
============================================================
Claude Code HTTP Gateway
============================================================
[INFO] Git Bash: D:\Program Files (x86)\Git\bin\bash.exe
[INFO] 工作目录: D:\Coding\Code\Dev\Skills
[INFO] 测试 Claude CLI...
[INFO] Claude CLI 测试成功: 服务启动成功...
[INFO] HTTP 服务器启动在 http://127.0.0.1:9876
[INFO] API 端点:
[INFO]   POST /message  发送消息
[INFO]   POST /approve  授权操作
[INFO]   GET  /status   获取状态
[INFO]   GET  /history  获取历史
[INFO]   GET  /pending  获取待授权列表
```

## 服务状态说明

| 状态 | 英文 | 说明 |
|------|------|------|
| 空闲 | `idle` | 服务空闲，可接受新请求 |
| 处理中 | `processing` | 正在处理 Claude 请求 |
| 等待授权 | `waiting_approval` | Claude 请求执行某操作，等待用户授权 |
| 错误 | `error` | 上次请求出错 |

---

## API 使用示例

### GET /status - 获取服务状态

获取服务当前运行状态。

#### 响应示例

```json
{
  "status": "idle",
  "status_text": "空闲",
  "is_processing": false,
  "history_count": 5,
  "request_count": 5,
  "platform": "Windows",
  "git_bash": "D:\\Program Files (x86)\\Git\\bin\\bash.exe",
  "work_dir": "D:\\Coding\\Code\\Dev\\Skills",
  "pending_approvals": 0
}
```

**处理中时额外字段：**

```json
{
  "status": "processing",
  "status_text": "处理中",
  "is_processing": true,
  "current_prompt": "当前处理的问题...",
  "elapsed_time": 5.23
}
```

#### 命令行示例

```bash
# Git Bash / Linux / macOS
curl http://127.0.0.1:9876/status

# Windows CMD
curl http://127.0.0.1:9876/status

# Windows PowerShell
Invoke-RestMethod -Uri "http://127.0.0.1:9876/status"
```

#### Python 示例

```python
import urllib.request
import json

response = urllib.request.urlopen('http://127.0.0.1:9876/status')
data = json.loads(response.read().decode('utf-8'))
print(f"状态: {data['status_text']}")
print(f"是否处理中: {data['is_processing']}")
print(f"工作目录: {data['work_dir']}")
print(f"历史记录数: {data['history_count']}")
```

#### JavaScript 示例

```javascript
// Node.js
const response = await fetch('http://127.0.0.1:9876/status');
const data = await response.json();
console.log(`状态: ${data.status_text}`);
console.log(`是否处理中: ${data.is_processing}`);
```

```javascript
// 浏览器 (需要 CORS 支持)
fetch('http://127.0.0.1:9876/status')
  .then(res => res.json())
  .then(data => console.log(data));
```

---

### POST /message - 发送消息

发送消息到 Claude，同步等待响应。

#### 请求参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| prompt | string | 是 | - | 发送给 Claude 的内容 |
| timeout | float | 否 | 300.0 | 超时时间（秒） |

#### 响应示例

**成功响应：**

```json
{
  "status": "success",
  "response": "Claude 的回复内容",
  "duration": 5.79
}
```

**等待授权：**

```json
{
  "status": "waiting_approval",
  "message": "Claude 请求授权执行操作",
  "permission": {
    "type": "permission",
    "content": "Do you want to allow running bash command?",
    "detail": "bash",
    "timestamp": "2026-03-25T14:30:00"
  },
  "hint": "使用 POST /approve 授权，或 POST /approve {\"deny\": true} 拒绝"
}
```

**服务繁忙：**

```json
{
  "status": "busy",
  "error": "正在处理上一条消息"
}
```

#### 命令行示例

> ⚠️ **Windows 用户注意**：Windows CMD 和 PowerShell 对引号处理不同。

```bash
# Git Bash / Linux / macOS
curl -X POST http://127.0.0.1:9876/message \
  -H "Content-Type: application/json" \
  -d '{"prompt": "介绍一下 Python", "timeout": 60}'

# Windows CMD - 双引号转义
curl -X POST http://127.0.0.1:9876/message -H "Content-Type: application/json" -d "{\"prompt\": \"介绍一下 Python\", \"timeout\": 60}"

# Windows PowerShell
Invoke-RestMethod -Uri "http://127.0.0.1:9876/message" -Method POST -ContentType "application/json" -Body '{"prompt": "介绍一下 Python", "timeout": 60}'
```

#### Python 示例

```python
import urllib.request
import json

# 构建请求
data = json.dumps({
    "prompt": "用 Python 写一个 Hello World",
    "timeout": 60
}).encode('utf-8')

req = urllib.request.Request(
    'http://127.0.0.1:9876/message',
    data=data,
    headers={'Content-Type': 'application/json'}
)

# 发送请求
response = urllib.request.urlopen(req, timeout=90)
result = json.loads(response.read().decode('utf-8'))

if result['status'] == 'success':
    print(f"响应: {result['response']}")
    print(f"耗时: {result['duration']}秒")
elif result['status'] == 'waiting_approval':
    print(f"需要授权: {result['permission']['content']}")
else:
    print(f"错误: {result.get('error')}")
```

#### JavaScript 示例

```javascript
// Node.js
const response = await fetch('http://127.0.0.1:9876/message', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    prompt: '用 Python 写一个 Hello World',
    timeout: 60
  })
});

const result = await response.json();

if (result.status === 'success') {
  console.log(`响应: ${result.response}`);
  console.log(`耗时: ${result.duration}秒`);
} else if (result.status === 'waiting_approval') {
  console.log(`需要授权: ${result.permission.content}`);
}
```

---

### POST /approve - 授权操作

授权或拒绝 Claude 执行待审批的操作。

#### 请求参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| deny | bool | 否 | false | true = 拒绝，false/省略 = 授权 |
| message | string | 否 | - | 附加说明 |

#### 响应示例

```json
{
  "status": "success",
  "action": "approved",
  "permission": {
    "type": "permission",
    "content": "Do you want to allow...",
    "detail": "bash"
  },
  "message": "已授权该操作",
  "remaining": 0
}
```

#### 命令行示例

```bash
# 授权操作
# Git Bash / Linux / macOS
curl -X POST http://127.0.0.1:9876/approve -H "Content-Type: application/json" -d '{}'

# Windows CMD
curl -X POST http://127.0.0.1:9876/approve -H "Content-Type: application/json" -d "{}"

# Windows PowerShell
Invoke-RestMethod -Uri "http://127.0.0.1:9876/approve" -Method POST -ContentType "application/json" -Body '{}'

# 拒绝操作
# Git Bash / Linux / macOS
curl -X POST http://127.0.0.1:9876/approve -H "Content-Type: application/json" -d '{"deny": true}'

# Windows CMD
curl -X POST http://127.0.0.1:9876/approve -H "Content-Type: application/json" -d "{\"deny\": true}"
```

#### Python 示例

```python
import urllib.request
import json

# 授权操作
data = json.dumps({}).encode('utf-8')
req = urllib.request.Request(
    'http://127.0.0.1:9876/approve',
    data=data,
    headers={'Content-Type': 'application/json'}
)
response = urllib.request.urlopen(req)
print(json.loads(response.read().decode('utf-8')))

# 拒绝操作
data = json.dumps({"deny": True}).encode('utf-8')
req = urllib.request.Request(
    'http://127.0.0.1:9876/approve',
    data=data,
    headers={'Content-Type': 'application/json'}
)
response = urllib.request.urlopen(req)
print(json.loads(response.read().decode('utf-8')))
```

---

### GET /pending - 获取待授权列表

获取当前等待授权的操作列表。

#### 响应示例

```json
{
  "status": "success",
  "count": 1,
  "pending": [
    {
      "type": "permission",
      "content": "Do you want to allow running bash command?",
      "detail": "bash",
      "timestamp": "2026-03-25T14:30:00"
    }
  ]
}
```

#### 命令行示例

```bash
# 所有平台通用
curl http://127.0.0.1:9876/pending

# Windows PowerShell
Invoke-RestMethod -Uri "http://127.0.0.1:9876/pending"
```

#### Python 示例

```python
import urllib.request
import json

response = urllib.request.urlopen('http://127.0.0.1:9876/pending')
data = json.loads(response.read().decode('utf-8'))

print(f"待授权数量: {data['count']}")
for item in data['pending']:
    print(f"  - {item['content']}")
```

---

### GET /history - 获取对话历史

获取所有对话历史记录。

#### 响应示例

```json
{
  "status": "success",
  "count": 2,
  "history": [
    {
      "id": 1,
      "timestamp": "2026-03-25T14:30:00.123456",
      "prompt": "你好",
      "response": "你好！有什么可以帮助你的？",
      "duration": 3.5
    },
    {
      "id": 2,
      "timestamp": "2026-03-25T14:31:00.654321",
      "prompt": "介绍一下 Python",
      "response": "Python 是一种高级编程语言...",
      "duration": 5.79
    }
  ]
}
```

#### 命令行示例

```bash
# 所有平台通用
curl http://127.0.0.1:9876/history

# Windows PowerShell
Invoke-RestMethod -Uri "http://127.0.0.1:9876/history"
```

#### Python 示例

```python
import urllib.request
import json

response = urllib.request.urlopen('http://127.0.0.1:9876/history')
data = json.loads(response.read().decode('utf-8'))

print(f"历史记录数: {data['count']}")
for entry in data['history']:
    print(f"[{entry['id']}] {entry['prompt']}")
    print(f"    响应: {entry['response'][:50]}...")
    print(f"    耗时: {entry['duration']}秒")
```

---

## 完整使用场景

### 场景 1：简单问答

```python
import urllib.request
import json

def ask_claude(question):
    """向 Claude 提问"""
    data = json.dumps({"prompt": question, "timeout": 60}).encode('utf-8')
    req = urllib.request.Request(
        'http://127.0.0.1:9876/message',
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    response = urllib.request.urlopen(req, timeout=90)
    result = json.loads(response.read().decode('utf-8'))
    return result

# 使用
result = ask_claude("什么是机器学习？")
print(result['response'])
```

### 场景 2：带状态检查的请求

```python
import urllib.request
import json
import time

def safe_ask(question, max_wait=30):
    """安全提问，检查服务状态"""
    # 先检查状态
    response = urllib.request.urlopen('http://127.0.0.1:9876/status')
    status = json.loads(response.read().decode('utf-8'))

    if status['is_processing']:
        print(f"服务忙碌，当前处理: {status.get('current_prompt', '')}")
        return None

    # 发送请求
    data = json.dumps({"prompt": question, "timeout": max_wait}).encode('utf-8')
    req = urllib.request.Request(
        'http://127.0.0.1:9876/message',
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    response = urllib.request.urlopen(req, timeout=max_wait + 30)
    return json.loads(response.read().decode('utf-8'))

# 使用
result = safe_ask("解释一下 REST API")
if result and result['status'] == 'success':
    print(result['response'])
```

### 场景 3：处理授权流程

```python
import urllib.request
import json

def send_with_approval(prompt):
    """发送请求并处理授权"""
    # 发送消息
    data = json.dumps({"prompt": prompt, "timeout": 60}).encode('utf-8')
    req = urllib.request.Request(
        'http://127.0.0.1:9876/message',
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    response = urllib.request.urlopen(req, timeout=90)
    result = json.loads(response.read().decode('utf-8'))

    # 检查是否需要授权
    if result['status'] == 'waiting_approval':
        print(f"Claude 请求授权: {result['permission']['content']}")

        # 用户确认
        choice = input("授权? (y/n): ")
        if choice.lower() == 'y':
            # 授权
            approve_data = json.dumps({}).encode('utf-8')
            approve_req = urllib.request.Request(
                'http://127.0.0.1:9876/approve',
                data=approve_data,
                headers={'Content-Type': 'application/json'}
            )
            urllib.request.urlopen(approve_req)
            print("已授权")
        else:
            # 拒绝
            approve_data = json.dumps({"deny": True}).encode('utf-8')
            approve_req = urllib.request.Request(
                'http://127.0.0.1:9876/approve',
                data=approve_data,
                headers={'Content-Type': 'application/json'}
            )
            urllib.request.urlopen(approve_req)
            print("已拒绝")

    return result

# 使用
result = send_with_approval("帮我创建一个文件 test.txt")
```

---

## 服务端日志

服务运行时会输出详细的请求/响应日志：

```
[14:30:15.123] [HTTP] <-- POST /message
[14:30:15.124] [HTTP]     Body: {"prompt": "你好", "timeout": 60}
[14:30:15.125] [REQUEST] 收到请求: 你好
[14:30:20.456] [RESPONSE] 响应完成 (5.33s): 你好！有什么可以帮助你的？
[14:30:20.457] [HTTP] --> 200
[14:30:20.457] [HTTP]     Response: {"response": "你好！...", "status": "success", ...}
```

**日志级别：**

| 级别 | 说明 |
|------|------|
| HTTP | HTTP 请求/响应 |
| REQUEST | 收到 Claude 请求 |
| RESPONSE | Claude 响应完成 |
| PENDING | 检测到权限请求 |
| APPROVE | 授权操作 |
| ERROR | 错误信息 |

---

## 授权流程

当 Claude 需要执行敏感操作（如运行命令、读写文件）时：

```
┌──────────────┐     POST /message      ┌──────────────┐
│    Client    │ ───────────────────▶   │   Gateway    │
└──────────────┘                        └──────────────┘
                                              │
                                              ▼
                                        ┌──────────────┐
                                        │  Claude CLI  │
                                        └──────────────┘
                                              │
                                              │ 请求授权
                                              ▼
┌──────────────┐     status: waiting_approval  │
│    Client    │ ◀─────────────────────────────┘
└──────────────┘
       │
       │ GET /pending (查看详情)
       ▼
┌──────────────┐     POST /approve           ┌──────────────┐
│    Client    │ ───────────────────────▶    │   Gateway    │
└──────────────┘                             └──────────────┘
                                                   │
                                                   │ 继续执行
                                                   ▼
                                             ┌──────────────┐
                                             │  Claude CLI  │
                                             └──────────────┘
                                                   │
                                                   │ 最终响应
                                                   ▼
┌──────────────┐     status: success        ┌──────────────┐
│    Client    │ ◀─────────────────────────│   Gateway    │
└──────────────┘                            └──────────────┘
```

---

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                     Claude HTTP Gateway                          │
│                      (端口: 9876)                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   HTTP Request ──▶ RequestHandler ──▶ ClaudeGateway             │
│         │                                      │                 │
│         │                                      │                 │
│         ▼                                      ▼                 │
│   ┌──────────┐                        ┌───────────────┐         │
│   │  日志    │                        │ 状态管理      │         │
│   │  记录    │                        │ - idle        │         │
│   └──────────┘                        │ - processing  │         │
│                                       │ - waiting_    │         │
│                                       │   approval    │         │
│                                       │ - error       │         │
│                                       └───────────────┘         │
│                                              │                   │
│                          ┌──────────────────┼──────────────────┐│
│                          │                  │                  ││
│                          ▼                  ▼                  ││
│                     Windows            Linux/Mac               ││
│                          │                  │                  ││
│                          ▼                  ▼                  ││
│                    Git Bash            直接管道                ││
│                    管道模式            stdin/stdout            ││
│                          │                  │                  ││
│                          └────────┬─────────┘                  ││
│                                   ▼                             ││
│                           Claude CLI                           ││
│                          (claude 命令)                         ││
└─────────────────────────────────────────────────────────────────┘
```

---

## 错误处理

| HTTP 状态码 | 说明 |
|-------------|------|
| 200 | 请求成功 |
| 400 | 请求参数错误（空 prompt、无效 JSON） |
| 404 | 未知 API 路径 |
| 500 | Claude CLI 执行失败或响应超时 |

---

## 配置

### 端口配置

默认端口 `9876`，可通过修改代码中的 `port` 参数更改：

```python
def run_http_server(gateway: ClaudeGateway, port: 9876):
    ...
```

### Git Bash 路径

Windows 平台自动检测以下路径：

```python
possible_paths = [
    r"D:\Program Files (x86)\Git\bin\bash.exe",
    r"D:\Program Files\Git\bin\bash.exe",
    r"C:\Program Files\Git\bin\bash.exe",
    r"C:\Program Files (x86)\Git\bin\bash.exe",
    r"%LOCALAPPDATA%\Programs\Git\bin\bash.exe",
    r"%PROGRAMFILES%\Git\bin\bash.exe",
    r"%PROGRAMFILES(X86)%\Git\bin\bash.exe",
]
```

---

## 限制

- **无会话保持** - 每次请求独立，不保持对话上下文
- **串行处理** - 并发请求排队处理，非并行
- **内存历史** - 历史记录存储在内存，重启后丢失
- **单机部署** - 不支持分布式部署

---

## 文件结构

```
src/claude-gateway/
├── claude-http.py     # 主程序
├── README.md          # 本文档
└── test_gateway.py    # 测试套件
```

---

## 测试

```bash
# 运行所有测试
python test_gateway.py

# 运行指定测试
python test_gateway.py --test status      # 状态查询
python test_gateway.py --test message     # 消息发送
python test_gateway.py --test error       # 错误处理

# 指定服务地址
python test_gateway.py --url http://127.0.0.1:9876
```

---

## 常见问题

### Q: Windows 上启动失败，提示找不到 Git Bash？

确保 Git for Windows 已安装，或将 Git Bash 路径添加到 `possible_paths` 列表中。

### Q: 请求超时怎么办？

增加 `timeout` 参数值，或检查网络连接和 Claude API 状态。

### Q: 如何查看日志？

服务运行时会在控制台输出请求日志：

```
[14:30:15.123] [HTTP] <-- POST /message
[14:30:15.124] [HTTP]     Body: {"prompt": "你好", "timeout": 60}
```

### Q: 如何授权 Claude 的操作？

1. 发送请求后，如果返回 `status: waiting_approval`
2. 调用 `GET /pending` 查看待授权操作详情
3. 调用 `POST /approve` 授权或 `POST /approve {"deny": true}` 拒绝

### Q: 支持流式响应吗？

当前版本不支持流式响应，所有响应都是完整返回。

### Q: Windows CMD 中 curl 命令报错怎么办？

Windows CMD 对引号处理不同，请使用：
- 双引号包裹整个 JSON
- 内部双引号用 `\"` 转义

```cmd
curl -X POST http://127.0.0.1:9876/message -H "Content-Type: application/json" -d "{\"prompt\": \"你好\"}"
```

---

## License

MIT