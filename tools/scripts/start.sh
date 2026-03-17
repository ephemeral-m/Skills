#!/usr/bin/env bash
#
# 启动开发服务
#
# 用法: ./start.sh [--loadbalance-only|--webadmin-only]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 参数解析
LOADBALANCE_ONLY=false
WEBADMIN_ONLY=false

for arg in "$@"; do
    case $arg in
        --loadbalance-only|-l)  LOADBALANCE_ONLY=true ;;
        --webadmin-only|-w)     WEBADMIN_ONLY=true ;;
        --help|-h)              echo "用法: $0 [--loadbalance-only|--webadmin-only]"; exit 0 ;;
    esac
done

# ============================================================
# 主逻辑
# ============================================================

log_info "=========================================="
log_info "启动服务"
log_info "=========================================="

# 检查 OpenResty
if ! check_openresty_built; then
    exit 1
fi

started=0

# ============================================================
# 启动负载均衡 (端口 9000)
# ============================================================
if [[ "$WEBADMIN_ONLY" != "true" ]]; then
    if is_loadbalance_running; then
        log_warn "负载均衡已在运行，正在停止..."
        stop_nginx_loadbalance || true
        sleep 1
    fi
    if start_nginx_loadbalance; then
        started=$((started + 1))
    fi
fi

# ============================================================
# 构建前端 + 启动 web-admin (端口 8080)
# ============================================================
if [[ "$LOADBALANCE_ONLY" != "true" ]]; then
    # 构建前端静态文件
    build_frontend

    if is_running "$BACKEND_LOGS_DIR/nginx.pid"; then
        log_warn "web-admin 已在运行，正在停止..."
        stop_nginx || true
        sleep 1
    fi

    log_info "启动 web-admin..."
    if start_nginx_webadmin; then
        started=$((started + 1))
    else
        log_error "web-admin 启动失败"
        exit 1
    fi
fi

# 输出结果
log_info "=========================================="
if [[ $started -gt 0 ]]; then
    log_success "已启动 $started 个服务"
    log_info ""
    log_info "服务访问地址:"
    log_info "  ┌──────────────────────────────────────────────────────────────┐"
    log_info "  │ 服务         │ 端口  │ 用途                                  │"
    log_info "  ├──────────────────────────────────────────────────────────────┤"
    log_info "  │ 负载均衡     │ 9000  │ HTTP 反向代理、API 网关               │"
    log_info "  │ web-admin    │ 8080  │ 配置管理前端 + API                    │"
    log_info "  └──────────────────────────────────────────────────────────────┘"
    log_info ""
    log_info "访问 http://<server>:8080 管理负载均衡配置"
    log_info ""
    log_info "使用 '/dev stop' 停止服务"
else
    log_warn "未启动任何服务"
fi
log_info "=========================================="