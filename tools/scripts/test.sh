#!/usr/bin/env bash
#
# 运行测试
#
# 用法: ./test.sh [--config|--lua|--dt [file]]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ============================================================
# 参数解析
# ============================================================

MODE="all"
DT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --config|-c) MODE="config"; shift ;;
        --lua|-l)    MODE="lua"; shift ;;
        --dt|-d)     MODE="dt"; shift; DT_FILE="$1"; shift ;;
        --help|-h)   echo "用法: $0 [--config|--lua|--dt [file]]"; exit 0 ;;
        *)           shift ;;
    esac
done

# ============================================================
# 测试函数
# ============================================================

# 测试 Nginx 配置
test_config() {
    check_openresty_built || exit 1

    log_step "测试 Nginx 配置..."
    "$NGINX_BIN" -t 2>&1
    log_success "配置测试通过"
}

# 测试 Lua 语法
test_lua() {
    log_step "检查 Lua 语法..."

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
    log_success "检查 $n 个文件通过"
}

# 测试 Test::Nginx 用例
test_dt() {
    local test_nginx_dir="$PROJECT_ROOT/test/test_nginx"
    local dt_dir="$PROJECT_ROOT/test/dt"

    check_openresty_built || exit 1

    if [[ ! -d "$test_nginx_dir" ]]; then
        log_error "Test::Nginx 目录不存在: $test_nginx_dir"
        exit 1
    fi

    export TEST_NGINX_BINARY="$NGINX_BIN"

    log_step "运行 Test::Nginx 测试..."
    cd "$test_nginx_dir" || exit 1

    local test_files=()

    if [[ -n "$DT_FILE" ]]; then
        # 支持多种格式
        if [[ -f "$dt_dir/$DT_FILE" ]]; then
            test_files=("$dt_dir/$DT_FILE")
        elif [[ -f "$dt_dir/${DT_FILE}.t" ]]; then
            test_files=("$dt_dir/${DT_FILE}.t")
        elif [[ -f "$dt_dir/${DT_FILE%%/*}/${DT_FILE#*/}.t" ]]; then
            test_files=("$dt_dir/${DT_FILE%%/*}/${DT_FILE#*/}.t")
        else
            log_error "测试文件不存在: $DT_FILE"
            log_info "可用测试:"
            find "$dt_dir" -name "*.t" -type f | sed 's|'"$dt_dir"'/||' | sort
            exit 1
        fi
    else
        while IFS= read -r -d '' f; do
            test_files+=("$f")
        done < <(find "$dt_dir" -name "*.t" -type f -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "未找到测试文件"
        exit 0
    fi

    local total=0 passed=0 failed=0
    for f in "${test_files[@]}"; do
        local rel_path="${f#$dt_dir/}"
        echo ""
        echo "--- $rel_path ---"
        if prove -I"$test_nginx_dir/lib" "$f" 2>&1; then
            ((passed++))
        else
            ((failed++))
        fi
        ((total++))
    done

    echo ""
    log_info "总计: $total, 通过: $passed, 失败: $failed"

    [[ $failed -gt 0 ]] && exit 1
}

# ============================================================
# 执行测试
# ============================================================

case "$MODE" in
    config) test_config ;;
    lua)    test_lua ;;
    dt)     test_dt ;;
    all)    test_lua && test_config && test_dt ;;
esac