#!/usr/bin/env python3
"""
Claude Code 通知脚本
发送通知消息到指定的 HTTP 端点
可作为 Hook 直接调用
"""

import sys
import os
import json
import urllib.request
import urllib.error
from typing import Dict, Any, Optional
from datetime import datetime, timezone


class Notifier:
    """通知发送器"""

    def __init__(self, endpoint: str = "http://127.0.0.1:8081"):
        self.endpoint = endpoint
        self.timeout = 3  # 超时时间（秒）

    def send_notification(self, event_type: str, title: str, message: str,
                         details: Optional[Dict[str, Any]] = None) -> bool:
        """
        发送通知到 HTTP 端点

        Args:
            event_type: 事件类型 (permission_request, task_complete, error, warning)
            title: 通知标题
            message: 通知消息
            details: 详细信息字典

        Returns:
            bool: 是否发送成功
        """
        payload = {
            "event_type": event_type,
            "title": title,
            "message": message,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "details": details or {}
        }

        try:
            data = json.dumps(payload, ensure_ascii=False).encode('utf-8')
            req = urllib.request.Request(
                f"{self.endpoint}/notify",
                data=data,
                headers={
                    'Content-Type': 'application/json',
                    'User-Agent': 'Claude-Code-Hook/1.0'
                },
                method='POST'
            )

            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                if response.status == 200:
                    self._log_success(event_type, title)
                    return True
                else:
                    self._log_error(f"HTTP {response.status}")
                    return False

        except urllib.error.URLError as e:
            self._log_error(f"连接失败: {e.reason}")
            return False
        except Exception as e:
            self._log_error(f"发送失败: {str(e)}")
            return False

    def _log_success(self, event_type: str, title: str):
        """记录成功日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] ✓ 通知已发送: [{event_type}] {title}", file=sys.stderr)

    def _log_error(self, error: str):
        """记录错误日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] ✗ 通知发送失败: {error}", file=sys.stderr)


def notify_permission_request(tool_name: str, tool_input: Dict[str, Any]):
    """通知：需要授权"""
    notifier = Notifier()

    # 提取关键信息
    target = extract_tool_target(tool_name, tool_input)

    notifier.send_notification(
        event_type="permission_request",
        title="需要工具授权",
        message=f"工具 '{tool_name}' 需要授权才能执行",
        details={
            "tool": tool_name,
            "target": target,
            "input": tool_input
        }
    )


def notify_task_complete(tool_name: str, tool_input: Dict[str, Any],
                        success: bool, duration_ms: Optional[int] = None):
    """通知：任务完成"""
    notifier = Notifier()

    target = extract_tool_target(tool_name, tool_input)
    status = "成功" if success else "失败"

    notifier.send_notification(
        event_type="task_complete",
        title=f"任务执行{status}",
        message=f"工具 '{tool_name}' 执行完成",
        details={
            "tool": tool_name,
            "target": target,
            "success": success,
            "duration_ms": duration_ms
        }
    )


def extract_tool_target(tool_name: str, tool_input: Dict[str, Any]) -> str:
    """提取工具目标信息"""
    extractors = {
        "Read": lambda i: i.get("file_path", "N/A"),
        "Write": lambda i: i.get("file_path", "N/A"),
        "Edit": lambda i: i.get("file_path", "N/A"),
        "Bash": lambda i: i.get("command", "N/A")[:100],
        "Glob": lambda i: i.get("pattern", "N/A"),
        "Grep": lambda i: i.get("pattern", "N/A"),
        "WebFetch": lambda i: i.get("url", "N/A"),
        "WebSearch": lambda i: i.get("query", "N/A"),
        "Skill": lambda i: i.get("skill", "N/A"),
        "Agent": lambda i: i.get("subagent_type", "N/A"),
    }

    extractor = extractors.get(tool_name)
    if extractor:
        try:
            return extractor(tool_input)
        except Exception:
            pass
    return "N/A"


def should_notify_permission(tool_name: str, tool_input: Dict[str, Any]) -> bool:
    """判断是否需要发送权限通知"""
    import re

    # 关键工具列表（需要关注权限的工具）
    critical_tools = {
        "Bash": lambda i: any([
            # 危险命令
            re.search(r"rm\s+-rf", i.get("command", "")),
            re.search(r"git\s+push.*--force", i.get("command", "")),
            re.search(r"sudo\s+", i.get("command", "")),
            # 系统级操作
            re.search(r"systemctl\s+", i.get("command", "")),
            re.search(r"docker\s+", i.get("command", "")),
        ]),
        "Write": lambda i: any([
            # 系统配置文件
            i.get("file_path", "").endswith("settings.json"),
            i.get("file_path", "").endswith("CLAUDE.md"),
            # 环境配置
            ".env" in i.get("file_path", ""),
        ]),
        "Edit": lambda i: any([
            # 修改配置文件
            i.get("file_path", "").endswith("settings.json"),
            i.get("file_path", "").endswith("CLAUDE.md"),
        ])
    }

    checker = critical_tools.get(tool_name)
    if checker:
        return checker(tool_input)
    return False


def should_notify_complete(tool_name: str, tool_input: Dict[str, Any], success: bool) -> bool:
    """判断是否需要发送完成通知"""
    # 只通知特定的工具
    important_tools = ["Bash", "Skill", "Agent", "Write", "Edit"]

    if tool_name not in important_tools:
        return False

    # Bash 工具：只通知长时间运行或重要的命令
    if tool_name == "Bash":
        command = tool_input.get("command", "")
        # 重要命令模式
        important_patterns = [
            "dev build",
            "dev test",
            "dev all",
            "git push",
            "git commit",
            "npm install",
            "pip install"
        ]
        return any(pattern in command for pattern in important_patterns)

    # Write/Edit：通知重要文件的修改
    if tool_name in ["Write", "Edit"]:
        file_path = tool_input.get("file_path", "")
        # 重要文件模式
        important_files = [
            "CLAUDE.md",
            "settings.json",
            ".env"
        ]
        return any(important in file_path for important in important_files)

    # Skill 和 Agent 总是通知
    if tool_name in ["Skill", "Agent"]:
        return True

    return False


def hook_permission():
    """Hook: 权限请求通知"""
    data = read_stdin_json()
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    if should_notify_permission(tool_name, tool_input):
        notify_permission_request(tool_name, tool_input)


def hook_complete():
    """Hook: 任务完成通知"""
    data = read_stdin_json()
    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})
    tool_response = data.get("tool_response", {})
    success = data.get("success", True)

    # 提取执行时长（如果有）
    duration_ms = None
    if isinstance(tool_response, dict):
        duration_ms = tool_response.get("duration_ms")

    if should_notify_complete(tool_name, tool_input, success):
        notify_task_complete(tool_name, tool_input, success, duration_ms)


def read_stdin_json() -> Dict[str, Any]:
    """从 stdin 读取 JSON 数据，优先使用环境变量"""
    # 优先从环境变量读取（bash 传递的数据）
    env_json = os.environ.get("INPUT_JSON", "")
    if env_json:
        try:
            return json.loads(env_json)
        except json.JSONDecodeError:
            pass

    # 从 stdin 读取
    try:
        if not sys.stdin.isatty():
            return json.load(sys.stdin)
    except json.JSONDecodeError:
        pass

    return {}


def main():
    """主函数：根据命令行参数执行不同的 hook"""
    if len(sys.argv) < 2:
        print("用法: notify.py <hook_type>", file=sys.stderr)
        print("  hook_type: permission | complete", file=sys.stderr)
        sys.exit(1)

    hook_type = sys.argv[1]

    if hook_type == "permission":
        hook_permission()
    elif hook_type == "complete":
        hook_complete()
    else:
        print(f"未知的 hook 类型: {hook_type}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()