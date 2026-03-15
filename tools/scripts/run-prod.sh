#!/usr/bin/env bash
#
# 启动生产 OpenResty 实例
#
# 用法: ./run-prod.sh [--reload]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 参数解析
RELOAD=false

for arg in "$@"; do
    case $arg in
        --reload|-r) RELOAD=true ;;
        --help|-h)   echo "用法: $0 [--reload]"; exit 0 ;;
    esac
done

# ============================================================
# 主逻辑
# ============================================================

log_info "=========================================="
log_info "启动生产 OpenResty"
log_info "=========================================="

# 检查 OpenResty
if ! check_openresty_built; then
    exit 1
fi

# 重载模式
if [[ "$RELOAD" == "true" ]]; then
    if reload_nginx_prod; then
        log_success "生产配置已重载"
    else
        log_error "重载失败"
        exit 1
    fi
    exit 0
fi

# 检查是否已在运行
if is_prod_running; then
    log_warn "生产 OpenResty 已在运行"
    log_info "使用 '$0 --reload' 重载配置"
    exit 0
fi

# 启动
if start_nginx_prod; then
    log_info "=========================================="
    log_success "生产 OpenResty 启动成功"
    log_info "HTTP 端口: 80"
    log_info "HTTPS 端口: 443 (如已配置)"
    log_info "健康检查: http://localhost/nginx-health"
    log_info "=========================================="
else
    log_error "启动失败"
    exit 1
fi