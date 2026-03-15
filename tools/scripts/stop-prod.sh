#!/usr/bin/env bash
#
# 停止生产 OpenResty 实例
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================================
# 主逻辑
# ============================================================

log_info "=========================================="
log_info "停止生产 OpenResty"
log_info "=========================================="

if stop_nginx_prod; then
    log_info "=========================================="
    log_success "生产 OpenResty 已停止"
    log_info "=========================================="
else
    log_warn "生产 OpenResty 未运行"
fi