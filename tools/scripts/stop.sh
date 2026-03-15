#!/usr/bin/env bash
#
# 停止开发服务
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================================
# 主逻辑
# ============================================================

log_info "=========================================="
log_info "停止开发服务"
log_info "=========================================="

stopped=0

# 停止 OpenResty
if stop_nginx; then
    stopped=$((stopped + 1))
fi

# 尝试通过端口停止残留进程
for port in 8080 8081; do
    pid=$(get_pid_by_port "$port")
    if [[ -n "$pid" ]]; then
        log_info "发现端口 $port 进程 (PID: $pid)，正在停止..."
        kill "$pid" 2>/dev/null || true
        stopped=$((stopped + 1))
    fi
done

# 停止前端
if stop_frontend; then
    stopped=$((stopped + 1))
fi

# 输出结果
log_info "=========================================="
if [[ $stopped -gt 0 ]]; then
    log_success "已停止 $stopped 个服务"
else
    log_warn "未发现运行中的服务"
fi
log_info "=========================================="