#!/usr/bin/env bash
# Dev CLI 入口脚本
# 用法: ./dev <command> [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_PY="$SCRIPT_DIR/dev"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 需要 Python 3"
    exit 1
fi

# 检查 PyYAML
if ! python3 -c "import yaml" 2>/dev/null; then
    echo "正在安装依赖: pyyaml"
    pip install pyyaml -q
fi

# 执行命令
python3 "$DEV_PY" "$@"