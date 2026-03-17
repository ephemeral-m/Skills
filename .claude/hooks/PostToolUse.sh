#!/bin/bash
# PostToolUse Hook - 命令执行后自动处理
# 当 dev build/test/all 失败时，智能建议修复 Skill
#
# 数据通过 stdin 以 JSON 格式传入

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 确保目录存在
mkdir -p "tools/state" 2>/dev/null || true

# 从 stdin 读取 JSON 数据
INPUT_JSON=$(cat 2>/dev/null || echo "{}")

# 使用 Python 处理，通过环境变量传递数据
# PYTHONIOENCODING 确保 Windows 下中文输出正确
PYTHONIOENCODING=utf-8 INPUT_JSON="$INPUT_JSON" SCRIPT_DIR="$SCRIPT_DIR" python3 -c '
import sys
import os
import re

# 添加脚本目录到 Python 路径
script_dir = os.environ.get("SCRIPT_DIR", ".")
sys.path.insert(0, script_dir)

from hooks_lib import (
    read_stdin_json, Colors, get_timestamp,
    get_action_desc, truncate, save_failure, detect_error_type
)

def extract_module(command):
    """从命令中提取模块名"""
    match = re.search(r"dev\s+(build|test|all)\s+([a-zA-Z0-9_-]+)", command)
    return match.group(2) if match else ""

def print_suggestion(title, skill_cmd):
    """打印建议信息"""
    print(Colors.yellow("━" * 50))
    print(Colors.yellow(f"[Hook] {title}"))
    print(Colors.yellow(f"建议执行: {skill_cmd}"))
    print(Colors.yellow("━" * 50))

def main():
    data = read_stdin_json()

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {})
    tool_response = data.get("tool_response", {})
    success = data.get("success", True)

    # 只处理 Bash 工具
    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")

    # 获取输出
    output = ""
    if isinstance(tool_response, dict):
        output = tool_response.get("output", "")
    elif isinstance(tool_response, str):
        output = tool_response

    # 提取模块名
    module = extract_module(command)

    # 分析失败命令
    if not success:
        # 检测错误类型
        error_type = detect_error_type(output)

        if error_type == "compile":
            print_suggestion("检测到编译错误", f"/fix-compile {module}")
            save_failure("compile", command, module)

        elif error_type == "test":
            print_suggestion("检测到测试失败", f"/fix-test {module}")
            save_failure("test", command, module)

        elif error_type == "runtime":
            print_suggestion("检测到运行时错误", "/fix-runtime")
            save_failure("runtime", command, module)

        else:
            # 检查是否是相关命令
            if re.match(r"^dev\s+(all|build|test|sync|start|stop)", command):
                print_suggestion("命令执行失败", "检查错误日志或请求 AI 协助")
                save_failure("unknown", command, module)

    sys.exit(0)

if __name__ == "__main__":
    main()
' 2>/dev/null || true

exit 0