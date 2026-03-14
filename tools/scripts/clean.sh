#!/usr/bin/env bash
#
# 清理构建产物
#
# 用法: ./scripts/clean.sh [--all]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

DEEP=false

for arg in "$@"; do
    case $arg in
        --all|-a)  DEEP=true ;;
        --help|-h) echo "用法: $0 [--all]"; exit 0 ;;
    esac
done

log_info "清理..."

rm -rf "$SRC_DIR/bundle/nginx-"*/objs
rm -f "$SRC_DIR/Makefile"
find "$SRC_DIR/bundle" \( -name "*.o" -o -name "*.lo" \) -delete 2>/dev/null || true
find "$SRC_DIR/bundle" -name ".libs" -type d -exec rm -rf {} + 2>/dev/null || true

if [[ "$DEEP" == "true" ]]; then
    run rm -rf "$BUILD_DIR"
fi

log_success "完成"