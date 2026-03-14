#!/usr/bin/env bash
#
# 公共函数和常量
#

# 路径 (scripts 在 tools 目录下)
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TOOLS_DIR/.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"
BUILD_DIR="$PROJECT_ROOT/build"
PREFIX="$BUILD_DIR/openresty"
NGINX_BIN="$PREFIX/nginx/sbin/nginx"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 执行命令，失败时打印错误并退出
run() {
    "$@"
    local ret=$?
    if [[ $ret -ne 0 ]]; then
        log_error "命令失败 (exit $ret): $*"
        exit $ret
    fi
}

# 获取并行数
get_jobs() {
    echo "${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
}