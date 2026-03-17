#!/usr/bin/env bash
#
# GDB 调试脚本
#
# 用法: gdb.sh <action> [args]
#   attach    - 附加到运行进程（交互模式）
#   bt        - 显示所有线程调用栈
#   info      - 查看进程信息
#   core      - 分析 core dump
#   status    - 调试状态概览
#

set -e

# ============================================================
# 配置
# ============================================================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TOOLS_DIR/.." && pwd)"

# OpenResty 路径
BUILD_DIR="$PROJECT_ROOT/build"
OPENRESTY_PREFIX="$BUILD_DIR/openresty"
NGINX_BIN="$OPENRESTY_PREFIX/nginx/sbin/nginx"

# 负载均衡实例目录
LOADBALANCE_DIR="$PROJECT_ROOT/src/loadbalance"
PID_FILE="$LOADBALANCE_DIR/logs/nginx.pid"
LOG_DIR="$LOADBALANCE_DIR/logs"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 函数
# ============================================================

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

# 获取 nginx PID
get_nginx_pid() {
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE" 2>/dev/null
    fi
}

# 检查进程是否运行
is_running() {
    local pid=$1
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# 获取 core dump 目录
get_core_dir() {
    local core_pattern=$(cat /proc/sys/kernel/core_pattern 2>/dev/null)

    if [[ "$core_pattern" =~ ^/ ]]; then
        # 绝对路径
        echo "${core_pattern%/*}"
    else
        # 相对路径，使用工作目录
        echo "$LOADBALANCE_DIR"
    fi
}

# ============================================================
# 命令实现
# ============================================================

# 附加到进程
cmd_attach() {
    local pid=$(get_nginx_pid)

    if ! is_running "$pid"; then
        log_error "Nginx 未运行"
        return 1
    fi

    log_info "附加到 Nginx Master 进程: PID=$pid"
    log_warn "进程将被暂停，使用 'detach' 命令恢复"
    echo ""

    # 启动交互式 GDB
    gdb -p "$pid"
}

# 显示所有线程调用栈
cmd_bt() {
    local pid=$(get_nginx_pid)

    if ! is_running "$pid"; then
        log_error "Nginx 未运行"
        return 1
    fi

    log_info "获取进程 $pid 的线程调用栈..."
    echo ""

    # 使用 batch 模式获取所有线程的完整调用栈
    gdb -batch \
        -ex "set pagination off" \
        -ex "thread apply all bt full" \
        -ex "info threads" \
        -p "$pid" 2>/dev/null || {
            log_error "GDB 附加失败，可能需要 root 权限"
            return 1
        }
}

# 查看进程信息
cmd_info() {
    local pid=$(get_nginx_pid)

    if ! is_running "$pid"; then
        log_error "Nginx 未运行"
        return 1
    fi

    echo -e "${CYAN}=== 进程信息 ===${NC}"
    echo ""

    # 基本进程信息
    echo -e "${BLUE}>>> 基本信息${NC}"
    ps -p "$pid" -o pid,ppid,user,%cpu,%mem,vsz,rss,stat,time,comm 2>/dev/null || echo "无法获取进程信息"
    echo ""

    # 线程信息
    echo -e "${BLUE}>>> 线程列表${NC}"
    ps -T -p "$pid" -o spid,lwp,stat,time,comm 2>/dev/null | head -20 || echo "无法获取线程信息"
    echo ""

    # 内存映射
    echo -e "${BLUE}>>> 内存映射 (前 30 行)${NC}"
    pmap "$pid" 2>/dev/null | head -30 || echo "无法获取内存映射"
    echo ""

    # 打开的文件
    echo -e "${BLUE}>>> 打开的文件 (前 20 个)${NC}"
    ls -la /proc/"$pid"/fd 2>/dev/null | head -20 || echo "无法获取文件描述符"
    echo ""

    # 网络连接
    echo -e "${BLUE}>>> 网络连接${NC}"
    if command -v ss &>/dev/null; then
        ss -tnp 2>/dev/null | grep "pid=$pid" || echo "无网络连接"
    elif command -v netstat &>/dev/null; then
        netstat -tnp 2>/dev/null | grep "$pid" || echo "无网络连接"
    else
        echo "无法获取网络连接"
    fi
    echo ""

    # 资源限制
    echo -e "${BLUE}>>> 资源限制${NC}"
    cat /proc/"$pid"/limits 2>/dev/null | grep -E "core|open files|processes|memory" || echo "无法获取资源限制"
}

# 分析 core dump
cmd_core() {
    local core_dir=${1:-}
    local core_file=""

    # 确定搜索目录
    if [[ -z "$core_dir" ]]; then
        core_dir=$(get_core_dir)
    fi

    log_info "搜索 core dump: $core_dir"
    echo ""

    # 查找最新的 core 文件
    if [[ -d "$core_dir" ]]; then
        core_file=$(find "$core_dir" -name "core*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    fi

    if [[ -z "$core_file" ]]; then
        log_warn "未找到 core dump 文件"
        echo ""
        echo "配置 core dump:"
        echo "  1. echo '/var/core/core.%e.%p' | sudo tee /proc/sys/kernel/core_pattern"
        echo "  2. ulimit -c unlimited"
        echo "  3. 重启 nginx"
        return 1
    fi

    local core_size=$(du -h "$core_file" 2>/dev/null | cut -f1)
    local core_time=$(stat -c '%y' "$core_file" 2>/dev/null | cut -d'.' -f1)

    echo -e "${CYAN}=== Core Dump 分析 ===${NC}"
    echo "文件: $core_file"
    echo "大小: $core_size"
    echo "时间: $core_time"
    echo ""

    # 使用 GDB 分析
    log_info "分析调用栈..."
    gdb -batch \
        -ex "set pagination off" \
        -ex "bt full" \
        -ex "info threads" \
        -ex "thread apply all bt" \
        "$NGINX_BIN" "$core_file" 2>/dev/null || {
            log_error "GDB 分析失败，检查 core 文件是否完整"
            return 1
        }
}

# 调试状态概览
cmd_status() {
    local pid=$(get_nginx_pid)

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   调试状态概览                              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # 进程状态
    echo -e "${BLUE}>>> 进程状态${NC}"
    if is_running "$pid"; then
        echo -e "状态: ${GREEN}运行中${NC} (PID: $pid)"
        ps -p "$pid" -o pid,ppid,%cpu,%mem,vsz,rss,stat,time,comm 2>/dev/null | tail -1
    else
        echo -e "状态: ${RED}未运行${NC}"
    fi
    echo ""

    # 日志文件
    echo -e "${BLUE}>>> 日志文件${NC}"
    for log in error.log access.log stream.log; do
        local log_path="$LOG_DIR/$log"
        if [[ -f "$log_path" ]]; then
            local size=$(du -h "$log_path" 2>/dev/null | cut -f1)
            local lines=$(wc -l < "$log_path" 2>/dev/null)
            echo "  $log: $size ($lines 行)"
        else
            echo "  $log: 不存在"
        fi
    done
    echo ""

    # Core dump 配置
    echo -e "${BLUE}>>> Core Dump 配置${NC}"
    local core_pattern=$(cat /proc/sys/kernel/core_pattern 2>/dev/null)
    echo "  Pattern: $core_pattern"

    local core_dir=$(get_core_dir)
    local core_count=$(find "$core_dir" -name "core*" -type f 2>/dev/null | wc -l)
    echo "  目录: $core_dir"
    echo "  数量: $core_count 个文件"
    echo ""

    # GDB 可用性
    echo -e "${BLUE}>>> 工具可用性${NC}"
    command -v gdb &>/dev/null && echo "  GDB: ${GREEN}可用${NC}" || echo "  GDB: ${RED}不可用${NC}"
    command -v gdbserver &>/dev/null && echo "  GDBServer: ${GREEN}可用${NC}" || echo "  GDBServer: ${YELLOW}不可用${NC}"
    echo ""

    # 网络端口
    echo -e "${BLUE}>>> 网络端口${NC}"
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep -E "LISTEN|Local" | head -10
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep -E "LISTEN|Local" | head -10
    else
        echo "  无法获取网络端口"
    fi
    echo ""

    # 快捷命令
    echo -e "${BLUE}>>> 快捷命令${NC}"
    echo "  /debug log --follow     # 实时日志跟踪"
    echo "  /debug c --bt           # 查看调用栈"
    echo "  /debug c --info         # 进程详情"
    echo "  /debug c --core         # Core dump 分析"
    echo "  /debug lua --errors     # Lua 错误"
}

# ============================================================
# 主逻辑
# ============================================================

ACTION=${1:-status}

case $ACTION in
    attach)
        cmd_attach
        ;;
    bt)
        cmd_bt
        ;;
    info)
        cmd_info
        ;;
    core)
        cmd_core "${2:-}"
        ;;
    status)
        cmd_status
        ;;
    *)
        echo "用法: gdb.sh <attach|bt|info|core|status>"
        echo ""
        echo "命令说明:"
        echo "  attach  - 附加到运行进程（交互模式）"
        echo "  bt      - 显示所有线程调用栈"
        echo "  info    - 查看进程信息"
        echo "  core    - 分析 core dump"
        echo "  status  - 调试状态概览"
        exit 1
        ;;
esac