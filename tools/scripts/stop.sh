#!/usr/bin/env bash
#
# 停止开发服务
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================================
# 主逻辑
# ============================================================

log_info "=========================================="
log_info "停止服务"
log_info "=========================================="

stopped=0

# 停止负载均衡
if stop_nginx_loadbalance; then
    stopped=$((stopped + 1))
fi

# 停止 web-admin OpenResty
if stop_nginx; then
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