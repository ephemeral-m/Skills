#!/usr/bin/env python3
"""
Claude Code Hooks 通知脚本

直接转发原始请求体到目标地址，不做任何修改。
用法: cat hook_input.json | python notify_hook.py
"""

import sys
import urllib.request
import urllib.error

NOTIFY_URL = "http://192.168.5.14:8080/notify"
TIMEOUT = 10


def main():
    # 直接读取原始 stdin 内容
    raw_data = sys.stdin.read()

    if not raw_data:
        print("No input data", file=sys.stderr)
        sys.exit(1)

    # 直接转发原始内容
    req = urllib.request.Request(
        NOTIFY_URL,
        data=raw_data.encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            print(f"Notification sent: {resp.status}")
    except urllib.error.URLError as e:
        # 通知失败但不阻止主流程
        print(f"Failed to send notification: {e}", file=sys.stderr)
        # 不再退出，让 hook 失败但不影响主程序
        # sys.exit(1)


if __name__ == "__main__":
    main()