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

# 负载均衡状态
echo ""
log_step "负载均衡 (端口 9000)"
if is_loadbalance_running; then
    pid=$(cat "$LOADBALANCE_DIR/logs/nginx.pid" 2>/dev/null)
    log_success "运行中 (PID: $pid)"
else
    log_warn "未运行"
fi

# Web-Admin 状态
echo ""
log_step "Web-Admin (端口 8080)"
if check_openresty_built; then
    if is_running "$BACKEND_LOGS_DIR/nginx.pid"; then
        pid=$(cat "$BACKEND_LOGS_DIR/nginx.pid" 2>/dev/null)
        log_success "运行中 (PID: $pid)"
        echo "  API: http://localhost:8080/api"
        echo "  前端: http://localhost:8080"
    else
        log_warn "未运行"
    fi
else
    log_error "未构建 - 请先运行 /dev build"
fi

# 端口监听状态
echo ""
log_step "端口监听"
for port in 8080 9000; do
    pid=$(get_pid_by_port "$port")
    if [[ -n "$pid" ]]; then
        echo -e "  $port: ${GREEN}监听中${NC} (PID: $pid)"
    else
        echo -e "  $port: ${YELLOW}未使用${NC}"
    fi
done

# 目录信息
echo ""
log_step "目录"
echo "  项目: $PROJECT_ROOT"
echo "  构建: $BUILD_DIR"
echo "  配置: $CONFIGS_DIR"

log_info "=========================================="