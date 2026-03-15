#!/usr/bin/env bash
#
# 构建 OpenResty
#
# 用法: ./scripts/build.sh [-jN] [--debug] [--verbose]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 支持通过环境变量指定模块路径
if [[ -n "$MODULE_PATH" ]]; then
    SRC_DIR="$PROJECT_ROOT/$MODULE_PATH"
fi

# 参数
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

# 配置选项
OPTS=(
    --prefix="$PREFIX"
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

# 日志文件（用于失败时输出）
BUILD_LOG=$(mktemp)
trap "rm -f '$BUILD_LOG'" EXIT

# 计时函数
step_start() {
    STEP_NAME=$1
    STEP_START=$(date +%s.%N)
    echo "[$STEP_NAME] 开始..."
}

step_end() {
    local step_end=$(date +%s.%N)
    local duration=$(echo "$step_end - $STEP_START" | bc 2>/dev/null || echo "0")
    printf "[%s] 完成 (%.1fs)\n" "$STEP_NAME" "$duration"
}

# 静默执行函数：成功时静默，失败时输出日志
run_silent() {
    if [[ "$VERBOSE" == "true" ]]; then
        "$@"
        return $?
    fi
    "$@" >> "$BUILD_LOG" 2>&1
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        echo ""
        cat "$BUILD_LOG"
        echo "[ERROR] 命令失败 (exit $ret): $*"
    fi
    return $ret
}

# 构建
cd "$SRC_DIR" || { echo "[ERROR] 源码目录不存在: $SRC_DIR"; exit 1; }

# 配置阶段
step_start "配置"
chmod +x ./configure 2>/dev/null || true
run_silent ./configure "${OPTS[@]}" || exit 1
step_end

# 编译阶段
step_start "编译"
echo "  并行数: $JOBS"
run_silent make -j"$JOBS" || exit 1
step_end

# 安装阶段
step_start "安装"
chmod 755 "$SRC_DIR/build/install" 2>/dev/null || true
run_silent make install || exit 1
step_end

# 验证构建结果
step_start "验证"
if [[ -x "$NGINX_BIN" ]]; then
    echo "  二进制: $NGINX_BIN"
    step_end
else
    echo "[ERROR] 构建产物不存在: $NGINX_BIN"
    exit 1
fi

# 输出版本信息
"$NGINX_BIN" -V 2>&1