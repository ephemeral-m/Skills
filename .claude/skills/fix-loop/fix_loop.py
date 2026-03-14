#!/usr/bin/env python3
"""
自动修复循环核心逻辑
"""

import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List, Optional

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent.parent.parent
CONFIG_PATH = PROJECT_ROOT / "dev.yaml"
STATE_DIR = PROJECT_ROOT / ".dev" / "state"
ANALYZER_DIR = PROJECT_ROOT / ".dev" / "analyzer"


def load_config() -> Dict[str, Any]:
    """加载配置"""
    import yaml
    with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def save_iteration_state(iteration: int, command: str, result: Dict[str, Any],
                          analysis: Dict[str, Any], fixes_applied: List[str]):
    """保存迭代状态"""
    state = {
        "iteration": iteration,
        "command": command,
        "timestamp": datetime.now().isoformat(),
        "result": result,
        "analysis": analysis,
        "fixes_applied": fixes_applied
    }

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    history_file = STATE_DIR / "fix_history.json"

    history = []
    if history_file.exists():
        with open(history_file, 'r', encoding='utf-8') as f:
            history = json.load(f)

    history.append(state)

    with open(history_file, 'w', encoding='utf-8') as f:
        json.dump(history, f, indent=2, ensure_ascii=False, default=str)


def get_last_iteration() -> Optional[Dict[str, Any]]:
    """获取上一次迭代状态"""
    history_file = STATE_DIR / "fix_history.json"
    if not history_file.exists():
        return None

    with open(history_file, 'r', encoding='utf-8') as f:
        history = json.load(f)

    return history[-1] if history else None


def format_errors_for_ai(analysis: Dict[str, Any]) -> str:
    """格式化错误信息供 AI 分析"""
    if analysis.get("success"):
        return ""

    lines = ["## 错误分析结果\n"]

    errors = analysis.get("errors", [])
    if not errors:
        return "执行失败，但未检测到明确的错误模式。"

    lines.append(f"检测到 {len(errors)} 个错误:\n")

    for i, err in enumerate(errors, 1):
        lines.append(f"### 错误 {i}")
        lines.append(f"- 类型: {err.get('type', 'unknown')}")
        if err.get('file'):
            lines.append(f"- 文件: {err['file']}")
            if err.get('line'):
                lines.append(f"- 行号: {err['line']}")
        lines.append(f"- 消息: {err.get('match', err.get('raw', 'N/A'))}")
        if err.get('suggestion'):
            lines.append(f"- 建议: {err['suggestion']}")
        lines.append("")

    return "\n".join(lines)


def main():
    """主入口"""
    import argparse

    parser = argparse.ArgumentParser(description='自动修复循环')
    parser.add_argument('command', help='要执行的命令')
    parser.add_argument('--max-iterations', type=int, default=5, help='最大循环次数')
    parser.add_argument('--module', help='指定模块')

    args = parser.parse_args()

    # 输出状态文件路径，供 Claude 读取
    state_info = {
        "config_path": str(CONFIG_PATH),
        "state_dir": str(STATE_DIR),
        "analyzer_dir": str(ANALYZER_DIR),
        "command": args.command,
        "max_iterations": args.max_iterations,
        "module": args.module
    }

    print(json.dumps(state_info, indent=2))


if __name__ == '__main__':
    main()