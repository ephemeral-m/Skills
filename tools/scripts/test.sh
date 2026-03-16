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

    # 优先使用构建的 LuaJIT，否则尝试系统 luajit 或 luac
    local lua_checker=""
    if [[ -x "$LUAJIT_BIN" ]]; then
        lua_checker="$LUAJIT_BIN"
    elif command -v luajit &>/dev/null; then
        lua_checker="luajit"
    elif command -v luac &>/dev/null; then
        lua_checker="luac -p"
    else
        log_error "未找到 Lua 语法检查器 (luajit 或 luac)"
        exit 1
    fi

    local n=0 failed=0
    while IFS= read -r -d '' f; do
        # LuaJIT 使用 -bl 检查语法（编译字节码但不执行）
        # luac 使用 -p 参数
        if [[ "$lua_checker" == *"luajit"* ]]; then
            if "$lua_checker" -bl "$f" >/dev/null 2>&1; then
                n=$((n + 1))
            else
                log_error "语法错误: $f"
                # 显示详细错误
                "$lua_checker" -bl "$f" 2>&1 | head -5
                failed=$((failed + 1))
            fi
        else
            if $lua_checker "$f" 2>&1; then
                n=$((n + 1))
            else
                log_error "语法错误: $f"
                failed=$((failed + 1))
            fi
        fi
    done < <(find "$PROJECT_ROOT" -name "*.lua" -type f \
             ! -path "*/bundle/*" ! -path "*/build/*" -print0 2>/dev/null)

    if [[ $failed -gt 0 ]]; then
        log_error "失败 $failed 个文件"
        exit 1
    fi
    log_success "检查 $n 个文件通过"
}

# 执行单个 .t 测试文件 (Test::Nginx)
run_t_test() {
    local f="$1"
    local test_nginx_dir="$2"
    local rel_path="${f#$dt_dir/}"

    echo ""
    echo "--- [Test::Nginx] $rel_path ---"

    local start_time=$(date +%s%N 2>/dev/null || date +%s)
    local output
    output=$(prove -I"$test_nginx_dir/lib" "$f" 2>&1) || true
    local end_time=$(date +%s%N 2>/dev/null || date +%s)
    local duration=$(( (end_time - start_time) / 1000000 ))  # ms

    echo "$output"

    if echo "$output" | grep -q "Result: PASS"; then
        echo "[PASS] $rel_path (${duration}ms)"
        return 0
    else
        echo "[FAIL] $rel_path"
        return 1
    fi
}

# 执行单个 .sh 测试脚本
run_sh_test() {
    local f="$1"
    local rel_path="${f#$dt_dir/}"

    echo ""
    echo "--- [Shell] $rel_path ---"

    local start_time=$(date +%s%N 2>/dev/null || date +%s)
    local output
    output=$(bash "$f" 2>&1) || true
    local end_time=$(date +%s%N 2>/dev/null || date +%s)
    local duration=$(( (end_time - start_time) / 1000000 ))  # ms

    echo "$output"

    # Shell 脚本成功返回 0，失败返回非 0
    if [[ $? -eq 0 ]] || echo "$output" | grep -qE "(PASS|成功|passed)"; then
        echo "[PASS] $rel_path (${duration}ms)"
        return 0
    else
        echo "[FAIL] $rel_path"
        return 1
    fi
}

# 测试 Test::Nginx 用例和 Shell 测试脚本
test_dt() {
    local test_nginx_dir="$PROJECT_ROOT/test/test_nginx"
    local dt_dir="$PROJECT_ROOT/test/dt"

    check_openresty_built || exit 1

    if [[ ! -d "$dt_dir" ]]; then
        log_warn "测试用例目录不存在: $dt_dir"
        exit 0
    fi

    export TEST_NGINX_BINARY="$NGINX_BIN"

    log_step "运行测试..."
    cd "$PROJECT_ROOT" || exit 1

    local t_files=()  # Test::Nginx 测试
    local sh_files=() # Shell 测试脚本

    if [[ -n "$DT_FILE" ]]; then
        # 支持多种格式:
        # phone_range_router_basic.t
        # phone_range_router/basic
        # web-admin/test_api.sh
        if [[ -f "$dt_dir/$DT_FILE" ]]; then
            if [[ "$DT_FILE" == *.t ]]; then
                t_files=("$dt_dir/$DT_FILE")
            elif [[ "$DT_FILE" == *.sh ]]; then
                sh_files=("$dt_dir/$DT_FILE")
            fi
        elif [[ -f "$dt_dir/${DT_FILE}.t" ]]; then
            t_files=("$dt_dir/${DT_FILE}.t")
        elif [[ -f "$dt_dir/${DT_FILE}.sh" ]]; then
            sh_files=("$dt_dir/${DT_FILE}.sh")
        elif [[ -f "$dt_dir/${DT_FILE%%/*}/${DT_FILE#*/}.t" ]]; then
            t_files=("$dt_dir/${DT_FILE%%/*}/${DT_FILE#*/}.t")
        elif [[ -d "$dt_dir/$DT_FILE" ]]; then
            # 如果是目录，执行目录下所有测试
            while IFS= read -r -d '' f; do
                t_files+=("$f")
            done < <(find "$dt_dir/$DT_FILE" -name "*.t" -type f -print0 2>/dev/null | sort -z)
            while IFS= read -r -d '' f; do
                sh_files+=("$f")
            done < <(find "$dt_dir/$DT_FILE" -name "*.sh" -type f -print0 2>/dev/null | sort -z)
        else
            log_error "测试文件不存在: $DT_FILE"
            log_info "可用测试:"
            find "$dt_dir" \( -name "*.t" -o -name "*.sh" \) -type f | sed 's|'"$dt_dir"'/||' | sort
            exit 1
        fi
    else
        # 执行 test/dt/ 下所有测试用例（递归查找所有子目录）
        log_info "查找所有测试用例..."

        # Test::Nginx 测试 (.t 文件)
        while IFS= read -r -d '' f; do
            t_files+=("$f")
        done < <(find "$dt_dir" -name "*.t" -type f -print0 2>/dev/null | sort -z)

        # Shell 测试脚本 (.sh 文件)
        while IFS= read -r -d '' f; do
            sh_files+=("$f")
        done < <(find "$dt_dir" -name "*.sh" -type f -print0 2>/dev/null | sort -z)
    fi

    local total_t=${#t_files[@]}
    local total_sh=${#sh_files[@]}
    local total=$((total_t + total_sh))

    if [[ $total -eq 0 ]]; then
        log_warn "未找到测试文件"
        exit 0
    fi

    log_info "发现 $total 个测试文件 (Test::Nginx: $total_t, Shell: $total_sh)"

    # 结果文件
    local result_file="$TOOLS_DIR/results/test-dt.json"
    mkdir -p "$(dirname "$result_file")"

    local passed=0 failed=0
    local failed_tests=()

    # 执行 Test::Nginx 测试
    if [[ $total_t -gt 0 ]]; then
        log_info "运行 Test::Nginx 测试..."
        cd "$test_nginx_dir" || exit 1
        for f in "${t_files[@]}"; do
            if run_t_test "$f" "$test_nginx_dir"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
                failed_tests+=("${f#$dt_dir/}")
            fi
        done
        cd "$PROJECT_ROOT"
    fi

    # 执行 Shell 测试脚本
    if [[ $total_sh -gt 0 ]]; then
        log_info "运行 Shell 测试脚本..."
        for f in "${sh_files[@]}"; do
            if run_sh_test "$f"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
                failed_tests+=("${f#$dt_dir/}")
            fi
        done
    fi

    echo ""
    log_info "=========================================="
    log_info "测试结果: 总计=$total, 通过=$passed, 失败=$failed"
    log_info "=========================================="

    # 保存结果到 JSON 文件
    local failed_json="[]"
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        failed_json="["
        for i in "${!failed_tests[@]}"; do
            [[ $i -gt 0 ]] && failed_json+=","
            failed_json+="\"${failed_tests[$i]}\""
        done
        failed_json+="]"
    fi

    cat > "$result_file" << EOF
{
  "timestamp": "$(date -Iseconds 2>/dev/null || date)",
  "total": $total,
  "passed": $passed,
  "failed": $failed,
  "test_nginx_count": $total_t,
  "shell_count": $total_sh,
  "failed_tests": $failed_json
}
EOF
    log_info "结果已保存到: $result_file"

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