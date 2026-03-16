#!/usr/bin/env bash
#
# 公共函数和常量
#

# ============================================================
# 路径配置
# ============================================================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TOOLS_DIR/.." && pwd)"

# 源码目录
SRC_DIR="$PROJECT_ROOT/src"
OPENRESTY_SRC="$SRC_DIR/openresty"
LUA_PLUGINS_DIR="$SRC_DIR/lua-plugins"
WEB_ADMIN_DIR="$SRC_DIR/web-admin"

# 负载均衡实例目录
LOADBALANCE_DIR="$SRC_DIR/loadbalance"

# 构建目录
BUILD_DIR="$PROJECT_ROOT/build"
OPENRESTY_PREFIX="$BUILD_DIR/openresty"
NGINX_BIN="$OPENRESTY_PREFIX/nginx/sbin/nginx"
LUAJIT_BIN="$OPENRESTY_PREFIX/luajit/bin/luajit"

# 数据目录
DATA_DIR="$WEB_ADMIN_DIR/data"
CONFIGS_DIR="$DATA_DIR/configs"

# 日志目录
NGINX_LOGS_DIR="$OPENRESTY_PREFIX/nginx/logs"
BACKEND_LOGS_DIR="$WEB_ADMIN_DIR/backend/logs"

# ============================================================
# 颜色定义
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 日志函数
# ============================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "${CYAN}[STEP]${NC} $*"; }

# ============================================================
# 工具函数
# ============================================================

# 获取并行数
get_jobs() {
    echo "${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
}

# 检查命令是否存在
has_cmd() {
    command -v "$1" &>/dev/null
}

# 检查进程是否运行
is_running() {
    local pid_file=$1
    [[ -f "$pid_file" ]] || return 1
    local pid=$(cat "$pid_file" 2>/dev/null)
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# 获取端口对应的 PID
get_pid_by_port() {
    local port=$1 pid
    if has_cmd lsof; then
        pid=$(lsof -ti:"$port" 2>/dev/null | head -1)
    elif has_cmd ss; then
        pid=$(ss -tlnp 2>/dev/null | awk "\$4 ~ /:$port\$/ {split(\$7, a, \",\"); split(a[1], b, \"=\"); print b[2]; exit}")
    fi
    [[ -n "$pid" ]] && echo "$pid"
}

# ============================================================
# OpenResty 相关函数
# ============================================================

# 检查 OpenResty 是否已构建
check_openresty_built() {
    if [[ ! -x "$NGINX_BIN" ]]; then
        log_error "OpenResty 未构建，请先运行: /dev build"
        return 1
    fi
}

# 获取 nginx PID 文件路径
get_nginx_pid_file() {
    if [[ -f "$BACKEND_LOGS_DIR/nginx.pid" ]]; then
        echo "$BACKEND_LOGS_DIR/nginx.pid"
    else
        echo "$NGINX_LOGS_DIR/nginx.pid"
    fi
}

# 启动 nginx (web-admin 模式)
start_nginx_webadmin() {
    local backend_dir="$WEB_ADMIN_DIR/backend"
    local conf_file="$backend_dir/nginx.conf"

    [[ ! -f "$conf_file" ]] && log_error "配置文件不存在: $conf_file" && return 1

    mkdir -p "$BACKEND_LOGS_DIR" "$CONFIGS_DIR" "$CONFIGS_DIR/history"

    export LUA_PATH="$OPENRESTY_PREFIX/lualib/?.lua;$LUA_PLUGINS_DIR/?.lua;;"
    export LUA_CPATH="$OPENRESTY_PREFIX/lualib/?.so;;"

    cd "$backend_dir"
    "$NGINX_BIN" -p "$backend_dir" -c nginx.conf
    local ret=$?
    cd "$PROJECT_ROOT"
    return $ret
}

# 停止 nginx
stop_nginx() {
    local pid_file=$(get_nginx_pid_file)

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_info "停止 Nginx (PID: $pid)..."
            "$NGINX_BIN" -s stop 2>/dev/null || kill "$pid" 2>/dev/null || true
            sleep 1
            return 0
        else
            log_warn "Nginx 未运行 (PID 文件过期)"
            rm -f "$pid_file"
        fi
    fi
    return 1
}

# ============================================================
# 负载均衡实例相关函数
# ============================================================

# 检查负载均衡 nginx 是否运行
is_loadbalance_running() {
    local pid_file="$LOADBALANCE_DIR/logs/nginx.pid"
    [[ -f "$pid_file" ]] || return 1
    local pid=$(cat "$pid_file" 2>/dev/null)
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# 启动负载均衡 nginx
start_nginx_loadbalance() {
    local conf_file="$LOADBALANCE_DIR/nginx.conf"

    [[ ! -f "$conf_file" ]] && log_error "负载均衡配置文件不存在" && return 1

    mkdir -p "$LOADBALANCE_DIR/logs" "$LOADBALANCE_DIR/conf.d" "$LOADBALANCE_DIR/deploy_history"
    chmod -R 777 "$LOADBALANCE_DIR/logs" "$LOADBALANCE_DIR/deploy_history" 2>/dev/null || true

    export LUA_PATH="$OPENRESTY_PREFIX/lualib/?.lua;$LUA_PLUGINS_DIR/?.lua;;"
    export LUA_CPATH="$OPENRESTY_PREFIX/lualib/?.so;;"

    log_info "验证负载均衡配置..."
    "$NGINX_BIN" -t -p "$LOADBALANCE_DIR" -c nginx.conf 2>&1 || { log_error "配置验证失败"; return 1; }

    log_info "启动负载均衡 OpenResty..."
    "$NGINX_BIN" -p "$LOADBALANCE_DIR" -c nginx.conf && log_success "负载均衡已启动 (端口: 9000)"
}

# 停止负载均衡 nginx
stop_nginx_loadbalance() {
    local pid_file="$LOADBALANCE_DIR/logs/nginx.pid"

    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log_info "停止负载均衡 (PID: $pid)..."
            kill -QUIT "$pid" 2>/dev/null || true
            sleep 1
            return 0
        else
            log_warn "负载均衡未运行"
            rm -f "$pid_file"
        fi
    fi
    return 1
}

# ============================================================
# 前端相关函数
# ============================================================

FRONTEND_DIR="$WEB_ADMIN_DIR/frontend"

# 检查前端依赖
check_frontend_deps() {
    [[ -d "$FRONTEND_DIR" ]] || return 1
    [[ -f "$FRONTEND_DIR/package.json" ]] || return 1
    bash -l -c "command -v npm &>/dev/null" || return 1
}

# 构建前端静态文件
build_frontend() {
    local dist_dir="$FRONTEND_DIR/dist"
    local need_build=false

    if [[ ! -d "$dist_dir" ]]; then
        need_build=true
    else
        local src_newer=$(find "$FRONTEND_DIR/src" -newer "$dist_dir" 2>/dev/null | head -1)
        [[ -n "$src_newer" ]] && need_build=true
    fi

    if [[ "$need_build" == "true" ]]; then
        check_frontend_deps || { log_warn "跳过前端构建"; return 0; }

        [[ ! -d "$FRONTEND_DIR/node_modules" ]] && { cd "$FRONTEND_DIR"; npm install --silent 2>/dev/null; cd "$PROJECT_ROOT"; }

        log_info "构建前端静态文件..."
        cd "$FRONTEND_DIR"
        npm run build --silent 2>/dev/null
        cd "$PROJECT_ROOT"
        log_success "前端构建完成"
    fi
}