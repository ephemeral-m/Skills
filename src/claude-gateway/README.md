# Claude HTTP Gateway (异步版)

通过 HTTP API 与 Claude Code CLI 交互的网关服务，采用异步任务模型，支持长时间运行的任务。

## 功能特性

- **异步任务模型** - 提交任务立即返回，支持长时间运行
- **任务状态查询** - 随时查询任务执行状态
- **任务取消** - 支持取消正在执行的任务
- **跨平台支持** - Windows (Git Bash) / Linux / macOS
- **零依赖** - 仅使用 Python 标准库

## 快速开始

### 启动服务

```bash
cd src/claude-gateway

# 使用默认工作目录（项目根目录）
python claude-http.py

# 指定工作目录
python claude-http.py /path/to/project

# 查看帮助
python claude-http.py --help
```

---

## API 使用示例

### POST /message - 提交任务

提交消息到 Claude，立即返回任务 ID（不等待响应）。

#### 请求参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| prompt | string | 是 | - | 发送给 Claude 的内容 |
| timeout | float | 否 | 300.0 | 任务超时时间（秒） |

#### 响应示例

```json
{
  "task_id": "aaa2377a-b123-4567-89ab-cdef12345678",
  "status": "pending",
  "message": "任务已提交",
  "hint": "使用 GET /task/aaa2377a-b123-4567-89ab-cdef12345678 查询结果"
}
```

#### 命令行示例

```bash
# Git Bash / Linux / macOS
curl -X POST http://127.0.0.1:9876/message \
  -H "Content-Type: application/json" \
  -d '{"prompt": "介绍一下 Python", "timeout": 300}'

# Windows CMD
curl -X POST http://127.0.0.1:9876/message -H "Content-Type: application/json" -d "{\"prompt\": \"介绍一下 Python\", \"timeout\": 300}"
```

#### Python 示例

```python
import urllib.request
import json

def submit_task(prompt, timeout=300):
    """提交任务"""
    data = json.dumps({"prompt": prompt, "timeout": timeout}).encode('utf-8')
    req = urllib.request.Request(
        'http://127.0.0.1:9876/message',
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    response = urllib.request.urlopen(req, timeout=10)
    return json.loads(response.read().decode('utf-8'))

# 提交任务
result = submit_task("用 Python 写一个 HTTP 服务器")
print(f"任务ID: {result['task_id']}")
```

---

### GET /task/{task_id} - 查询任务

查询任务的执行状态和结果。

#### 任务状态

| 状态 | 说明 |
|------|------|
| `pending` | 等待执行 |
| `running` | 执行中 |
| `completed` | 已完成 |
| `failed` | 执行失败 |
| `cancelled` | 已取消 |

#### 响应示例

**执行中：**

```json
{
  "task_id": "aaa2377a-b123-4567-89ab-cdef12345678",
  "prompt": "介绍一下 Python",
  "status": "running",
  "created_at": "2026-03-26T10:30:00.123456",
  "started_at": "2026-03-26T10:30:00.234567"
}
```

**已完成：**

```json
{
  "task_id": "aaa2377a-b123-4567-89ab-cdef12345678",
  "prompt": "介绍一下 Python",
  "status": "completed",
  "created_at": "2026-03-26T10:30:00.123456",
  "started_at": "2026-03-26T10:30:00.234567",
  "completed_at": "2026-03-26T10:30:10.345678",
  "duration": 10.11,
  "response": "Python 是一种高级编程语言..."
}
```

**失败：**

```json
{
  "task_id": "aaa2377a-b123-4567-89ab-cdef12345678",
  "prompt": "...",
  "status": "failed",
  "error": "执行超时",
  "duration": 300.0
}
```

#### 命令行示例

```bash
curl http://127.0.0.1:9876/task/aaa2377a-b123-4567-89ab-cdef12345678
```

#### Python 示例

```python
import urllib.request
import json
import time

def wait_for_task(task_id, poll_interval=1.0, max_wait=600):
    """等待任务完成"""
    start = time.time()
    while time.time() - start < max_wait:
        response = urllib.request.urlopen(
            f'http://127.0.0.1:9876/task/{task_id}',
            timeout=10
        )
        data = json.loads(response.read().decode('utf-8'))
        status = data.get('status', '')

        if status in ('completed', 'failed', 'cancelled'):
            return data

        time.sleep(poll_interval)

    return {"error": "等待超时", "status": "timeout"}

# 提交并等待完成
task = submit_task("写一个冒泡排序")
result = wait_for_task(task['task_id'])
print(f"状态: {result['status']}")
print(f"响应: {result.get('response', result.get('error'))}")
```

---

### POST /task/{task_id}/cancel - 取消任务

取消正在执行或等待中的任务。

#### 响应示例

```json
{
  "task_id": "aaa2377a-b123-4567-89ab-cdef12345678",
  "status": "cancelled",
  "message": "任务已取消"
}
```

#### 命令行示例

```bash
# Git Bash / Linux / macOS
curl -X POST http://127.0.0.1:9876/task/aaa2377a-b123-4567-89ab-cdef12345678/cancel

# Windows CMD
curl -X POST http://127.0.0.1:9876/task/aaa2377a-b123-4567-89ab-cdef12345678/cancel
```

---

### GET /status - 获取服务状态

#### 响应示例

```json
{
  "status": "running",
  "work_dir": "D:\\Coding\\Code\\Dev\\Skills",
  "platform": "Windows",
  "git_bash": "D:\\Program Files (x86)\\Git\\bin\\bash.exe",
  "max_workers": 1,
  "queue_size": 0,
  "pending_tasks": 0,
  "running_tasks": 1,
  "total_tasks": 5,
  "history_count": 3
}
```

---

### GET /history - 获取历史记录

#### 响应示例

```json
{
  "history": [
    {
      "id": 1,
      "task_id": "aaa2377a-b123-4567-89ab-cdef12345678",
      "timestamp": "2026-03-26T10:30:00.123456",
      "prompt": "介绍一下 Python",
      "response": "Python 是一种高级编程语言...",
      "duration": 10.11
    }
  ],
  "count": 1
}
```

---

## 完整使用场景

### 场景 1：异步提交 + 轮询结果

```python
import urllib.request
import json
import time

def ask_claude(prompt, timeout=300, poll_interval=1.0):
    """异步提问，返回结果"""
    # 提交任务
    data = json.dumps({"prompt": prompt, "timeout": timeout}).encode('utf-8')
    req = urllib.request.Request(
        'http://127.0.0.1:9876/message',
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    response = urllib.request.urlopen(req, timeout=10)
    task = json.loads(response.read().decode('utf-8'))
    task_id = task['task_id']

    # 轮询结果
    start = time.time()
    while time.time() - start < timeout + 30:
        response = urllib.request.urlopen(
            f'http://127.0.0.1:9876/task/{task_id}',
            timeout=10
        )
        data = json.loads(response.read().decode('utf-8'))

        if data['status'] == 'completed':
            return data['response']
        elif data['status'] in ('failed', 'cancelled'):
            raise Exception(data.get('error', '任务失败'))

        time.sleep(poll_interval)

    raise Exception("等待超时")

# 使用
try:
    result = ask_claude("写一个 Python 脚本处理 CSV 文件")
    print(result)
except Exception as e:
    print(f"错误: {e}")
```

### 场景 2：提交多个任务

```python
import urllib.request
import json
import time

def submit_multiple(prompts):
    """批量提交任务"""
    task_ids = []
    for prompt in prompts:
        data = json.dumps({"prompt": prompt, "timeout": 300}).encode('utf-8')
        req = urllib.request.Request(
            'http://127.0.0.1:9876/message',
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        response = urllib.request.urlopen(req, timeout=10)
        task = json.loads(response.read().decode('utf-8'))
        task_ids.append(task['task_id'])
        print(f"提交: {prompt[:30]}... -> {task['task_id'][:8]}")
    return task_ids

def collect_results(task_ids, max_wait=600):
    """收集结果"""
    results = {}
    start = time.time()

    while task_ids and time.time() - start < max_wait:
        for task_id in task_ids[:]:
            response = urllib.request.urlopen(
                f'http://127.0.0.1:9876/task/{task_id}',
                timeout=10
            )
            data = json.loads(response.read().decode('utf-8'))

            if data['status'] in ('completed', 'failed', 'cancelled'):
                results[task_id] = data
                task_ids.remove(task_id)
                print(f"完成: {task_id[:8]} ({data['status']})")

        time.sleep(1.0)

    return results

# 使用
prompts = [
    "解释什么是 REST API",
    "写一个冒泡排序",
    "Python 如何读取 JSON 文件"
]
task_ids = submit_multiple(prompts)
results = collect_results(task_ids)

for task_id, result in results.items():
    print(f"\n{task_id[:8]}: {result.get('response', result.get('error'))[:100]}...")
```

---

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                  Claude HTTP Gateway (异步版)                    │
│                       (端口: 9876)                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  POST /message ──▶ 任务队列 ──▶ 工作线程 ──▶ Claude CLI         │
│        │              │            │              │              │
│        │              │            │              │              │
│        ▼              ▼            ▼              ▼              │
│   立即返回        Task 对象    subprocess.Popen   响应存储       │
│   task_id                                                      │
│                                                                  │
│  GET /task/{id} ─────────────────────────────────▶ 查询状态     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**同步 vs 异步对比：**

| 特性 | 同步模式 | 异步模式 |
|------|----------|----------|
| 请求响应 | 等待完成才返回 | 立即返回 task_id |
| 超时风险 | HTTP 请求超时 | 无超时风险 |
| 长时间任务 | 可能超时 | 支持任意时长 |
| 取消任务 | 不支持 | 支持 |
| 并发 | 串行 | 队列 + 工作线程 |

---

## 错误处理

| HTTP 状态码 | 说明 |
|-------------|------|
| 200 | 请求成功 |
| 400 | 请求参数错误 |
| 404 | 任务不存在或未知路径 |
| 500 | 服务器内部错误 |

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
python test_gateway.py --test submit   # 提交任务
python test_gateway.py --test query    # 查询任务
python test_gateway.py --test wait     # 等待完成
python test_gateway.py --test cancel   # 取消任务
```

---

## 常见问题

### Q: 为什么改用异步模式？

同步模式下，长时间任务（如代码生成、复杂分析）会导致 HTTP 请求超时。异步模式提交任务后立即返回，通过轮询查询结果，避免超时问题。

### Q: 如何知道任务完成了？

使用 `GET /task/{task_id}` 查询，当 `status` 为 `completed` 时表示完成。

### Q: 任务可以运行多长时间？

由提交任务时的 `timeout` 参数控制，默认 300 秒。可以设置更长的超时时间，如 `"timeout": 3600`（1小时）。

### Q: 如何取消正在执行的任务？

调用 `POST /task/{task_id}/cancel`。

### Q: 支持并行执行多个任务吗？

当前版本 `max_workers=1`，任务串行执行。可以修改代码增加工作线程数。

---

## License

MIT