#!/usr/bin/env bash
#
# 审计日志查看工具
#
# 用法:
#   audit-log.sh              # 查看最近的审计日志
#   audit-log.sh --tail 50    # 查看最后 50 条
#   audit-log.sh --tool Write # 只查看 Write 工具
#   audit-log.sh --failed     # 只查看失败的操作
#   audit-log.sh --json       # JSON 格式输出
#

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIT_DIR="$PROJECT_ROOT/tools/state/audit"
AUDIT_LOG="$AUDIT_DIR/audit.log"
AUDIT_JSON="$AUDIT_DIR/audit.jsonl"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认参数
LINES=30
TOOL_FILTER=""
FAILED_ONLY=false
JSON_OUTPUT=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --tail|-n)
            LINES="$2"
            shift 2
            ;;
        --tool|-t)
            TOOL_FILTER="$2"
            shift 2
            ;;
        --failed|-f)
            FAILED_ONLY=true
            shift
            ;;
        --json|-j)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            echo "用法: audit-log.sh [选项]"
            echo ""
            echo "选项:"
            echo "  --tail, -n N      显示最后 N 条记录 (默认 30)"
            echo "  --tool, -t TOOL   只显示指定工具的记录"
            echo "  --failed, -f      只显示失败的操作"
            echo "  --json, -j        JSON 格式输出"
            echo "  --help, -h        显示帮助"
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
    esac
done

# 检查日志文件
if [[ ! -f "$AUDIT_LOG" && ! -f "$AUDIT_JSON" ]]; then
    echo -e "${YELLOW}审计日志文件不存在${NC}"
    echo "日志将在 AI 执行操作后自动生成"
    exit 0
fi

# JSON 格式输出
if [[ "$JSON_OUTPUT" == "true" ]]; then
    if [[ -f "$AUDIT_JSON" ]]; then
        if [[ -n "$TOOL_FILTER" ]]; then
            grep "\"tool\":\"$TOOL_FILTER\"" "$AUDIT_JSON" | tail -n "$LINES"
        elif [[ "$FAILED_ONLY" == "true" ]]; then
            grep '"success":false' "$AUDIT_JSON" | tail -n "$LINES"
        else
            tail -n "$LINES" "$AUDIT_JSON"
        fi
    else
        echo "JSON 日志文件不存在"
        exit 1
    fi
    exit 0
fi

# 文本格式输出
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      审计日志                              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [[ -f "$AUDIT_LOG" ]]; then
    # 统计信息
    total=$(wc -l < "$AUDIT_LOG" 2>/dev/null || echo 0)
    failed=$(grep -c '\[✗\]' "$AUDIT_LOG" 2>/dev/null || echo 0)
    echo -e "${BLUE}统计:${NC} 总计 $total 条记录, $failed 条失败"
    echo ""

    echo -e "${BLUE}最近 $LINES 条记录:${NC}"
    echo ""

    # 过滤并显示
    cmd="tail -n $LINES \"$AUDIT_LOG\""
    if [[ -n "$TOOL_FILTER" ]]; then
        cmd="grep \"$TOOL_FILTER\" \"$AUDIT_LOG\" | tail -n $LINES"
    fi

    if [[ "$FAILED_ONLY" == "true" ]]; then
        cmd="grep '\[✗\]' \"$AUDIT_LOG\" | tail -n $LINES"
    fi

    eval "$cmd" | while IFS= read -r line; do
        # 高亮显示
        if echo "$line" | grep -q '\[✗\]'; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -q '\[✓\]'; then
            echo -e "${GREEN}$line${NC}"
        else
            echo "$line"
        fi
    done
else
    echo -e "${YELLOW}审计日志文件不存在: $AUDIT_LOG${NC}"
fi

echo ""
echo -e "${BLUE}日志文件位置:${NC}"
echo "  $AUDIT_LOG"
echo "  $AUDIT_JSON"