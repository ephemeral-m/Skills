#!/bin/bash
# PreToolUse Hook - 工具执行前检查
# 用于命令验证、参数预处理、安全检查等
#
# 环境变量:
#   CLAUDE_TOOL_NAME - 工具名称
#   CLAUDE_TOOL_INPUT - 工具输入 (JSON)

set -e

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 解析 JSON 辅助函数
json_get() {
    echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$2',''))" 2>/dev/null || echo ""
}

# 危险命令检查
check_dangerous_commands() {
    local command="$1"

    # 定义危险模式
    local dangerous_patterns=(
        "rm -rf /"
        "rm -rf /*"
        "dd if=/dev/zero"
        "mkfs"
        "> /dev/sda"
        "chmod -R 777 /"
        "curl.*|.*bash"
        "wget.*|.*bash"
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$command" =~ $pattern ]]; then
            echo -e "${RED}[HOOK] 检测到危险操作: $command${NC}"
            echo -e "${RED}[HOOK] 已阻止执行，请确认操作是否正确${NC}"
            return 1
        fi
    done

    # Git 危险操作警告
    if [[ "$command" =~ "git push --force" ]] || [[ "$command" =~ "git push -f" ]]; then
        echo -e "${YELLOW}[HOOK] 警告: force push 可能会覆盖远程提交${NC}"
        # 不阻止，只是警告
    fi

    if [[ "$command" =~ "git reset --hard" ]]; then
        echo -e "${YELLOW}[HOOK] 警告: reset --hard 会丢失未提交的更改${NC}"
    fi

    return 0
}

# 文件操作检查
check_file_operations() {
    local command="$1"

    # 检查删除重要文件
    if [[ "$command" =~ "rm.*dev\.yaml" ]] || [[ "$command" =~ "rm.*CLAUDE\.md" ]]; then
        echo -e "${YELLOW}[HOOK] 警告: 正在删除配置文件${NC}"
    fi
}

# 主逻辑
if [[ "$TOOL_NAME" == "Bash" ]]; then
    command=$(json_get "$TOOL_INPUT" "command")

    # 执行检查
    check_dangerous_commands "$command" || exit 1
    check_file_operations "$command"
fi

# 正常放行
exit 0