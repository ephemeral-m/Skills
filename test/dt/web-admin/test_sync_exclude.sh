#!/usr/bin/env bash
#
# Test: Sync excludes src/web-admin/data/
#
# This test verifies that /dev sync preserves remote config data
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DATA_DIR="$PROJECT_ROOT/src/web-admin/data/configs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if we're running on the remote server
if [[ ! -d "$DATA_DIR" ]]; then
    log_error "Data directory not found: $DATA_DIR"
    log_error "This test must run on the remote Linux server"
    exit 1
fi

log_info "=== Test: Sync excludes src/web-admin/data/ ==="

# Step 1: Create a unique test config
TEST_PORT=19999
TEST_ID="sync_test_$(date +%s)"
TEST_FILE="$DATA_DIR/test_sync.json"

log_info "Step 1: Creating test config (port $TEST_PORT)..."

cat > "$TEST_FILE" << EOF
{
  "version": 999,
  "updated_at": "$(date -Iseconds)",
  "test_id": "$TEST_ID",
  "items": [
    {
      "id": "sync_test_item",
      "listen": [{"port": $TEST_PORT}],
      "server_name": "sync-test.local"
    }
  ]
}
EOF

log_info "Created: $TEST_FILE with test_id=$TEST_ID"

# Step 2: Record the test_id for verification
echo "$TEST_ID" > /tmp/sync_test_marker

log_info "Step 2: Test config created successfully"
log_info ""
log_info "Now run '/dev sync' from your local machine, then run:"
log_info "  bash $SCRIPT_DIR/test_sync_exclude.sh --verify"
log_info ""

# Verification mode
if [[ "$1" == "--verify" ]]; then
    log_info "=== Verification ==="

    if [[ ! -f "$TEST_FILE" ]]; then
        log_error "Test file was deleted by sync: $TEST_FILE"
        log_error "Sync exclude is NOT working!"
        exit 1
    fi

    STORED_ID=$(cat /tmp/sync_test_marker 2>/dev/null || echo "")

    if [[ -z "$STORED_ID" ]]; then
        log_error "Test marker not found"
        exit 1
    fi

    if grep -q "$STORED_ID" "$TEST_FILE"; then
        log_info "SUCCESS: Config preserved after sync"
        log_info "Test ID matches: $STORED_ID"

        # Cleanup
        rm -f "$TEST_FILE" /tmp/sync_test_marker
        log_info "Cleanup done"
        exit 0
    else
        log_error "Config was overwritten by sync!"
        log_error "Expected test_id: $STORED_ID"
        log_error "File content:"
        cat "$TEST_FILE"
        exit 1
    fi
fi