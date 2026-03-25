#!/usr/bin/env python3
"""
Claude HTTP Gateway 测试套件 (异步版)

使用方式：
  # 先启动服务
  python claude-http.py &

  # 运行测试
  python test_gateway.py
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from typing import Dict, Any, Tuple


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


def http_post(path: str, data: Dict[str, Any] = None) -> Tuple[Dict[str, Any], int]:
    """发送 POST 请求"""
    try:
        body = json.dumps(data or {}).encode('utf-8')
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


def wait_for_task(task_id: str, timeout: float = 60.0) -> Dict[str, Any]:
    """等待任务完成"""
    start = time.time()
    while time.time() - start < timeout:
        data, _ = http_get(f"/task/{task_id}")
        status = data.get("status", "")
        if status in ("completed", "failed", "cancelled"):
            return data
        time.sleep(0.5)
    return {"error": "等待超时", "status": "timeout"}


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

    required_fields = ["status", "work_dir", "platform"]
    for field in required_fields:
        if field not in data:
            return False, f"缺少字段: {field}"

    return True, f"工作目录: {data['work_dir']}"


def test_submit_task() -> Tuple[bool, str]:
    """测试 POST /message 提交任务"""
    data, code = http_post("/message", {"prompt": "说 测试成功", "timeout": 60})

    if code != 200:
        return False, f"HTTP {code}: {data.get('error')}"

    if "task_id" not in data:
        return False, "缺少 task_id"

    task_id = data["task_id"]
    return True, f"任务ID: {task_id[:8]}..."


def test_query_task() -> Tuple[bool, str]:
    """测试查询任务"""
    # 先提交任务
    submit_data, _ = http_post("/message", {"prompt": "说 查询测试", "timeout": 60})
    task_id = submit_data.get("task_id")

    if not task_id:
        return False, "提交任务失败"

    # 查询任务
    data, code = http_get(f"/task/{task_id}")

    if code != 200:
        return False, f"HTTP {code}"

    if "task_id" not in data or "status" not in data:
        return False, "缺少必要字段"

    return True, f"状态: {data['status']}"


def test_wait_for_completion() -> Tuple[bool, str]:
    """测试等待任务完成"""
    # 提交任务
    submit_data, _ = http_post("/message", {"prompt": "说 完成测试", "timeout": 60})
    task_id = submit_data.get("task_id")

    if not task_id:
        return False, "提交任务失败"

    # 等待完成
    result = wait_for_task(task_id, timeout=60)

    if result.get("status") != "completed":
        return False, f"任务状态: {result.get('status')}, 错误: {result.get('error')}"

    if "response" not in result:
        return False, "缺少响应内容"

    return True, f"耗时: {result.get('duration', 0)}s"


def test_cancel_pending_task() -> Tuple[bool, str]:
    """测试取消任务"""
    # 提交一个长任务
    submit_data, _ = http_post("/message", {"prompt": "请详细介绍一下Python的历史", "timeout": 300})
    task_id = submit_data.get("task_id")

    if not task_id:
        return False, "提交任务失败"

    # 立即取消
    time.sleep(0.2)  # 稍微等待一下
    data, code = http_post(f"/task/{task_id}/cancel")

    if code != 200:
        # 任务可能已经完成了
        task = http_get(f"/task/{task_id}")[0]
        if task.get("status") == "completed":
            return True, "任务已完成（太快了）"
        return False, f"HTTP {code}: {data}"

    return True, f"已取消: {task_id[:8]}..."


def test_history() -> Tuple[bool, str]:
    """测试 GET /history"""
    data, code = http_get("/history")

    if code != 200:
        return False, f"HTTP {code}: {data.get('error')}"

    if "history" not in data or "count" not in data:
        return False, "缺少必要字段"

    return True, f"历史记录数: {data['count']}"


def test_empty_prompt() -> Tuple[bool, str]:
    """测试空 prompt"""
    data, code = http_post("/message", {"prompt": ""})

    if code != 400:
        return False, f"期望 400，实际 {code}"

    return True, "正确返回 400"


def test_invalid_task_id() -> Tuple[bool, str]:
    """测试无效任务ID"""
    data, code = http_get("/task/invalid-task-id")

    if code != 404:
        return False, f"期望 404，实际 {code}"

    return True, "正确返回 404"


# ========== 主程序 ==========

def main():
    parser = argparse.ArgumentParser(description="Claude HTTP Gateway 测试 (异步版)")
    parser.add_argument("--test", "-t", default="all",
                        choices=["all", "status", "submit", "query", "wait", "cancel", "history", "error"],
                        help="指定测试项")
    parser.add_argument("--url", default=DEFAULT_URL, help="服务地址")
    args = parser.parse_args()

    global BASE_URL
    BASE_URL = args.url

    print("=" * 50)
    print("Claude HTTP Gateway 测试套件 (异步版)")
    print(f"服务地址: {BASE_URL}")
    print("=" * 50)

    suite = TestSuite()

    if args.test == "all":
        suite.run_test("状态查询", test_status)
        suite.run_test("提交任务", test_submit_task)
        suite.run_test("查询任务", test_query_task)
        suite.run_test("等待完成", test_wait_for_completion)
        suite.run_test("取消任务", test_cancel_pending_task)
        suite.run_test("历史记录", test_history)
        suite.run_test("空 prompt", test_empty_prompt)
        suite.run_test("无效任务ID", test_invalid_task_id)
    elif args.test == "error":
        suite.run_test("空 prompt", test_empty_prompt)
        suite.run_test("无效任务ID", test_invalid_task_id)
    elif args.test == "status":
        suite.run_test("状态查询", test_status)
    elif args.test == "submit":
        suite.run_test("提交任务", test_submit_task)
    elif args.test == "query":
        suite.run_test("查询任务", test_query_task)
    elif args.test == "wait":
        suite.run_test("等待完成", test_wait_for_completion)
    elif args.test == "cancel":
        suite.run_test("取消任务", test_cancel_pending_task)
    elif args.test == "history":
        suite.run_test("历史记录", test_history)

    success = suite.summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()