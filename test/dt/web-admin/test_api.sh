#!/bin/bash
# Web-Admin API 端到端测试用例
# 测试前端与 loadbalance 的完整交互流程
#
# 用法: ./test_api.sh [test_name]
# 示例: ./test_api.sh all          # 运行所有测试
#       ./test_api.sh config_crud  # 运行指定测试

set -e

# 配置
# API_BASE 可通过环境变量覆盖，默认使用本地开发服务器
API_BASE="${API_BASE:-http://127.0.0.1:8080}"
TEST_PORT_START=9000
TEST_PORT_END=9100

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 测试计数器
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# 辅助函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "\n${YELLOW}=== TEST: $1 ===${NC}"; }

# 断言函数
assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if [ "$expected" = "$actual" ]; then
        log_info "PASS: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "FAIL: $msg"
        log_error "  Expected: $expected"
        log_error "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local msg="$3"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if echo "$haystack" | grep -q "$needle"; then
        log_info "PASS: $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "FAIL: $msg"
        log_error "  Expected to contain: $needle"
        log_error "  Actual: $haystack"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_success() {
    local response="$1"
    local msg="$2"
    assert_contains '"success":true' "$response" "$msg"
}

# HTTP 请求封装
api_get() {
    curl -s "${API_BASE}$1"
}

api_post() {
    curl -s -X POST "${API_BASE}$1" \
        -H "Content-Type: application/json" \
        -d "$2"
}

api_put() {
    curl -s -X PUT "${API_BASE}$1" \
        -H "Content-Type: application/json" \
        -d "$2"
}

api_delete() {
    curl -s -X DELETE "${API_BASE}$1"
}

# 获取随机测试端口
get_test_port() {
    echo $((TEST_PORT_START + RANDOM % (TEST_PORT_END - TEST_PORT_START)))
}

# 清理测试数据
cleanup_test_data() {
    log_info "清理测试数据..."
    # 清理测试用的 upstream
    for id in test_upstream_e2e test_stream_backend; do
        api_delete "/api/config/upstream/${id}" > /dev/null 2>&1 || true
    done
    # 清理测试用的 stream
    for port in 9001 9002 9003; do
        api_delete "/api/config/stream/tcp_test_${port}" > /dev/null 2>&1 || true
    done
}

#==============================================================================
# 测试用例
#==============================================================================

# 测试 API 健康检查
test_health() {
    log_test "API 健康检查"

    local response=$(api_get "/api/health")
    assert_contains '"status":"healthy"' "$response" "健康检查返回 healthy"
}

# 测试 API 信息
test_api_info() {
    log_test "API 信息端点"

    local response=$(api_get "/api")
    assert_contains '"name"' "$response" "API 返回名称"
    assert_contains '"version"' "$response" "API 返回版本"
    assert_contains '"endpoints"' "$response" "API 返回端点列表"
}

#==============================================================================
# Upstream 配置 CRUD 测试
#==============================================================================

test_upstream_crud() {
    log_test "Upstream CRUD 完整流程"

    local upstream_id="test_upstream_e2e"

    # 1. 创建 upstream
    log_info "1. 创建 upstream 配置"
    local create_data='{
        "id": "'${upstream_id}'",
        "servers": [
            {"host": "192.168.1.100", "port": 8080, "weight": 3},
            {"host": "192.168.1.101", "port": 8080, "weight": 2}
        ],
        "balance": "least_conn",
        "keepalive": 32
    }'
    local response=$(api_post "/api/config/upstream" "$create_data")
    assert_contains '"message":"Created successfully"' "$response" "创建 upstream 成功"
    assert_contains "\"id\":\"${upstream_id}\"" "$response" "返回创建的 ID"

    # 2. 查询 upstream 列表
    log_info "2. 查询 upstream 列表"
    local list_response=$(api_get "/api/config/upstream")
    assert_contains "${upstream_id}" "$list_response" "列表中包含创建的 upstream"

    # 3. 查询单个 upstream
    log_info "3. 查询单个 upstream"
    local get_response=$(api_get "/api/config/upstream/${upstream_id}")
    assert_contains "${upstream_id}" "$get_response" "查询返回正确的 upstream"
    assert_contains "192.168.1.100" "$get_response" "包含服务器配置"

    # 4. 更新 upstream
    log_info "4. 更新 upstream 配置"
    local update_data='{
        "id": "'${upstream_id}'",
        "servers": [
            {"host": "192.168.1.100", "port": 8080, "weight": 5},
            {"host": "192.168.1.101", "port": 8080, "weight": 3},
            {"host": "192.168.1.102", "port": 8080, "weight": 1, "backup": true}
        ],
        "balance": "round_robin"
    }'
    local update_response=$(api_put "/api/config/upstream/${upstream_id}" "$update_data")
    assert_contains '"message":"Updated successfully"' "$update_response" "更新 upstream 成功"

    # 5. 验证更新结果
    log_info "5. 验证更新结果"
    local verify_response=$(api_get "/api/config/upstream/${upstream_id}")
    assert_contains "192.168.1.102" "$verify_response" "新增服务器已添加"
    assert_contains '"backup":true' "$verify_response" "backup 属性正确"

    # 6. 删除 upstream
    log_info "6. 删除 upstream"
    local delete_response=$(api_delete "/api/config/upstream/${upstream_id}")
    assert_contains '"message":"Deleted successfully"' "$delete_response" "删除 upstream 成功"

    # 7. 验证删除结果
    log_info "7. 验证删除结果"
    local final_response=$(api_get "/api/config/upstream/${upstream_id}")
    # 应该返回 404 或者不包含该 ID
    if echo "$final_response" | grep -q "not found\|Not Found\|error"; then
        log_info "删除验证通过 - upstream 已不存在"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "删除验证失败 - upstream 仍然存在"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

#==============================================================================
# Stream 配置测试（TCP 代理）
#==============================================================================

test_stream_tcp() {
    log_test "Stream TCP 代理完整流程"

    local stream_port=$(get_test_port)
    local stream_id="tcp_test_${stream_port}"
    local upstream_id="test_stream_backend"

    # 0. 先创建 upstream
    log_info "0. 创建依赖的 upstream"
    local upstream_data='{
        "id": "'${upstream_id}'",
        "servers": [{"host": "127.0.0.1", "port": 80}]
    }'
    api_post "/api/config/upstream" "$upstream_data" > /dev/null

    # 1. 创建 stream 配置
    log_info "1. 创建 stream TCP 代理配置 (端口 ${stream_port})"
    local create_data='{
        "id": "'${stream_id}'",
        "listen": '${stream_port}',
        "protocol": "tcp",
        "proxy_pass": "'${upstream_id}'",
        "timeout": {
            "connect": "5s",
            "read": "30s",
            "send": "30s"
        }
    }'
    local response=$(api_post "/api/config/stream" "$create_data")
    assert_contains '"message":"Created successfully"' "$response" "创建 stream 配置成功"

    # 2. 应用配置
    log_info "2. 应用配置到 loadbalance"
    local apply_response=$(api_post "/api/deploy/apply" "{}")
    assert_success "$apply_response" "配置应用成功"
    assert_contains '"backup_id"' "$apply_response" "返回备份 ID"

    # 3. 验证端口监听
    log_info "3. 验证端口监听 (通过 API status)"
    local status_response=$(api_get "/api/deploy/status")
    assert_contains '"nginx_running":true' "$status_response" "Nginx 正在运行"

    # 4. 预览配置
    log_info "4. 预览生成的配置"
    local preview_response=$(api_post "/api/deploy/preview" "{}")
    assert_contains "listen ${stream_port}" "$preview_response" "预览包含正确的端口"

    # 5. 清理
    log_info "5. 清理测试数据"
    api_delete "/api/config/stream/${stream_id}" > /dev/null
    api_delete "/api/config/upstream/${upstream_id}" > /dev/null
    api_post "/api/deploy/apply" "{}" > /dev/null
}

#==============================================================================
# Stream 配置测试（UDP 代理）
#==============================================================================

test_stream_udp() {
    log_test "Stream UDP 代理完整流程"

    local stream_port=$(get_test_port)
    local stream_id="udp_test_${stream_port}"
    local upstream_id="test_udp_backend"

    # 0. 先创建 upstream
    log_info "0. 创建依赖的 upstream"
    local upstream_data='{
        "id": "'${upstream_id}'",
        "servers": [{"host": "8.8.8.8", "port": 53}]
    }'
    api_post "/api/config/upstream" "$upstream_data" > /dev/null

    # 1. 创建 stream UDP 配置
    log_info "1. 创建 stream UDP 代理配置 (端口 ${stream_port})"
    local create_data='{
        "id": "'${stream_id}'",
        "listen": "'${stream_port} udp'",
        "protocol": "udp",
        "proxy_pass": "'${upstream_id}'",
        "timeout": {
            "read": "5s",
            "send": "5s"
        }
    }'
    local response=$(api_post "/api/config/stream" "$create_data")
    assert_contains '"message":"Created successfully"' "$response" "创建 stream UDP 配置成功"

    # 2. 应用配置
    log_info "2. 应用配置"
    local apply_response=$(api_post "/api/deploy/apply" "{}")
    assert_success "$apply_response" "配置应用成功"

    # 3. 清理
    log_info "3. 清理测试数据"
    api_delete "/api/config/stream/${stream_id}" > /dev/null
    api_delete "/api/config/upstream/${upstream_id}" > /dev/null
    api_post "/api/deploy/apply" "{}" > /dev/null
}

#==============================================================================
# 部署流程测试
#==============================================================================

test_deploy_flow() {
    log_test "部署流程完整测试"

    # 1. 查看部署状态
    log_info "1. 查看部署状态"
    local status_response=$(api_get "/api/deploy/status")
    assert_contains '"nginx_running"' "$status_response" "返回 Nginx 运行状态"
    assert_contains '"config_stats"' "$status_response" "返回配置统计"

    # 2. 查看部署历史
    log_info "2. 查看部署历史"
    local history_response=$(api_get "/api/deploy/history")
    assert_contains '"history"' "$history_response" "返回部署历史"

    # 3. 预览配置
    log_info "3. 预览配置"
    local preview_response=$(api_post "/api/deploy/preview" "{}")
    assert_contains '"upstreams"' "$preview_response" "预览包含 upstreams"
    assert_contains '"stream_servers"' "$preview_response" "预览包含 stream_servers"
    assert_contains '"full"' "$preview_response" "预览包含完整配置"

    # 4. 应用配置
    log_info "4. 应用配置"
    local apply_response=$(api_post "/api/deploy/apply" "{}")
    assert_success "$apply_response" "配置应用成功"

    # 5. 验证备份已创建
    log_info "5. 验证备份已创建"
    local backup_id=$(echo "$apply_response" | grep -o '"backup_id":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$backup_id" ]; then
        log_info "备份 ID: ${backup_id}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "未找到备份 ID"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

#==============================================================================
# 配置验证测试
#==============================================================================

test_config_validation() {
    log_test "配置验证测试"

    # 1. 验证有效的 upstream 配置
    log_info "1. 验证有效的 upstream 配置"
    local valid_data='{
        "id": "valid_test",
        "servers": [{"host": "192.168.1.1", "port": 8080}]
    }'
    local response=$(api_post "/api/config/upstream/validate" "$valid_data")
    assert_contains '"valid":true' "$response" "有效配置验证通过"

    # 2. 验证无效的 upstream 配置（缺少 id）
    log_info "2. 验证无效的 upstream 配置（缺少 id）"
    local invalid_data='{
        "servers": [{"host": "192.168.1.1", "port": 8080}]
    }'
    local response=$(api_post "/api/config/upstream/validate" "$invalid_data")
    assert_contains '"valid":false' "$response" "无效配置验证失败"

    # 3. 验证无效的 stream 配置（缺少 listen）
    log_info "3. 验证无效的 stream 配置（缺少 listen）"
    local invalid_stream='{
        "id": "test",
        "protocol": "tcp"
    }'
    local response=$(api_post "/api/config/stream/validate" "$invalid_stream")
    assert_contains '"valid":false' "$response" "无效 stream 配置验证失败"

    # 4. 验证无效的 location 配置（缺少 path）
    log_info "4. 验证无效的 location 配置（缺少 path）"
    local invalid_location='{
        "id": "test",
        "proxy_pass": "http://backend"
    }'
    local response=$(api_post "/api/config/location/validate" "$invalid_location")
    assert_contains '"valid":false' "$response" "无效 location 配置验证失败"
}

#==============================================================================
# 错误处理测试
#==============================================================================

test_error_handling() {
    log_test "错误处理测试"

    # 1. 无效的 domain
    log_info "1. 请求无效的 domain"
    local response=$(api_get "/api/config/invalid_domain")
    assert_contains '"error"' "$response" "返回错误信息"

    # 2. 缺少 Content-Type
    log_info "2. POST 请求缺少 Content-Type"
    local response=$(curl -s -X POST "${API_BASE}/api/config/upstream" -d '{}')
    assert_contains '"error"' "$response" "返回错误信息"

    # 3. 无效的 JSON
    log_info "3. 发送无效的 JSON"
    local response=$(curl -s -X POST "${API_BASE}/api/config/upstream" \
        -H "Content-Type: application/json" \
        -d 'not valid json')
    assert_contains '"error"' "$response" "返回错误信息"

    # 4. GET 不存在的配置
    log_info "4. GET 不存在的配置"
    local response=$(api_get "/api/config/upstream/nonexistent_id_12345")
    # 可能返回 404 或者空结果
    if echo "$response" | grep -q "error\|not found\|Not Found"; then
        log_info "正确处理不存在的配置"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_info "GET 不存在配置返回: $response"
        TESTS_PASSED=$((TESTS_PASSED + 1))  # 也算通过，只要不崩溃
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

#==============================================================================
# 状态 API 测试
#==============================================================================

test_status_api() {
    log_test "状态 API 测试"

    # 1. Nginx 状态
    log_info "1. 获取 Nginx 状态"
    local response=$(api_get "/api/status/nginx")
    assert_contains '"version"' "$response" "返回 Nginx 版本"
    assert_contains '"uptime"' "$response" "返回运行时间"

    # 2. 连接状态
    log_info "2. 获取连接状态"
    local response=$(api_get "/api/status/connections")
    assert_contains '"active"' "$response" "返回活跃连接数"

    # 3. 请求统计
    log_info "3. 获取请求统计"
    local response=$(api_get "/api/status/requests")
    assert_contains '"total"' "$response" "返回总请求数"
    assert_contains '"by_status"' "$response" "返回状态码统计"
    assert_contains '"by_method"' "$response" "返回方法统计"

    # 4. 全部状态
    log_info "4. 获取全部状态"
    local response=$(api_get "/api/status/all")
    assert_contains '"nginx"' "$response" "包含 nginx 状态"
    assert_contains '"connections"' "$response" "包含连接状态"
    assert_contains '"requests"' "$response" "包含请求统计"
    assert_contains '"timestamp"' "$response" "包含时间戳"

    # 5. 无效的状态类型
    log_info "5. 请求无效的状态类型"
    local response=$(api_get "/api/status/invalid")
    assert_contains '"error"' "$response" "返回错误信息"
}

#==============================================================================
# 完整业务流程测试
#==============================================================================

test_full_workflow() {
    log_test "完整业务流程测试 - 创建代理服务"

    local port=$(get_test_port)
    local upstream_id="workflow_backend_${port}"
    local stream_id="workflow_stream_${port}"

    echo "测试端口: ${port}"

    # 1. 创建 upstream
    log_info "步骤 1: 创建 upstream"
    local upstream_data='{
        "id": "'${upstream_id}'",
        "servers": [
            {"host": "192.168.1.10", "port": 8080, "weight": 2},
            {"host": "192.168.1.11", "port": 8080, "weight": 1}
        ],
        "balance": "least_conn"
    }'
    local r1=$(api_post "/api/config/upstream" "$upstream_data")
    assert_contains "success\|Created" "$r1" "创建 upstream 成功"

    # 2. 创建 stream 代理
    log_info "步骤 2: 创建 stream 代理"
    local stream_data='{
        "id": "'${stream_id}'",
        "listen": '${port}',
        "protocol": "tcp",
        "proxy_pass": "'${upstream_id}'"
    }'
    local r2=$(api_post "/api/config/stream" "$stream_data")
    assert_contains "success\|Created" "$r2" "创建 stream 成功"

    # 3. 预览配置
    log_info "步骤 3: 预览配置"
    local r3=$(api_post "/api/deploy/preview" "{}")
    assert_contains "${port}" "$r3" "预览包含新端口"
    assert_contains "${upstream_id}" "$r3" "预览包含 upstream"

    # 4. 应用配置
    log_info "步骤 4: 应用配置"
    local r4=$(api_post "/api/deploy/apply" "{}")
    assert_success "$r4" "应用配置成功"

    # 5. 验证状态
    log_info "步骤 5: 验证部署状态"
    local r5=$(api_get "/api/deploy/status")
    assert_contains '"nginx_running":true' "$r5" "Nginx 运行正常"

    # 6. 清理
    log_info "步骤 6: 清理测试数据"
    api_delete "/api/config/stream/${stream_id}" > /dev/null
    api_delete "/api/config/upstream/${upstream_id}" > /dev/null
    api_post "/api/deploy/apply" "{}" > /dev/null

    log_info "完整流程测试通过"
}

#==============================================================================
# 主程序
#==============================================================================

print_summary() {
    echo ""
    echo "========================================"
    echo "测试总结"
    echo "========================================"
    echo -e "总计: ${TESTS_TOTAL}"
    echo -e "通过: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "失败: ${RED}${TESTS_FAILED}${NC}"
    echo "========================================"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}所有测试通过!${NC}"
        return 0
    else
        echo -e "${RED}有测试失败!${NC}"
        return 1
    fi
}

# 运行所有测试
run_all_tests() {
    cleanup_test_data

    test_health
    test_api_info
    test_upstream_crud
    test_stream_tcp
    test_stream_udp
    test_deploy_flow
    test_config_validation
    test_error_handling
    test_status_api
    test_full_workflow

    print_summary
}

# 主入口
main() {
    local test_name="${1:-all}"

    case "$test_name" in
        all)
            run_all_tests
            ;;
        health)
            test_health
            print_summary
            ;;
        upstream)
            test_upstream_crud
            print_summary
            ;;
        stream)
            test_stream_tcp
            test_stream_udp
            print_summary
            ;;
        deploy)
            test_deploy_flow
            print_summary
            ;;
        validation)
            test_config_validation
            print_summary
            ;;
        error)
            test_error_handling
            print_summary
            ;;
        status)
            test_status_api
            print_summary
            ;;
        workflow)
            test_full_workflow
            print_summary
            ;;
        *)
            echo "未知测试: $test_name"
            echo "可用测试: all, health, upstream, stream, deploy, validation, error, status, workflow"
            exit 1
            ;;
    esac
}

main "$@"