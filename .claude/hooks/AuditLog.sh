#!/bin/bash
# AuditLog Hook - 审计日志记录
# 记录 AI 执行的所有工具操作
#
# 数据通过 stdin 以 JSON 格式传入

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 确保目录存在
mkdir -p "tools/state/audit" 2>/dev/null || true

# 从 stdin 读取 JSON 数据
INPUT_JSON=$(cat 2>/dev/null || echo "{}")

# 使用 Python 处理，通过环境变量传递数据
INPUT_JSON="$INPUT_JSON" SCRIPT_DIR="$SCRIPT_DIR" python3 -c '
import sys
import os

# 添加脚本目录到 Python 路径
script_dir = os.environ.get("SCRIPT_DIR", ".")
sys.path.insert(0, script_dir)

from hooks_lib import (
    read_stdin_json, get_timestamp, get_session_id,
    get_action_desc, truncate, extract_target, extract_details,
    write_audit_log
)

def main():
    data = read_stdin_json()

    tool_name = data.get("tool_name", "Unknown")
    tool_input = data.get("tool_input", {})
    session_id = data.get("session_id", get_session_id())

    # 提取操作信息
    action = get_action_desc(tool_name)
    target = extract_target(tool_name, tool_input)
    details = extract_details(tool_name, tool_input)

    # 写入审计日志
    write_audit_log(
        tool=tool_name,
        action=action,
        target=target,
        details=details,
        session=session_id,
        success=True
    )

if __name__ == "__main__":
    main()
'

exit 0