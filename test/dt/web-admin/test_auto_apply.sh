#!/usr/bin/env bash
#
# Test: Config auto-apply via web-admin API
#
# Tests:
# 1. POST /api/config/listeners-http creates config
# 2. Config is saved to listeners-http.json
# 3. POST /api/deploy/apply generates nginx config
# 4. loadbalance http.conf is updated
# 5. nginx reload succeeds and listens on new port
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

API_URL="http://127.0.0.1:8080"
TEST_PORT=19999
CONFIG_ID="auto-apply-test-$TEST_PORT"
DATA_DIR="/home/m30020610/Skills/src/web-admin/data/configs"
LB_DIR="/home/m30020610/Skills/src/loadbalance"

log_info "=== Test: Config auto-apply ==="

# Step 1: Add HTTP listener config via API
log_info "Step 1: Adding HTTP listener config (port $TEST_PORT)..."

RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"id\":\"$CONFIG_ID\",\"server_name\":\"auto-apply-test.local\",\"listen\":[{\"port\":$TEST_PORT,\"ssl\":false}],\"root\":\"/var/www/test\"}" \
    "$API_URL/api/config/listeners-http")

if echo "$RESPONSE" | grep -q '"success":true'; then
    log_info "Config added: $CONFIG_ID"
else
    log_error "Failed to add config: $RESPONSE"
    exit 1
fi

# Step 2: Verify listeners-http.json contains the port
log_info "Step 2: Checking listeners-http.json..."
if grep -q "\"port\":$TEST_PORT" "$DATA_DIR/listeners-http.json" || grep -q "\"port\": $TEST_PORT" "$DATA_DIR/listeners-http.json"; then
    log_info "listeners-http.json contains port $TEST_PORT"
else
    log_error "listeners-http.json missing port $TEST_PORT"
    cat "$DATA_DIR/listeners-http.json"
    exit 1
fi

# Step 3: Apply config via deploy API
log_info "Step 3: Applying config via /api/deploy/apply..."
APPLY_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" "$API_URL/api/deploy/apply")

if echo "$APPLY_RESPONSE" | grep -q '"success":true'; then
    log_info "Config applied successfully"
else
    log_error "Failed to apply config: $APPLY_RESPONSE"
    exit 1
fi

# Step 4: Verify loadbalance http.conf contains the port
log_info "Step 4: Checking loadbalance http.conf..."
if grep -q "listen $TEST_PORT" "$LB_DIR/conf.d/http.conf"; then
    log_info "http.conf contains 'listen $TEST_PORT'"
else
    log_error "http.conf missing 'listen $TEST_PORT'"
    cat "$LB_DIR/conf.d/http.conf"
    exit 1
fi

# Step 5: Verify nginx is listening on the port
log_info "Step 5: Checking nginx listening..."
sleep 1
if ss -tlnp 2>/dev/null | grep -q ":$TEST_PORT"; then
    log_info "nginx is listening on port $TEST_PORT"
else
    log_error "nginx NOT listening on port $TEST_PORT"
    ss -tlnp | grep nginx
    exit 1
fi

# Step 6: Cleanup - delete the test config
log_info "Step 6: Cleaning up..."
curl -s -X DELETE "$API_URL/api/config/listeners-http/$CONFIG_ID" > /dev/null
log_info "Config deleted from storage"

# Apply again to remove the config from nginx
curl -s -X POST -H "Content-Type: application/json" "$API_URL/api/deploy/apply" > /dev/null
log_info "Config removed from nginx"

# Verify cleanup
sleep 1
if ! grep -q "listen $TEST_PORT" "$LB_DIR/conf.d/http.conf" 2>/dev/null; then
    log_info "http.conf cleaned up"
else
    log_error "http.conf still contains port $TEST_PORT"
fi

log_info ""
log_info "=== All tests passed! ==="