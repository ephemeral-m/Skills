# Claude Code 通知系统使用说明

## 概述

本通知系统基于 Claude Code 的 hooks 机制，能够在需要授权或任务完成时自动发送通知到指定的 HTTP 端点（默认：`http://127.0.0.1:8081`）。

## 系统架构

```
Claude Code
    │
    ├─ PreToolUse Hook
    │   └─> notify.py permission
    │       └─> 发送权限请求通知
    │
    └─ PostToolUse Hook
        └─> notify.py complete
            └─> 发送任务完成通知
```

## 文件说明

### 1. notify.py
通知发送脚本，负责：
- 从 stdin 读取 hook 数据
- 判断是否需要发送通知
- 发送 HTTP POST 请求到通知端点

**用法**:
```bash
# 权限请求通知
python .claude/hooks/notify.py permission

# 任务完成通知
python .claude/hooks/notify.py complete
``

### 2. settings.local.json
配置文件，包含 hooks 定义：

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python .claude/hooks/notify.py permission"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "python .claude/hooks/notify.py complete"
          }
        ]
      }
    ]
  }
}
```

### 3. test_notify_server.py
测试服务器，用于接收和显示通知。

## 通知触发条件

### 权限请求通知 (permission_request)
当执行以下操作时会触发：

1. **Bash 工具**：
   - `rm -rf` 命令
   - `git push --force` 命令
   - `sudo` 命令
   - `systemctl` 命令
   - `docker` 命令

2. **Write/Edit 工具**：
   - 修改 `settings.json` 文件
   - 修改 `CLAUDE.md` 文件
   - 修改 `.env` 文件

### 任务完成通知 (task_complete)
当执行以下操作完成后会触发：

1. **Bash 工具**：
   - `dev build/test/all` 命令
   - `git push/commit` 命令
   - `npm install` 命令
   - `pip install` 命令

2. **Write/Edit 工具**：
   - 修改重要文件（`CLAUDE.md`、`settings.json`、`.env`）

3. **Skill/Agent 工具**：
   - 所有调用都会触发通知

## 通知消息格式

```json
{
  "event_type": "permission_request|task_complete",
  "title": "通知标题",
  "message": "通知消息",
  "timestamp": "2026-03-25T10:30:00Z",
  "details": {
    "tool": "工具名称",
    "target": "操作目标",
    "success": true,
    "duration_ms": 100
  }
}
```

## 测试步骤

### 1. 启动测试服务器
```bash
python test_notify_server.py
```

输出：
```
通知接收服务器已启动
监听地址: http://127.0.0.1:8081
通知端点: http://127.0.0.1:8081/notify

等待通知... (按 Ctrl+C 停止)
```

### 2. 测试权限请求通知
在另一个终端中执行：
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf /test"}}' | \
python .claude/hooks/notify.py permission
```

服务器输出：
```
============================================================
[2026-03-25 10:30:00] 收到通知
============================================================
事件类型: permission_request
标题: 需要工具授权
消息: 工具 'Bash' 需要授权才能执行
时间戳: 2026-03-25T10:30:00Z

详细信息:
  tool: Bash
  target: rm -rf /test
  input: {...}
============================================================
```

### 3. 测试任务完成通知
```bash
echo '{"tool_name":"Skill","tool_input":{"skill":"dev"},"success":true}' | \
python .claude/hooks/notify.py complete
```

### 4. 在实际场景中测试
启动测试服务器后，正常使用 Claude Code。当触发相关操作时，会自动发送通知。

## 自定义配置

### 修改通知端点
编辑 `notify.py` 文件，修改 `Notifier` 类的默认端点：

```python
def __init__(self, endpoint: str = "http://your-server:port"):
    self.endpoint = endpoint
```

### 调整超时时间
```python
self.timeout = 5  # 秒
```

### 添加新的触发条件
在 `notify.py` 中修改：
- `should_notify_permission()` - 权限请求触发条件
- `should_notify_complete()` - 任务完成触发条件

## 故障排查

### 1. 通知未发送
- 检查测试服务器是否运行
- 查看 hook 命令是否正确配置
- 检查 Python 脚本是否有执行权限

### 2. 连接失败
- 确认服务器地址和端口正确
- 检查防火墙设置
- 确认服务器能够接收 POST 请求

### 3. Hook 未触发
- 验证 `settings.local.json` 语法（`python -m json.tool .claude/settings.local.json`）
- 确认 matcher 匹配正确的工具名称
- 查看是否有其他 hook 阻止执行

## 集成到生产环境

### 1. 实现通知接收服务
创建一个 HTTP 服务，监听 `/notify` 端点：
- 支持_POST 方法
- 接收 JSON 格式的通知数据
- 返回 200 状态码表示成功

### 2. 通知处理建议
- 记录所有通知到数据库
- 根据事件类型分类处理
- 实现告警逻辑（如危险操作）
- 提供通知历史查询接口

### 3. 安全建议
- 使用 HTTPS 加密通信
- 添加认证机制（API Key 或 Token）
- 限制访问来源（IP 白名单）
- 敏感信息脱敏处理

## 示例：集成到 Webhook

```python
# 示例：转发通知到 Slack Webhook
import requests

def send_notification(event_type, title, message, details):
    slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

    payload = {
        "text": f"{title}\n{message}",
        "attachments": [
            {
                "fields": [
                    {"title": k, "value": str(v), "short": True}
                    for k, v in details.items()
                ]
            }
        ]
    }

    requests.post(slack_webhook_url, json=payload)
```

## 注意事项

1. **性能影响**：通知发送有 3 秒超时，不会显著影响 Claude Code 性能
2. **错误处理**：通知失败不会影响 Claude Code 正常运行
3. **隐私安全**：通知可能包含敏感信息（命令、文件路径），注意保护
4. **网络要求**：需要能够访问通知端点（localhost 或远程服务器）

## 更新日志

- **2026-03-25**: 初始版本
  - 实现权限请求通知
  - 实现任务完成通知
  - 添加测试服务器