#!/bin/bash
# PostToolUse Hook - 命令执行后自动处理
# 当 dev build/test/verify 失败时，智能建议修复 Skill
#
# 环境变量:
#   CLAUDE_TOOL_NAME - 工具名称
#   CLAUDE_TOOL_INPUT - 工具输入 (JSON)
#   CLAUDE_TOOL_RESULT - 工具结果
#   CLAUDE_TOOL_EXIT_CODE - 退出码

set -e

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 从环境变量获取工具信息
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
TOOL_RESULT="${CLAUDE_TOOL_RESULT:-}"
EXIT_CODE="${CLAUDE_TOOL_EXIT_CODE:-0}"

# 状态目录 (tools 目录结构)
STATE_DIR="tools/state"
HISTORY_FILE="$STATE_DIR/tool_history.json"

# 确保目录存在
mkdir -p "$STATE_DIR"

# 解析 JSON 辅助函数
json_get() {
    echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('$2',''))" 2>/dev/null || echo ""
}

# 记录工具调用历史
record_tool_call() {
    local timestamp=$(date -Iseconds 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
    local command=$(json_get "$TOOL_INPUT" "command")
    local needs_fix="false"

    if [[ "$EXIT_CODE" != "0" ]]; then
        needs_fix="true"
    fi

    local record=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "tool": "$TOOL_NAME",
  "command": "$command",
  "success": $([[ "$EXIT_CODE" == "0" ]] && echo "true" || echo "false"),
  "needs_fix": $needs_fix
}
EOF
)

    # 追加到历史文件
    if [ -f "$HISTORY_FILE" ]; then
        python3 -c "
import json
with open('$HISTORY_FILE', 'r') as f:
    history = json.load(f)
history.append($record)
# 只保留最近 50 条记录
history = history[-50:]
with open('$HISTORY_FILE', 'w') as f:
    json.dump(history, f, indent=2)
" 2>/dev/null || echo "[$record]" > "$HISTORY_FILE"
    else
        echo "[$record]" > "$HISTORY_FILE"
    fi
}

# 分类错误并建议修复
classify_and_suggest() {
    local output="$1"
    local command="$2"

    # 提取模块名（如果命令是 dev build xxx 或 dev test xxx）
    local module=""
    if [[ "$command" =~ dev\ (build|test|verify)\ ([a-zA-Z0-9_-]+) ]]; then
        module="${BASH_REMATCH[2]}"
    fi

    # 编译错误
    if echo "$output" | grep -qE "error:|fatal error:|undefined reference|cannot find|was not declared"; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}[Hook] 检测到编译错误${NC}"
        echo -e "${YELLOW}建议执行: /fix-compile ${module}${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # 保存失败状态
        echo "{\"failed\": true, \"type\": \"compile\", \"command\": \"$command\", \"module\": \"$module\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "$STATE_DIR/last_failure.json"
        return
    fi

    # 测试失败
    if echo "$output" | grep -qE "\[  FAILED  \]|Assertion|expected|actual|FAIL:|panic:"; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}[Hook] 检测到测试失败${NC}"
        echo -e "${YELLOW}建议执行: /fix-test ${module}${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        echo "{\"failed\": true, \"type\": \"test\", \"command\": \"$command\", \"module\": \"$module\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "$STATE_DIR/last_failure.json"
        return
    fi

    # 运行时错误
    if echo "$output" | grep -qE "segmentation fault|SIGSEGV|panic:|exception|core dumped"; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}[Hook] 检测到运行时错误${NC}"
        echo -e "${YELLOW}建议执行: /fix-runtime${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        echo "{\"failed\": true, \"type\": \"runtime\", \"command\": \"$command\", \"module\": \"$module\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "$STATE_DIR/last_failure.json"
        return
    fi

    # 通用失败
    if [[ "$EXIT_CODE" != "0" ]]; then
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}[Hook] 命令执行失败 (exit code: $EXIT_CODE)${NC}"
        echo -e "${YELLOW}建议检查错误日志或请求 AI 协助${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        echo "{\"failed\": true, \"type\": \"unknown\", \"command\": \"$command\", \"module\": \"$module\", \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}" > "$STATE_DIR/last_failure.json"
    fi
}

# 主逻辑
if [[ "$TOOL_NAME" == "Bash" ]]; then
    command=$(json_get "$TOOL_INPUT" "command")

    # 记录历史
    record_tool_call

    # 分析失败命令
    if [[ "$EXIT_CODE" != "0" ]]; then
        # 获取输出（从 TOOL_RESULT 或 stdout）
        output=""
        if [ -n "$TOOL_RESULT" ]; then
            output=$(json_get "$TOOL_RESULT" "output" 2>/dev/null || echo "")
        fi

        # 检查 dev 命令
        if [[ "$command" =~ ^dev\ (build|test|verify|sync) ]]; then
            classify_and_suggest "$output" "$command"
        # 检查直接编译命令
        elif [[ "$command" =~ (make|cmake|gcc|g\+\+|go\ build|cargo\ build) ]]; then
            classify_and_suggest "$output" "$command"
        # 检查测试命令
        elif [[ "$command" =~ (ctest|go\ test|pytest|cargo\ test|npm\ test) ]]; then
            classify_and_suggest "$output" "$command"
        fi
    fi
fi

exit 0