#!/usr/bin/env bash
#
# 运行测试
#
# 用法: ./test.sh [--config|--lua|--dt [file]]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 全局变量
DT_DIR="$PROJECT_ROOT/test/dt"
TEST_NGINX_DIR="$PROJECT_ROOT/test/test_nginx"

# 参数
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

test_config() {
    check_openresty_built || exit 1
    log_step "测试 Nginx 配置..."
    "$NGINX_BIN" -t 2>&1
    log_success "配置测试通过"
}

test_lua() {
    log_step "检查 Lua 语法..."

    local checker=""
    if [[ -x "$LUAJIT_BIN" ]]; then
        checker="$LUAJIT_BIN -bl"
    elif command -v luajit &>/dev/null; then
        checker="luajit -bl"
    elif command -v luac &>/dev/null; then
        checker="luac -p"
    else
        log_error "未找到 Lua 语法检查器"
        exit 1
    fi

    local n=0 failed=0
    while IFS= read -r -d '' f; do
        if $checker "$f" >/dev/null 2>&1; then
            n=$((n + 1))
        else
            log_error "语法错误: $f"
            $checker "$f" 2>&1 | head -3
            failed=$((failed + 1))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.lua" -type f \
             ! -path "*/bundle/*" ! -path "*/build/*" -print0 2>/dev/null)

    [[ $failed -gt 0 ]] && log_error "失败 $failed 个文件" && exit 1
    log_success "检查 $n 个文件通过"
}

run_single_test() {
    local f="$1" type="$2"
    local rel="${f#$DT_DIR/}"

    echo ""
    echo "--- [$type] $rel ---"

    local output
    if [[ "$type" == "Test::Nginx" ]]; then
        output=$(TEST_NGINX_BINARY="$NGINX_BIN" prove -I"$TEST_NGINX_DIR/lib" "$f" 2>&1) || true
        echo "$output"
        echo "$output" | grep -q "Result: PASS"
        return $?
    else
        output=$(bash "$f" 2>&1)
        local ret=$?
        echo "$output" | tail -10
        if [[ $ret -eq 0 ]]; then
            return 0
        fi
        echo "$output" | grep -qE "(PASS|成功)" && return 0 || return 1
    fi
}

test_dt() {
    check_openresty_built || exit 1

    [[ ! -d "$DT_DIR" ]] && log_warn "测试目录不存在" && exit 0

    export TEST_NGINX_BINARY="$NGINX_BIN"
    log_step "运行测试..."

    local t_files=() sh_files=()

    if [[ -n "$DT_FILE" ]]; then
        # 尝试各种路径格式
        if [[ -f "$DT_DIR/$DT_FILE" ]]; then
            [[ "$DT_FILE" == *.t ]] && t_files+=("$DT_DIR/$DT_FILE") || sh_files+=("$DT_DIR/$DT_FILE")
        elif [[ -f "$DT_DIR/${DT_FILE}.t" ]]; then
            t_files+=("$DT_DIR/${DT_FILE}.t")
        elif [[ -f "$DT_DIR/${DT_FILE}.sh" ]]; then
            sh_files+=("$DT_DIR/${DT_FILE}.sh")
        elif [[ -d "$DT_DIR/$DT_FILE" ]]; then
            mapfile -d '' t_files < <(find "$DT_DIR/$DT_FILE" -name "*.t" -type f -print0 2>/dev/null | sort -z)
            mapfile -d '' sh_files < <(find "$DT_DIR/$DT_FILE" -name "*.sh" -type f -print0 2>/dev/null | sort -z)
        else
            log_error "测试文件不存在: $DT_FILE"
            find "$DT_DIR" \( -name "*.t" -o -name "*.sh" \) -type f | sed 's|'"$DT_DIR"'/||' | sort | head -20
            exit 1
        fi
    else
        log_info "查找所有测试用例..."
        mapfile -d '' t_files < <(find "$DT_DIR" -name "*.t" -type f -print0 2>/dev/null | sort -z)
        mapfile -d '' sh_files < <(find "$DT_DIR" -name "*.sh" -type f -print0 2>/dev/null | sort -z)
    fi

    local total=$((${#t_files[@]} + ${#sh_files[@]}))
    [[ $total -eq 0 ]] && log_warn "未找到测试文件" && exit 0

    log_info "发现 $total 个测试文件 (Test::Nginx: ${#t_files[@]}, Shell: ${#sh_files[@]})"

    local passed=0 failed=0
    declare -a failed_tests

    # 执行 Test::Nginx 测试
    if [[ ${#t_files[@]} -gt 0 ]]; then
        cd "$TEST_NGINX_DIR"
        for f in "${t_files[@]}"; do
            if run_single_test "$f" "Test::Nginx"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
                failed_tests+=("${f#$DT_DIR/}")
            fi
        done
        cd "$PROJECT_ROOT"
    fi

    # 执行 Shell 测试
    for f in "${sh_files[@]}"; do
        if run_single_test "$f" "Shell"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
            failed_tests+=("${f#$DT_DIR/}")
        fi
    done

    # 输出结果
    echo ""
    log_info "=========================================="
    log_info "测试结果: 总计=$total, 通过=$passed, 失败=$failed"
    log_info "=========================================="

    # 保存结果
    local result_file="$TOOLS_DIR/results/test-dt.json"
    mkdir -p "$(dirname "$result_file")"

    # 生成 JSON
    local failed_json="[]"
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        failed_json=$(printf '%s\n' "${failed_tests[@]}" | jq -R . | jq -s . 2>/dev/null || echo '[]')
    fi

    cat > "$result_file" << EOF
{
  "timestamp": "$(date -Iseconds 2>/dev/null || date)",
  "total": $total,
  "passed": $passed,
  "failed": $failed,
  "failed_tests": $failed_json
}
EOF

    if [[ $failed -gt 0 ]]; then
        log_error "失败的测试:"
        for t in "${failed_tests[@]}"; do
            log_error "  - $t"
        done
        exit 1
    fi

    log_success "所有测试通过!"
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