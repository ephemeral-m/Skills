#!/usr/bin/env bash
#
# 完整验证：构建 + 测试
#
# 用法: ./scripts/verify.sh [--quick]
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

QUICK=false

for arg in "$@"; do
    case $arg in
        --quick|-q) QUICK=true ;;
        --help|-h)  echo "用法: $0 [--quick]"; exit 0 ;;
    esac
done

if [[ "$QUICK" != "true" ]]; then
    run "$SCRIPT_DIR/build.sh"
fi
run "$SCRIPT_DIR/test.sh"

log_success "验证通过"