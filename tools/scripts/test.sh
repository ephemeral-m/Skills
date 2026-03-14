#!/usr/bin/env bash
#
# 运行测试
#
# 用法: ./scripts/test.sh [--config|--lua]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

MODE="all"

for arg in "$@"; do
    case $arg in
        --config|-c) MODE="config" ;;
        --lua|-l)    MODE="lua" ;;
        --help|-h)   echo "用法: $0 [--config|--lua]"; exit 0 ;;
    esac
done

# 测试 Nginx 配置
test_config() {
    if [[ ! -x "$NGINX_BIN" ]]; then
        log_error "未构建，请先运行: ./scripts/build.sh"
        exit 1
    fi
    log_info "测试 Nginx 配置..."
    run "$NGINX_BIN" -t
    log_success "配置正确"
}

# 测试 Lua 语法
test_lua() {
    log_info "检查 Lua 语法..."
    local n=0 failed=0
    while IFS= read -r -d '' f; do
        if luac -p "$f" 2>&1; then
            ((n++))
        else
            log_error "语法错误: $f"
            ((failed++))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.lua" -type f \
             ! -path "*/bundle/*" ! -path "*/build/*" -print0 2>/dev/null)

    if [[ $failed -gt 0 ]]; then
        log_error "失败 $failed 个文件"
        exit 1
    fi
    log_success "检查 $n 个文件"
}

case "$MODE" in
    config) test_config ;;
    lua)    test_lua ;;
    all)    test_config && test_lua ;;
esac