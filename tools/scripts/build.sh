#!/usr/bin/env bash
#
# 构建 OpenResty
#
# 用法: ./scripts/build.sh [-jN] [--debug]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 参数
JOBS=$(get_jobs)
DEBUG=false

for arg in "$@"; do
    case $arg in
        -j*)       JOBS="${arg#-j}" ;;
        --debug)   DEBUG=true ;;
        --help|-h) echo "用法: $0 [-jN] [--debug]"; exit 0 ;;
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
    --without-http_rewrite_module
)

[[ "$DEBUG" == "true" ]] && OPTS+=(--with-debug)

# 构建
cd "$SRC_DIR" || { log_error "源码目录不存在: $SRC_DIR"; exit 1; }

log_info "配置..."
run ./configure "${OPTS[@]}"

log_info "编译 (并行: $JOBS)..."
run make -j"$JOBS"

log_info "安装..."
chmod 755 "$SRC_DIR/build/install"
run make install

log_success "完成: $NGINX_BIN"
run "$NGINX_BIN" -V