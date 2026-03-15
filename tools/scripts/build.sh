#!/usr/bin/env bash
#
# 构建 OpenResty
#
# 用法: ./build.sh [-jN] [--debug] [--verbose]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================================
# 参数解析
# ============================================================

JOBS=$(get_jobs)
DEBUG=false
VERBOSE=false

for arg in "$@"; do
    case $arg in
        -j*)       JOBS="${arg#-j}" ;;
        --debug)   DEBUG=true ;;
        --verbose) VERBOSE=true ;;
        --help|-h) echo "用法: $0 [-jN] [--debug] [--verbose]"; exit 0 ;;
    esac
done

# ============================================================
# 配置选项
# ============================================================

OPTS=(
    --prefix="$OPENRESTY_PREFIX"
    --with-http_ssl_module
    --with-http_v2_module
    --with-http_v3_module
    --with-stream
    --with-stream_ssl_module
    --with-stream_ssl_preread_module
    --with-http_realip_module
    --with-http_gzip_static_module
    --with-http_stub_status_module
    --with-http_auth_request_module
)

[[ "$DEBUG" == "true" ]] && OPTS+=(--with-debug)

# ============================================================
# 构建函数
# ============================================================

# 计时
step_start() {
    STEP_NAME=$1
    STEP_START=$(date +%s.%N)
    log_step "$STEP_NAME 开始..."
}

step_end() {
    local end duration
    end=$(date +%s.%N)
    duration=$(echo "$end - $STEP_START" | bc 2>/dev/null || echo "0")
    log_success "$STEP_NAME 完成 (${duration}s)"
}

# 静默执行
run_quiet() {
    local log_file
    log_file=$(mktemp)
    trap "rm -f '$log_file'" RETURN

    if [[ "$VERBOSE" == "true" ]]; then
        "$@"
        return $?
    fi

    "$@" >> "$log_file" 2>&1
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        cat "$log_file"
        log_error "命令失败 (exit $ret): $*"
    fi
    return $ret
}

# ============================================================
# 构建流程
# ============================================================

cd "$OPENRESTY_SRC" || { log_error "源码目录不存在: $OPENRESTY_SRC"; exit 1; }

# 配置
step_start "配置"
chmod +x ./configure 2>/dev/null || true
run_quiet ./configure "${OPTS[@]}" || exit 1
step_end

# 编译
step_start "编译"
log_info "并行数: $JOBS"
run_quiet make -j"$JOBS" || exit 1
step_end

# 安装
step_start "安装"
chmod 755 "$OPENRESTY_SRC/build/install" 2>/dev/null || true
run_quiet make install || exit 1
step_end

# 验证
step_start "验证"
if [[ -x "$NGINX_BIN" ]]; then
    log_info "二进制: $NGINX_BIN"
    step_end
else
    log_error "构建产物不存在: $NGINX_BIN"
    exit 1
fi

# 版本信息
log_info "构建完成，版本信息:"
"$NGINX_BIN" -V 2>&1