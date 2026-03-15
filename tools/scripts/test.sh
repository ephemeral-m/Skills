#!/usr/bin/env bash
#
# 运行测试
#
# 用法: ./scripts/test.sh [--config|--lua|--dt [file]]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

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

# 测试 Nginx 配置
test_config() {
    if [[ ! -x "$NGINX_BIN" ]]; then
        echo "[ERROR] 未构建，请先运行: ./scripts/build.sh"
        exit 1
    fi
    echo "[配置] 开始..."
    "$NGINX_BIN" -t 2>&1
    echo "[配置] 完成"
}

# 测试 Lua 语法
test_lua() {
    echo "[Lua] 开始语法检查..."
    local n=0 failed=0
    while IFS= read -r -d '' f; do
        if luac -p "$f" 2>&1; then
            ((n++))
        else
            echo "[ERROR] 语法错误: $f"
            ((failed++))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.lua" -type f \
             ! -path "*/bundle/*" ! -path "*/build/*" -print0 2>/dev/null)

    if [[ $failed -gt 0 ]]; then
        echo "[ERROR] 失败 $failed 个文件"
        exit 1
    fi
    echo "[Lua] 完成 - 检查 $n 个文件"
}

# 测试 Test::Nginx 用例
test_dt() {
    local test_nginx_dir="$PROJECT_ROOT/test/test_nginx"
    local dt_dir="$PROJECT_ROOT/test/dt"

    if [[ ! -x "$NGINX_BIN" ]]; then
        echo "[ERROR] 未构建，请先运行: ./scripts/build.sh"
        exit 1
    fi

    if [[ ! -d "$test_nginx_dir" ]]; then
        echo "[ERROR] Test::Nginx 目录不存在: $test_nginx_dir"
        exit 1
    fi

    # 设置环境变量
    export TEST_NGINX_BINARY="$NGINX_BIN"

    echo "[DT] 开始运行 Test::Nginx 测试..."
    cd "$test_nginx_dir" || exit 1

    local test_files=()
    if [[ -n "$DT_FILE" ]]; then
        # 支持多种格式:
        # 1. 完整路径: phone_range_router/basic.t
        # 2. 插件/文件: phone_range_router/basic
        # 3. 旧格式兼容: phone_range_router_basic.t 或 phone_range_router_basic

        local found=false

        # 尝试直接匹配
        if [[ -f "$dt_dir/$DT_FILE" ]]; then
            test_files=("$dt_dir/$DT_FILE")
            found=true
        # 尝试添加 .t 后缀
        elif [[ -f "$dt_dir/${DT_FILE}.t" ]]; then
            test_files=("$dt_dir/${DT_FILE}.t")
            found=true
        # 尝试在子目录中查找
        elif [[ -f "$dt_dir/${DT_FILE%%/*}/${DT_FILE#*/}.t" ]]; then
            test_files=("$dt_dir/${DT_FILE%%/*}/${DT_FILE#*/}.t")
            found=true
        fi

        if [[ "$found" != "true" ]]; then
            echo "[ERROR] 测试文件不存在: $DT_FILE"
            echo "[INFO] 可用测试:"
            find "$dt_dir" -name "*.t" -type f | sed 's|'"$dt_dir"'/||' | sort
            exit 1
        fi
    else
        # 运行所有测试（递归查找子目录）
        while IFS= read -r -d '' f; do
            test_files+=("$f")
        done < <(find "$dt_dir" -name "*.t" -type f -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo "[WARN] 未找到测试文件"
        exit 0
    fi

    local total=0 passed=0 failed=0
    for f in "${test_files[@]}"; do
        # 显示相对路径更清晰
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
    echo "[DT] 完成 - 总计: $total, 通过: $passed, 失败: $failed"

    if [[ $failed -gt 0 ]]; then
        exit 1
    fi
}

case "$MODE" in
    config) test_config ;;
    lua)    test_lua ;;
    dt)     test_dt ;;
    all)    test_lua && test_config && test_dt ;;
esac