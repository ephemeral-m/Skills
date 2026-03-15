#!/usr/bin/env bash
#
# 公共函数和常量
# 所有脚本应该 source 此文件
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

# 构建目录
BUILD_DIR="$PROJECT_ROOT/build"
OPENRESTY_PREFIX="$BUILD_DIR/openresty"
NGINX_BIN="$OPENRESTY_PREFIX/nginx/sbin/nginx"

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

# 执行命令，失败时打印错误并退出
run() {
    "$@"
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        log_error "命令失败 (exit $ret): $*"
        exit $ret
    fi
}

# 静默执行：成功时无输出，失败时显示错误
run_silent() {
    local log_file
    log_file=$(mktemp)
    trap "rm -f '$log_file'" RETURN

    "$@" >> "$log_file" 2>&1
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        cat "$log_file"
        log_error "命令失败 (exit $ret): $*"
    fi
    return $ret
}

# 获取并行数
get_jobs() {
    echo "${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
}

# 检查命令是否存在
has_cmd() {
    command -v "$1" &>/dev/null
}

# 等待端口可用
wait_port() {
    local port=$1 timeout=${2:-10}
    local i=0
    while [[ $i -lt $timeout ]]; do
        if has_cmd nc && nc -z localhost "$port" 2>/dev/null; then
            return 0
        elif has_cmd ss && ss -tln | grep -q ":$port "; then
            return 0
        elif has_cmd netstat && netstat -tln 2>/dev/null | grep -q ":$port "; then
            return 0
        fi
        sleep 1
        ((i++))
    done
    return 1
}

# 检查进程是否运行
is_running() {
    local pid_file=$1
    [[ -f "$pid_file" ]] || return 1
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# 获取端口对应的主进程 PID (只返回第一个)
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
    return 0
}

# 获取 nginx PID 文件路径
get_nginx_pid_file() {
    # 优先使用 web-admin 的 pid 文件
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

    if [[ ! -f "$conf_file" ]]; then
        log_error "配置文件不存在: $conf_file"
        return 1
    fi

    # 创建必要目录
    mkdir -p "$BACKEND_LOGS_DIR"
    mkdir -p "$CONFIGS_DIR"
    mkdir -p "$CONFIGS_DIR/history"

    # 设置 Lua 模块路径
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
    local pid_file
    pid_file=$(get_nginx_pid_file)

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
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
# 前端相关函数
# ============================================================

FRONTEND_DIR="$WEB_ADMIN_DIR/frontend"
FRONTEND_PORT=5173

# 检查前端依赖
check_frontend_deps() {
    if [[ ! -d "$FRONTEND_DIR" ]]; then
        log_warn "前端目录不存在: $FRONTEND_DIR"
        return 1
    fi
    if [[ ! -f "$FRONTEND_DIR/package.json" ]]; then
        log_warn "package.json 不存在"
        return 1
    fi
    # 使用 bash -l 加载环境变量后检测 npm
    if ! bash -l -c "command -v npm &>/dev/null"; then
        log_warn "未安装 Node.js/npm"
        return 1
    fi
    return 0
}

# 安装前端依赖
install_frontend_deps() {
    if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
        log_info "安装前端依赖..."
        cd "$FRONTEND_DIR"
        npm install --silent 2>/dev/null
        cd "$PROJECT_ROOT"
    fi
}

# 启动前端开发服务器
start_frontend() {
    # 检查是否已运行
    local pid
    pid=$(get_pid_by_port "$FRONTEND_PORT")
    if [[ -n "$pid" ]]; then
        log_warn "前端服务已在运行 (PID: $pid)"
        return 0
    fi

    # 检查并安装依赖
    check_frontend_deps || return 1
    install_frontend_deps

    log_info "启动前端开发服务器..."
    cd "$FRONTEND_DIR"
    nohup npm run dev > /tmp/vite.log 2>&1 &
    cd "$PROJECT_ROOT"

    # 等待启动
    sleep 2
    if wait_port "$FRONTEND_PORT" 5; then
        log_success "前端服务已启动 (端口: $FRONTEND_PORT)"
        return 0
    else
        log_error "前端服务启动失败"
        return 1
    fi
}

# 停止前端开发服务器
stop_frontend() {
    local pids
    pids=$(pgrep -f "vite.*$FRONTEND_DIR" 2>/dev/null)

    if [[ -n "$pids" ]]; then
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                log_info "停止前端服务 (PID: $pid)..."
                kill "$pid" 2>/dev/null || true
            fi
        done
        log_success "前端服务已停止"
        return 0
    fi

    # 尝试通过端口查找
    local pid
    pid=$(get_pid_by_port "$FRONTEND_PORT")
    if [[ -n "$pid" ]]; then
        log_info "停止前端服务 (PID: $pid)..."
        kill "$pid" 2>/dev/null || true
        log_success "前端服务已停止"
        return 0
    fi

    return 1
}