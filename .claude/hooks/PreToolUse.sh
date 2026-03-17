#!/bin/bash
# PreToolUse Hook - 工具执行前检查
# 用于命令验证、参数预处理、安全检查等
#
# 数据通过 stdin 以 JSON 格式传入

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 从 stdin 读取 JSON 数据
INPUT_JSON=$(cat 2>/dev/null || echo "{}")

# 使用 Python 处理，通过环境变量传递数据
INPUT_JSON="$INPUT_JSON" python3 -c '
import sys
import os
import re

# 添加脚本目录到 Python 路径
script_dir = os.environ.get("SCRIPT_DIR", ".")
sys.path.insert(0, script_dir)

from hooks_lib import read_stdin_json, Colors

def check_dangerous_commands(command):
    """检查危险命令"""
    dangerous_patterns = [
        (r"rm\s+-rf\s+/", "rm -rf / - 删除根目录"),
        (r"rm\s+-rf\s+/\*", "rm -rf /* - 删除根目录所有文件"),
        (r"dd\s+if=/dev/zero", "dd 覆盖磁盘"),
        (r"mkfs", "格式化磁盘"),
        (r">\s*/dev/sda", "直接写入磁盘设备"),
        (r"chmod\s+-R\s+777\s+/", "递归修改根目录权限"),
        (r"curl.*\|\s*bash", "curl 管道执行脚本"),
        (r"wget.*\|\s*bash", "wget 管道执行脚本"),
    ]

    for pattern, desc in dangerous_patterns:
        if re.search(pattern, command):
            print(Colors.red(f"[Hook] 检测到危险操作: {desc}"))
            print(Colors.red(f"[Hook] 已阻止执行: {command[:80]}..."))
            return False
    return True

def check_git_operations(command):
    """检查 Git 危险操作"""
    warnings = []

    if re.search(r"git\s+push\s+(-f|--force)", command):
        warnings.append("force push 可能会覆盖远程提交")

    if re.search(r"git\s+reset\s+--hard", command):
        warnings.append("reset --hard 会丢失未提交的更改")

    if re.search(r"git\s+clean\s+-fdx?", command):
        warnings.append("clean 会删除未跟踪的文件")

    for warning in warnings:
        print(Colors.yellow(f"[Hook] 警告: {warning}"))

def check_file_operations(command):
    """检查文件操作"""
    # 检查删除重要配置文件
    if re.search(r"rm.*dev\.yaml|rm.*CLAUDE\.md", command):
        print(Colors.yellow("[Hook] 警告: 正在删除配置文件"))

def main():
    data = read_stdin_json()

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})

    # 只处理 Bash 工具
    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")
    if not command:
        sys.exit(0)

    # 执行检查
    if not check_dangerous_commands(command):
        sys.exit(1)  # 阻止执行

    check_git_operations(command)
    check_file_operations(command)

    # 正常放行
    sys.exit(0)

if __name__ == "__main__":
    main()
' 2>/dev/null

exit $?