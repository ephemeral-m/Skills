#!/usr/bin/env bash
#
# 启动开发服务
#
# 用法: ./run.sh [--frontend-only|--nginx-only|--loadbalance-only]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 参数解析
FRONTEND_ONLY=false
NGINX_ONLY=false
LOADBALANCE_ONLY=false

for arg in "$@"; do
    case $arg in
        --frontend-only|-f)     FRONTEND_ONLY=true ;;
        --nginx-only|-n)        NGINX_ONLY=true ;;
        --loadbalance-only|-l)  LOADBALANCE_ONLY=true ;;
        --help|-h)              echo "用法: $0 [--frontend-only|--nginx-only|--loadbalance-only]"; exit 0 ;;
    esac
done

# ============================================================
# 主逻辑
# ============================================================

log_info "=========================================="
log_info "启动开发服务"
log_info "=========================================="

# 检查 OpenResty
if ! check_openresty_built; then
    exit 1
fi

# 检查是否已在运行
if is_running "$BACKEND_LOGS_DIR/nginx.pid" || is_running "$NGINX_LOGS_DIR/nginx.pid"; then
    log_warn "web-admin 服务已在运行"
fi

if is_loadbalance_running; then
    log_warn "负载均衡服务已在运行"
fi

started=0

# ============================================================
# 启动负载均衡 (端口 80/443)
# ============================================================
if [[ "$FRONTEND_ONLY" != "true" && "$NGINX_ONLY" != "true" ]]; then
    if [[ "$LOADBALANCE_ONLY" == "true" ]] || [[ "$FRONTEND_ONLY" != "true" && "$NGINX_ONLY" != "true" ]]; then
        if is_loadbalance_running; then
            log_info "负载均衡已在运行"
        else
            if start_nginx_loadbalance; then
                started=$((started + 1))
            fi
        fi
    fi
fi

# ============================================================
# 启动前端开发服务器 (端口 5173)
# ============================================================
if [[ "$NGINX_ONLY" != "true" && "$LOADBALANCE_ONLY" != "true" ]]; then
    if check_frontend_deps; then
        if start_frontend; then
            started=$((started + 1))
        fi
    else
        log_warn "跳过前端服务"
    fi
fi

# ============================================================
# 启动 web-admin OpenResty (端口 8080/8081)
# ============================================================
if [[ "$FRONTEND_ONLY" != "true" && "$LOADBALANCE_ONLY" != "true" ]]; then
    if is_running "$BACKEND_LOGS_DIR/nginx.pid"; then
        log_info "web-admin 已在运行"
    else
        log_info "启动 web-admin..."
        if start_nginx_webadmin; then
            log_success "web-admin 已启动"
            log_info "API 地址: http://localhost:8080/api"
            log_info "前端地址: http://localhost:8081"
            started=$((started + 1))
        else
            log_error "web-admin 启动失败"
            exit 1
        fi
    fi
fi

# 输出结果
log_info "=========================================="
if [[ $started -gt 0 ]]; then
    log_success "已启动 $started 个服务"
    log_info "使用 '/dev stop' 停止服务"
else
    log_warn "未启动任何服务"
fi
log_info "=========================================="