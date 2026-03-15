#!/usr/bin/env bash
#
# 查看服务状态
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================================
# 主逻辑
# ============================================================

log_info "=========================================="
log_info "服务状态"
log_info "=========================================="

# OpenResty 状态
echo ""
log_step "OpenResty"
if check_openresty_built; then
    if is_running "$BACKEND_LOGS_DIR/nginx.pid"; then
        pid=$(cat "$BACKEND_LOGS_DIR/nginx.pid" 2>/dev/null)
        log_success "运行中 (PID: $pid)"
        echo "  API: http://localhost:8080/api"
        echo "  生产: http://localhost:8081"
    elif is_running "$NGINX_LOGS_DIR/nginx.pid"; then
        pid=$(cat "$NGINX_LOGS_DIR/nginx.pid" 2>/dev/null)
        log_success "运行中 (PID: $pid) - 默认配置"
        echo "  地址: http://localhost:8080"
    else
        log_warn "未运行"
    fi
    echo "  二进制: $NGINX_BIN"
else
    log_error "未构建"
fi

# 前端状态
echo ""
log_step "前端 (Vite)"
pid=$(get_pid_by_port "$FRONTEND_PORT")
if [[ -n "$pid" ]]; then
    log_success "运行中 (PID: $pid)"
    echo "  地址: http://localhost:$FRONTEND_PORT"
elif [[ -d "$FRONTEND_DIR/node_modules" ]]; then
    log_warn "未运行"
else
    log_warn "未安装依赖"
fi

# 端口监听状态
echo ""
log_step "端口监听"
for port in 8080 8081 5173; do
    pid=$(get_pid_by_port "$port")
    if [[ -n "$pid" ]]; then
        status="${GREEN}监听中${NC} (PID: $pid)"
    else
        status="${YELLOW}未使用${NC}"
    fi
    echo -e "  $port: $status"
done

# 目录信息
echo ""
log_step "目录"
echo "  项目: $PROJECT_ROOT"
echo "  源码: $SRC_DIR"
echo "  构建: $BUILD_DIR"
echo "  配置: $CONFIGS_DIR"

log_info "=========================================="