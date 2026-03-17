#!/bin/bash
# AuditLog Hook - 审计日志记录
# 记录 AI 执行的所有工具操作
#
# 环境变量:
#   CLAUDE_TOOL_NAME - 工具名称
#   CLAUDE_TOOL_INPUT - 工具输入 (JSON)
#   CLAUDE_TOOL_RESULT - 工具结果 (JSON, PostToolUse 可用)
#   CLAUDE_TOOL_EXIT_CODE - 退出码 (PostToolUse 可用)

set -e

# 配置
AUDIT_DIR="tools/state/audit"
AUDIT_LOG="$AUDIT_DIR/audit.log"
AUDIT_JSON="$AUDIT_DIR/audit.jsonl"
MAX_LOG_SIZE_MB=10

# 颜色
CYAN='\033[0;36m'
NC='\033[0m'

# 确保目录存在
mkdir -p "$AUDIT_DIR"

# 获取时间戳
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# 获取会话 ID (使用日期作为简单标识)
get_session_id() {
    date +"%Y%m%d_%H%M%S"
}

# 解析 JSON 辅助函数
json_get() {
    local json="$1"
    local key="$2"
    echo "$json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    result = data.get('$key', '')
    if isinstance(result, str):
        print(result[:500])  # 截断长字符串
    else:
        print(str(result)[:500])
except:
    print('')
" 2>/dev/null || echo ""
}

# 截断内容
truncate() {
    local text="$1"
    local max_len="${2:-200}"
    if [ ${#text} -gt $max_len ]; then
        echo "${text:0:$max_len}..."
    else
        echo "$text"
    fi
}

# 获取操作描述
get_action_desc() {
    local tool="$1"
    case "$tool" in
        Read) echo "读取文件" ;;
        Write) echo "写入文件" ;;
        Edit) echo "编辑文件" ;;
        Bash) echo "执行命令" ;;
        Glob) echo "搜索文件" ;;
        Grep) echo "搜索内容" ;;
        WebFetch) echo "获取网页" ;;
        WebSearch) echo "搜索网络" ;;
        Skill) echo "调用技能" ;;
        Agent) echo "启动代理" ;;
        AskUserQuestion) echo "询问用户" ;;
        *) echo "其他操作" ;;
    esac
}

# 提取关键信息
extract_tool_info() {
    local tool="$1"
    local input="$2"

    case "$tool" in
        Read|Write)
            echo "file_path=$(json_get "$input" 'file_path')"
            ;;
        Edit)
            echo "file_path=$(json_get "$input" 'file_path')"
            local old_str=$(json_get "$input" 'old_string')
            local new_str=$(json_get "$input" 'new_string')
            echo "old=$(truncate "$old_str" 50)"
            echo "new=$(truncate "$new_str" 50)"
            ;;
        Bash)
            echo "command=$(json_get "$input" 'command')"
            ;;
        Glob)
            echo "pattern=$(json_get "$input" 'pattern')"
            echo "path=$(json_get "$input" 'path')"
            ;;
        Grep)
            echo "pattern=$(json_get "$input" 'pattern')"
            echo "path=$(json_get "$input" 'path')"
            ;;
        WebFetch)
            echo "url=$(json_get "$input" 'url')"
            ;;
        WebSearch)
            echo "query=$(json_get "$input" 'query')"
            ;;
        Skill)
            echo "skill=$(json_get "$input" 'skill')"
            echo "args=$(json_get "$input" 'args')"
            ;;
        Agent)
            echo "type=$(json_get "$input" 'subagent_type')"
            echo "prompt=$(truncate "$(json_get "$input" 'prompt')" 100)"
            ;;
    esac
}

# 检查日志轮转
check_rotation() {
    if [ -f "$AUDIT_LOG" ]; then
        local size_mb=$(du -m "$AUDIT_LOG" 2>/dev/null | cut -f1)
        if [ "$size_mb" -ge $MAX_LOG_SIZE_MB ]; then
            local backup="$AUDIT_DIR/audit_$(date +%Y%m%d_%H%M%S).log"
            mv "$AUDIT_LOG" "$backup"
            # 压缩旧日志
            gzip "$backup" 2>/dev/null || true
        fi
    fi
}

# 写入审计日志
write_audit_log() {
    local tool="$1"
    local action="$2"
    local target="$3"
    local details="$4"
    local success="$5"
    local timestamp=$(get_timestamp)
    local session_id=$(get_session_id)

    # JSON 格式日志
    local json_record=$(cat <<EOF
{"timestamp":"$timestamp","session":"$session_id","tool":"$tool","action":"$action","target":"$target","details":$details,"success":$success}
EOF
)

    # 追加到 JSON 日志
    echo "$json_record" >> "$AUDIT_JSON"

    # 人类可读格式
    local status_icon="✓"
    [ "$success" = "false" ] && status_icon="✗"

    local log_line="[$timestamp] [$status_icon] $tool: $action - $target"
    echo "$log_line" >> "$AUDIT_LOG"

    # 输出提示
    echo -e "${CYAN}[AUDIT]${NC} $tool: $action - $(truncate "$target" 60)" >&2
}

# 主逻辑
main() {
    local tool="${CLAUDE_TOOL_NAME:-Unknown}"
    local input="${CLAUDE_TOOL_INPUT:-{}}"
    local exit_code="${CLAUDE_TOOL_EXIT_CODE:-0}"

    # 检查日志轮转
    check_rotation

    # 获取操作描述
    local action=$(get_action_desc "$tool")

    # 提取关键信息
    local info=$(extract_tool_info "$tool" "$input")

    # 构建目标字符串
    local target=""
    case "$tool" in
        Read|Write|Edit)
            target=$(echo "$info" | grep "^file_path=" | cut -d'=' -f2-)
            ;;
        Bash)
            target=$(echo "$info" | grep "^command=" | cut -d'=' -f2-)
            ;;
        Glob)
            target=$(echo "$info" | grep "^pattern=" | cut -d'=' -f2-)
            ;;
        Grep)
            target=$(echo "$info" | grep "^pattern=" | cut -d'=' -f2-)
            ;;
        WebFetch)
            target=$(echo "$info" | grep "^url=" | cut -d'=' -f2-)
            ;;
        WebSearch)
            target=$(echo "$info" | grep "^query=" | cut -d'=' -f2-)
            ;;
        Skill)
            target=$(echo "$info" | grep "^skill=" | cut -d'=' -f2-)
            ;;
        Agent)
            target=$(echo "$info" | grep "^type=" | cut -d'=' -f2-)
            ;;
        *)
            target="N/A"
            ;;
    esac

    # 构建 details JSON
    local details="{}"
    if [ -n "$info" ]; then
        details=$(echo "$info" | python3 -c "
import sys, json
lines = sys.stdin.read().strip().split('\n')
result = {}
for line in lines:
    if '=' in line:
        k, v = line.split('=', 1)
        result[k] = v
print(json.dumps(result))
" 2>/dev/null || echo '{}')
    fi

    # 判断成功
    local success="true"
    [ "$exit_code" != "0" ] && success="false"

    # 写入日志
    write_audit_log "$tool" "$action" "$target" "$details" "$success"
}

main "$@"