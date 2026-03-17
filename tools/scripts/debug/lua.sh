#!/usr/bin/env bash
#
# Lua 调试脚本
#
# 用法: lua.sh <action> [args]
#   errors    - 查看最近 Lua 错误
#   modules   - 查看已加载模块
#   eval      - 执行 Lua 代码片段
#   dict      - 查看共享字典内容
#

set -e

# ============================================================
# 配置
# ============================================================
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TOOLS_DIR/.." && pwd)"

# OpenResty 路径
BUILD_DIR="$PROJECT_ROOT/build"
OPENRESTY_PREFIX="$BUILD_DIR/openresty"
NGINX_BIN="$OPENRESTY_PREFIX/nginx/sbin/nginx"
RESTY_BIN="$OPENRESTY_PREFIX/bin/resty"
LUAJIT_BIN="$OPENRESTY_PREFIX/luajit/bin/luajit"

# 负载均衡实例目录
LOADBALANCE_DIR="$PROJECT_ROOT/src/loadbalance"
PID_FILE="$LOADBALANCE_DIR/logs/nginx.pid"
LOG_DIR="$LOADBALANCE_DIR/logs"
ERROR_LOG="$LOG_DIR/error.log"

# Lua 路径
LUA_PLUGINS_DIR="$PROJECT_ROOT/src/lua-plugins"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# 函数
# ============================================================

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 获取 nginx PID
get_nginx_pid() {
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE" 2>/dev/null
    fi
}

# 检查进程是否运行
is_running() {
    local pid=$1
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# ============================================================
# 命令实现
# ============================================================

# 查看 Lua 错误
cmd_errors() {
    if [[ ! -f "$ERROR_LOG" ]]; then
        log_warn "错误日志不存在: $ERROR_LOG"
        return 1
    fi

    echo -e "${CYAN}=== 最近 Lua 错误 ===${NC}"
    echo ""

    # 搜索 Lua 相关错误
    grep -i "lua\|error" "$ERROR_LOG" 2>/dev/null | tail -30 | while read -r line; do
        # 高亮错误级别
        if echo "$line" | grep -qi "error"; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -qi "warn"; then
            echo -e "${YELLOW}$line${NC}"
        else
            echo "$line"
        fi
    done

    echo ""
    echo -e "${BLUE}统计:${NC}"
    echo "  Lua 错误: $(grep -c "lua.*error" "$ERROR_LOG" 2>/dev/null || echo 0)"
    echo "  Lua 警告: $(grep -c "lua.*warn" "$ERROR_LOG" 2>/dev/null || echo 0)"
    echo "  总 Lua 日志: $(grep -c "lua" "$ERROR_LOG" 2>/dev/null || echo 0)"
}

# 查看已加载模块
cmd_modules() {
    local pid=$(get_nginx_pid)

    if ! is_running "$pid"; then
        log_error "Nginx 未运行"
        return 1
    fi

    echo -e "${CYAN}=== 已加载 Lua 模块 ===${NC}"
    echo ""

    # 通过 nginx -s reload 获取模块列表是不现实的
    # 这里列出预期的模块
    echo -e "${BLUE}>>> Lua 插件目录${NC}"
    if [[ -d "$LUA_PLUGINS_DIR" ]]; then
        find "$LUA_PLUGINS_DIR" -name "*.lua" -type f 2>/dev/null | sort | while read -r f; do
            local rel_path="${f#$LUA_PLUGINS_DIR/}"
            local module_name="${rel_path%.lua}"
            module_name="${module_name//\//.}"
            echo "  $module_name"
        done
    else
        echo "  目录不存在: $LUA_PLUGINS_DIR"
    fi
    echo ""

    # OpenResty 内置模块
    echo -e "${BLUE}>>> OpenResty 内置模块${NC}"
    local lualib_dir="$OPENRESTY_PREFIX/lualib"
    if [[ -d "$lualib_dir" ]]; then
        echo "  ngx.* - Nginx Lua API"
        echo "  ngx.ctx - 请求上下文"
        echo "  ngx.shared.* - 共享字典"
        echo ""
        echo "  常用模块:"
        find "$lualib_dir/resty" -name "*.lua" -type f 2>/dev/null | head -20 | while read -r f; do
            local name="${f#$lualib_dir/resty/}"
            name="${name%.lua}"
            echo "  resty.$name"
        done
    fi
    echo ""

    # 运行时检查
    if command -v "$LUAJIT_BIN" &>/dev/null; then
        echo -e "${BLUE}>>> LuaJIT 版本${NC}"
        "$LUAJIT_BIN" -v 2>/dev/null || echo "  无法获取版本"
    fi
}

# 执行 Lua 代码片段
cmd_eval() {
    local code=$1

    if [[ -z "$code" ]]; then
        log_error "请提供 Lua 代码"
        echo "用法: lua.sh eval 'print(ngx.now())'"
        return 1
    fi

    echo -e "${CYAN}=== 执行 Lua 代码 ===${NC}"
    echo "代码: $code"
    echo ""

    # 设置环境
    export LUA_PATH="$OPENRESTY_PREFIX/lualib/?.lua;$LUA_PLUGINS_DIR/?.lua;;"
    export LUA_CPATH="$OPENRESTY_PREFIX/lualib/?.so;;"

    # 使用 resty 执行
    if [[ -x "$RESTY_BIN" ]]; then
        echo -e "${BLUE}>>> 输出${NC}"
        echo "$code" | "$RESTY_BIN" - 2>&1
    elif [[ -x "$LUAJIT_BIN" ]]; then
        echo -e "${BLUE}>>> 输出 (LuaJIT 模式)${NC}"
        echo "$code" | "$LUAJIT_BIN" - 2>&1
    else
        log_error "resty 和 luajit 都不可用"
        return 1
    fi

    echo ""
    log_info "执行完成"
}

# 查看共享字典
cmd_dict() {
    local dict_name=$1

    if [[ -z "$dict_name" ]]; then
        log_error "请指定共享字典名称"
        echo "用法: lua.sh dict <name>"
        return 1
    fi

    local pid=$(get_nginx_pid)

    if ! is_running "$pid"; then
        log_error "Nginx 未运行，无法访问共享字典"
        return 1
    fi

    echo -e "${CYAN}=== 共享字典: $dict_name ===${NC}"
    echo ""

    # 通过 Lua 代码获取字典内容
    local code="
local dict = ngx.shared.$dict_name
if not dict then
    print('ERROR: 共享字典不存在: $dict_name')
    os.exit(1)
end

print('字典名称: $dict_name')
print('容量: ' .. (dict:capacity and dict:capacity() or 'N/A') .. ' bytes')
print('空闲空间: ' .. (dict:free_space and dict:free_space() or 'N/A') .. ' bytes')
print('')

local keys = dict:get_keys(100)
if not keys or #keys == 0 then
    print('字典为空')
else
    print('键值对 (' .. #keys .. ' 个):')
    for i, key in ipairs(keys) do
        local value, err = dict:get(key)
        if value then
            local vtype = type(value)
            if vtype == 'string' and #value > 100 then
                value = string.sub(value, 1, 100) .. '...'
            end
            print(string.format('  [%s] = %s (%s)', key, tostring(value), vtype))
        else
            print(string.format('  [%s] = ERROR: %s', key, tostring(err)))
        end
    end
end
"

    export LUA_PATH="$OPENRESTY_PREFIX/lualib/?.lua;$LUA_PLUGINS_DIR/?.lua;;"
    export LUA_CPATH="$OPENRESTY_PREFIX/lualib/?.so;;"

    if [[ -x "$RESTY_BIN" ]]; then
        echo "$code" | "$RESTY_BIN" - 2>&1
    else
        log_error "resty 不可用"
        return 1
    fi
}

# ============================================================
# 主逻辑
# ============================================================

ACTION=${1:-help}

case $ACTION in
    errors)
        cmd_errors
        ;;
    modules)
        cmd_modules
        ;;
    eval)
        cmd_eval "${2:-}"
        ;;
    dict)
        cmd_dict "${2:-}"
        ;;
    help|*)
        echo "用法: lua.sh <errors|modules|eval|dict>"
        echo ""
        echo "命令说明:"
        echo "  errors    - 查看最近 Lua 错误"
        echo "  modules   - 查看已加载模块"
        echo "  eval      - 执行 Lua 代码片段"
        echo "  dict      - 查看共享字典内容"
        echo ""
        echo "示例:"
        echo "  lua.sh errors"
        echo "  lua.sh eval 'print(ngx.now())'"
        echo "  lua.sh dict cache"
        ;;
esac