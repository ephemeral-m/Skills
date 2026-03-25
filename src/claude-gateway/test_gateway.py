#!/usr/bin/env python3
"""
Claude HTTP Gateway 测试套件

使用方式：
  # 先启动服务
  python claude-http.py &

  # 运行测试
  python test_gateway.py

  # 或指定测试项
  python test_gateway.py --test status
  python test_gateway.py --test message
  python test_gateway.py --test all
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from typing import Dict, Any, Tuple


# 配置
DEFAULT_URL = "http://127.0.0.1:9876"
BASE_URL = DEFAULT_URL
TIMEOUT = 90


def http_get(path: str) -> Tuple[Dict[str, Any], int]:
    """发送 GET 请求"""
    try:
        req = urllib.request.urlopen(f"{BASE_URL}{path}", timeout=TIMEOUT)
        return json.loads(req.read().decode('utf-8')), 200
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode('utf-8')), e.code
    except Exception as e:
        return {"error": str(e)}, 500


def http_post(path: str, data: Dict[str, Any]) -> Tuple[Dict[str, Any], int]:
    """发送 POST 请求"""
    try:
        body = json.dumps(data).encode('utf-8')
        req = urllib.request.Request(
            f"{BASE_URL}{path}",
            data=body,
            headers={'Content-Type': 'application/json'}
        )
        response = urllib.request.urlopen(req, timeout=TIMEOUT)
        return json.loads(response.read().decode('utf-8')), 200
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode('utf-8')), e.code
    except Exception as e:
        return {"error": str(e)}, 500


def print_result(name: str, success: bool, detail: str = ""):
    """打印测试结果"""
    status = "PASS" if success else "FAIL"
    print(f"  [{status}] {name}")
    if detail:
        print(f"        {detail}")


class TestSuite:
    """测试套件"""

    def __init__(self):
        self.passed = 0
        self.failed = 0

    def run_test(self, name: str, test_func) -> bool:
        """运行单个测试"""
        print(f"\n测试: {name}")
        print("-" * 40)
        try:
            success, detail = test_func()
            print_result(name, success, detail)
            if success:
                self.passed += 1
            else:
                self.failed += 1
            return success
        except Exception as e:
            print_result(name, False, str(e))
            self.failed += 1
            return False

    def summary(self):
        """输出测试汇总"""
        total = self.passed + self.failed
        print("\n" + "=" * 50)
        print(f"测试汇总: {self.passed}/{total} 通过")
        if self.failed > 0:
            print(f"失败: {self.failed}")
        print("=" * 50)
        return self.failed == 0


# ========== 测试用例 ==========

def test_status() -> Tuple[bool, str]:
    """测试 GET /status"""
    data, code = http_get("/status")

    if code != 200:
        return False, f"HTTP {code}: {data.get('error')}"

    required_fields = ["status", "status_text", "is_processing", "platform"]
    for field in required_fields:
        if field not in data:
            return False, f"缺少字段: {field}"

    valid_statuses = ["idle", "processing", "waiting_approval", "error"]
    if data["status"] not in valid_statuses:
        return False, f"无效状态: {data['status']}"

    return True, f"状态: {data['status_text']} ({data['status']})"


def test_message_success() -> Tuple[bool, str]:
    """测试 POST /message 正常请求"""
    data, code = http_post("/message", {"prompt": "说 测试成功", "timeout": 60})

    if code != 200:
        return False, f"HTTP {code}: {data.get('error')}"

    if data.get("status") != "success":
        return False, f"状态: {data.get('status')}, 错误: {data.get('error')}"

    if "response" not in data:
        return False, "缺少 response 字段"

    return True, f"响应时间: {data.get('duration', 0):.2f}s"


def test_message_empty_prompt() -> Tuple[bool, str]:
    """测试 POST /message 空 prompt"""
    data, code = http_post("/message", {"prompt": ""})

    if code != 400:
        return False, f"期望 400，实际 {code}"

    if "error" not in data:
        return False, "缺少错误信息"

    return True, f"正确返回 400: {data.get('error')}"


def test_message_invalid_json() -> Tuple[bool, str]:
    """测试 POST /message 无效 JSON"""
    try:
        body = b"not a json"
        req = urllib.request.Request(
            f"{BASE_URL}/message",
            data=body,
            headers={'Content-Type': 'application/json'}
        )
        response = urllib.request.urlopen(req, timeout=TIMEOUT)
        return False, "应该返回 400"
    except urllib.error.HTTPError as e:
        if e.code == 400:
            return True, "正确返回 400"
        return False, f"期望 400，实际 {e.code}"


def test_history() -> Tuple[bool, str]:
    """测试 GET /history"""
    data, code = http_get("/history")

    if code != 200:
        return False, f"HTTP {code}: {data.get('error')}"

    if "history" not in data or "count" not in data:
        return False, "缺少必要字段"

    if data["count"] != len(data["history"]):
        return False, "count 与 history 长度不匹配"

    return True, f"历史记录数: {data['count']}"


def test_pending() -> Tuple[bool, str]:
    """测试 GET /pending"""
    data, code = http_get("/pending")

    if code != 200:
        return False, f"HTTP {code}: {data.get('error')}"

    if "pending" not in data or "count" not in data:
        return False, "缺少必要字段"

    return True, f"待授权数: {data['count']}"


def test_404() -> Tuple[bool, str]:
    """测试未知路径"""
    data, code = http_get("/unknown")

    if code != 404:
        return False, f"期望 404，实际 {code}"

    return True, "正确返回 404"


def test_message_busy() -> Tuple[bool, str]:
    """测试并发请求处理"""
    import threading
    import time

    results = []

    def send_request():
        data, code = http_post("/message", {"prompt": "说 数字", "timeout": 60})
        results.append((data, code))

    # 发送两个并发请求
    threads = [threading.Thread(target=send_request) for _ in range(2)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    # 检查结果
    statuses = [r[0].get("status") for r in results]
    if "success" in statuses and "busy" in statuses:
        return True, "正确处理并发请求"
    elif statuses.count("success") == 2:
        return True, "两个请求都成功（串行处理）"
    else:
        return False, f"意外状态: {statuses}"


# ========== 主程序 ==========

def main():
    parser = argparse.ArgumentParser(description="Claude HTTP Gateway 测试")
    parser.add_argument("--test", "-t", default="all",
                        choices=["all", "status", "message", "history", "pending", "error", "concurrent"],
                        help="指定测试项 (default: all)")
    parser.add_argument("--url", default=DEFAULT_URL, help="服务地址")
    args = parser.parse_args()

    # 更新全局 BASE_URL
    global BASE_URL
    BASE_URL = args.url

    print("=" * 50)
    print("Claude HTTP Gateway 测试套件")
    print(f"服务地址: {BASE_URL}")
    print("=" * 50)

    suite = TestSuite()

    # 测试映射
    tests = {
        "status": ("状态查询", test_status),
        "message": ("消息发送", test_message_success),
        "history": ("历史记录", test_history),
        "pending": ("待授权列表", test_pending),
        "error": ("错误处理", [
            ("空 prompt", test_message_empty_prompt),
            ("无效 JSON", test_message_invalid_json),
            ("404 路径", test_404),
        ]),
        "concurrent": ("并发处理", test_message_busy),
    }

    if args.test == "all":
        # 运行所有测试
        suite.run_test("状态查询", test_status)
        suite.run_test("消息发送", test_message_success)
        suite.run_test("历史记录", test_history)
        suite.run_test("待授权列表", test_pending)
        suite.run_test("空 prompt", test_message_empty_prompt)
        suite.run_test("无效 JSON", test_message_invalid_json)
        suite.run_test("404 路径", test_404)
        suite.run_test("并发处理", test_message_busy)
    elif args.test == "error":
        # 只运行错误处理测试
        suite.run_test("空 prompt", test_message_empty_prompt)
        suite.run_test("无效 JSON", test_message_invalid_json)
        suite.run_test("404 路径", test_404)
    else:
        # 运行指定测试
        name, test = tests[args.test]
        if isinstance(test, list):
            for sub_name, sub_test in test:
                suite.run_test(sub_name, sub_test)
        else:
            suite.run_test(name, test)

    # 输出汇总
    success = suite.summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()