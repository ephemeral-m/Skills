#!/usr/bin/env bash
#
# 日志调试脚本
#
# 用法: log.sh <type> <lines> <grep> <follow>
#

set -e

# ============================================================
# 配置
# ============================================================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TOOLS_DIR/.." && pwd)"

# 日志目录
LOG_DIR="$PROJECT_ROOT/src/loadbalance/logs"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 参数
# ============================================================
TYPE=${1:-error}
LINES=${2:-50}
GREP=${3:-}
FOLLOW=${4:-false}

# ============================================================
# 函数
# ============================================================

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 日志文件映射
get_log_file() {
    local type=$1
    case $type in
        error)
            echo "$LOG_DIR/error.log"
            ;;
        access)
            echo "$LOG_DIR/access.log"
            ;;
        stream)
            echo "$LOG_DIR/stream.log"
            ;;
        *)
            echo "$LOG_DIR/error.log"
            ;;
    esac
}

# 格式化日志输出
format_log() {
    local file=$1
    local lines=$2
    local grep_pattern=$3

    if [[ ! -f "$file" ]]; then
        log_warn "日志文件不存在: $file"
        return 1
    fi

    if [[ -n "$grep_pattern" ]]; then
        grep -i --color=always "$grep_pattern" "$file" | tail -n "$lines"
    else
        tail -n "$lines" "$file"
    fi
}

# 实时跟踪日志
follow_log() {
    local file=$1
    local grep_pattern=$2

    if [[ ! -f "$file" ]]; then
        log_error "日志文件不存在: $file"
        return 1
    fi

    log_info "实时跟踪: $file (按 Ctrl+C 退出)"

    if [[ -n "$grep_pattern" ]]; then
        tail -f "$file" | grep --line-buffered -i --color=always "$grep_pattern"
    else
        tail -f "$file"
    fi
}

# 显示日志统计
show_stats() {
    local file=$1

    if [[ -f "$file" ]]; then
        local size=$(du -h "$file" 2>/dev/null | cut -f1)
        local lines=$(wc -l < "$file" 2>/dev/null)
        local errors=$(grep -c "\[error\]" "$file" 2>/dev/null || echo 0)
        local warns=$(grep -c "\[warn\]" "$file" 2>/dev/null || echo 0)

        echo ""
        echo -e "${CYAN}=== 日志统计 ===${NC}"
        echo "文件: $file"
        echo "大小: $size"
        echo "行数: $lines"
        echo "错误: $errors"
        echo "警告: $warns"
        echo ""
    fi
}

# ============================================================
# 主逻辑
# ============================================================

LOG_FILE=$(get_log_file "$TYPE")

echo -e "${CYAN}=== $TYPE 日志 ===${NC}"
echo ""

if [[ "$FOLLOW" == "true" ]]; then
    # 实时跟踪模式
    show_stats "$LOG_FILE"
    follow_log "$LOG_FILE" "$GREP"
else
    # 查看模式
    show_stats "$LOG_FILE"
    format_log "$LOG_FILE" "$LINES" "$GREP"
fi