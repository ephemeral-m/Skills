"""
Claude Code Hooks 共享库
提供通用的数据处理、日志记录和颜色输出功能
"""

import sys
import os
import json
from datetime import datetime, timezone
from typing import Optional, Dict, Any


# ============================================================================
# 颜色定义
# ============================================================================

class Colors:
    """终端颜色定义"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

    @classmethod
    def red(cls, text: str) -> str:
        return f"{cls.RED}{text}{cls.NC}"

    @classmethod
    def yellow(cls, text: str) -> str:
        return f"{cls.YELLOW}{text}{cls.NC}"

    @classmethod
    def green(cls, text: str) -> str:
        return f"{cls.GREEN}{text}{cls.NC}"

    @classmethod
    def cyan(cls, text: str) -> str:
        return f"{cls.CYAN}{text}{cls.NC}"


# ============================================================================
# 数据读取
# ============================================================================

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


# ============================================================================
# 工具信息提取
# ============================================================================

TOOL_ACTIONS = {
    "Read": "读取文件",
    "Write": "写入文件",
    "Edit": "编辑文件",
    "Bash": "执行命令",
    "Glob": "搜索文件",
    "Grep": "搜索内容",
    "WebFetch": "获取网页",
    "WebSearch": "搜索网络",
    "Skill": "调用技能",
    "Agent": "启动代理",
    "AskUserQuestion": "询问用户"
}


def get_action_desc(tool: str) -> str:
    """获取工具操作的中文描述"""
    return TOOL_ACTIONS.get(tool, "其他操作")


def truncate(text: Optional[str], max_len: int = 100) -> str:
    """截断文本"""
    if not text:
        return "N/A"
    if len(text) > max_len:
        return text[:max_len] + "..."
    return text


def extract_target(tool: str, tool_input: Dict[str, Any]) -> str:
    """根据工具类型提取目标信息"""
    if not tool_input:
        return "N/A"

    extractors = {
        "Read": lambda i: i.get("file_path", "N/A"),
        "Write": lambda i: i.get("file_path", "N/A"),
        "Edit": lambda i: i.get("file_path", "N/A"),
        "Bash": lambda i: truncate(i.get("command", "N/A"), 100),
        "Glob": lambda i: i.get("pattern", "N/A"),
        "Grep": lambda i: i.get("pattern", "N/A"),
        "WebFetch": lambda i: i.get("url", "N/A"),
        "WebSearch": lambda i: i.get("query", "N/A"),
        "Skill": lambda i: i.get("skill", "N/A"),
        "Agent": lambda i: i.get("subagent_type", "N/A"),
    }

    extractor = extractors.get(tool)
    if extractor:
        try:
            return extractor(tool_input)
        except Exception:
            pass
    return "N/A"


def extract_details(tool: str, tool_input: Dict[str, Any]) -> Dict[str, Any]:
    """提取工具输入的详细信息（用于审计日志）"""
    details = {}

    if tool == "Read":
        details["file_path"] = tool_input.get("file_path", "")

    elif tool == "Write":
        details["file_path"] = tool_input.get("file_path", "")
        content = tool_input.get("content", "")
        details["content_length"] = len(content)

    elif tool == "Edit":
        details["file_path"] = tool_input.get("file_path", "")
        details["old_length"] = len(tool_input.get("old_string", ""))
        details["new_length"] = len(tool_input.get("new_string", ""))

    elif tool == "Bash":
        details["command"] = truncate(tool_input.get("command", ""), 200)

    elif tool in ("Glob", "Grep"):
        details["pattern"] = tool_input.get("pattern", "")
        details["path"] = tool_input.get("path", "")

    elif tool == "Skill":
        details["skill"] = tool_input.get("skill", "")
        details["args"] = tool_input.get("args", "")

    elif tool == "Agent":
        details["type"] = tool_input.get("subagent_type", "")
        details["prompt_preview"] = truncate(tool_input.get("prompt", ""), 100)

    return details


# ============================================================================
# 时间戳
# ============================================================================

def get_timestamp() -> str:
    """获取 UTC 时间戳"""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def get_session_id() -> str:
    """获取会话 ID"""
    return datetime.now().strftime("%Y%m%d_%H%M%S")


# ============================================================================
# 审计日志
# ============================================================================

AUDIT_DIR = "tools/state/audit"
AUDIT_JSONL = os.path.join(AUDIT_DIR, "audit.jsonl")
AUDIT_LOG = os.path.join(AUDIT_DIR, "audit.log")


def write_audit_log(tool: str, action: str, target: str,
                    details: Dict[str, Any], session: str, success: bool = True):
    """写入审计日志"""
    # 确保目录存在
    os.makedirs(AUDIT_DIR, exist_ok=True)

    timestamp = get_timestamp()

    # JSON 记录
    record = {
        "timestamp": timestamp,
        "session": session,
        "tool": tool,
        "action": action,
        "target": target,
        "details": details,
        "success": success
    }

    with open(AUDIT_JSONL, "a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")

    # 可读日志
    status = "✓" if success else "✗"
    log_line = f"[{timestamp}] [{status}] {tool}: {action} - {truncate(target, 80)}"

    with open(AUDIT_LOG, "a", encoding="utf-8") as f:
        f.write(log_line + "\n")


# ============================================================================
# 失败记录
# ============================================================================

FAILURE_FILE = "tools/state/last_failure.json"


def save_failure(failure_type: str, command: str, module: str = ""):
    """保存失败记录"""
    os.makedirs(os.path.dirname(FAILURE_FILE), exist_ok=True)

    record = {
        "failed": True,
        "type": failure_type,
        "command": command,
        "module": module,
        "timestamp": get_timestamp()
    }

    with open(FAILURE_FILE, "w", encoding="utf-8") as f:
        json.dump(record, f, ensure_ascii=False)


# ============================================================================
# 错误模式匹配
# ============================================================================

ERROR_PATTERNS = {
    "compile": [
        r"error:",
        r"fatal error:",
        r"undefined reference",
        r"cannot find",
        r"was not declared",
        r"compilation failed",
    ],
    "test": [
        r"\[  FAILED  \]",
        r"Assertion",
        r"expected",
        r"actual",
        r"FAIL:",
        r"panic:",
        r"test failed",
    ],
    "runtime": [
        r"segmentation fault",
        r"SIGSEGV",
        r"panic:",
        r"exception",
        r"core dumped",
        r"runtime error",
    ]
}


def detect_error_type(output: str) -> Optional[str]:
    """检测错误类型"""
    import re

    for error_type, patterns in ERROR_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, output, re.IGNORECASE):
                return error_type
    return None