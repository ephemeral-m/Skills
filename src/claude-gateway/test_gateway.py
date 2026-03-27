#!/usr/bin/env python3
"""
Claude HTTP Gateway 测试脚本

使用方式：
  # 先启动服务
  python claude-http.py

  # 运行测试
  python test_gateway.py
"""

import json
import sys
import time
import urllib.request
import urllib.error

BASE_URL = "http://127.0.0.1:9876"
TIMEOUT = 120


def request(method: str, path: str, data: dict = None) -> tuple:
    """发送 HTTP 请求"""
    try:
        url = f"{BASE_URL}{path}"
        body = json.dumps(data).encode('utf-8') if data else None

        req = urllib.request.Request(
            url,
            data=body,
            method=method,
            headers={'Content-Type': 'application/json'} if body else {}
        )

        response = urllib.request.urlopen(req, timeout=TIMEOUT)
        return json.loads(response.read().decode('utf-8')), 200

    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode('utf-8')), e.code
    except Exception as e:
        return {"error": str(e)}, 500


def test_status():
    """测试状态接口"""
    print("\n[测试] GET /status")
    data, code = request("GET", "/status")

    if code != 200:
        print(f"  [FAIL] HTTP {code}")
        return False

    print(f"  [PASS] session: {data.get('session_id', 'N/A')[:8]}...")
    print(f"         work_dir: {data.get('work_dir')}")
    return True


def test_message():
    """测试消息接口"""
    print("\n[测试] POST /message")
    data, code = request("POST", "/message", {"prompt": "说 测试成功"})

    if code != 200:
        print(f"  [FAIL] HTTP {code}: {data.get('error')}")
        return False

    print(f"  [PASS] task_id: {data.get('task_id')}")
    print(f"         status: {data.get('status')}")
    print(f"         duration: {data.get('duration')}s")

    if data.get('response'):
        print(f"         response: {data['response'][:50]}...")

    return data.get('status') == 'completed'


def test_query_task():
    """测试查询任务"""
    print("\n[测试] GET /task/{id}")

    # 先创建任务
    create_data, _ = request("POST", "/message", {"prompt": "说 查询测试"})
    task_id = create_data.get('task_id')

    if not task_id:
        print("  [FAIL] 创建任务失败")
        return False

    # 查询任务
    data, code = request("GET", f"/task/{task_id}")

    if code != 200:
        print(f"  [FAIL] HTTP {code}")
        return False

    print(f"  [PASS] task_id: {task_id}")
    print(f"         status: {data.get('status')}")
    return True


def test_session_context():
    """测试会话上下文保持"""
    print("\n[测试] 会话上下文保持")

    # 第一条消息
    data1, _ = request("POST", "/message", {"prompt": "请记住数字 42，只回复'好的'"})
    if data1.get('status') != 'completed':
        print(f"  [FAIL] 第一条消息失败: {data1.get('error')}")
        return False

    print(f"  [INFO] 第一条消息完成")

    # 第二条消息验证上下文
    data2, _ = request("POST", "/message", {"prompt": "我让你记住什么数字？"})

    if data2.get('status') != 'completed':
        print(f"  [FAIL] 第二条消息失败: {data2.get('error')}")
        return False

    response = data2.get('response', '')
    if '42' in response:
        print(f"  [PASS] 上下文保持成功，响应包含 '42'")
        return True
    else:
        print(f"  [FAIL] 响应未包含 '42': {response[:100]}")
        return False


def main():
    print("=" * 50)
    print("Claude HTTP Gateway 测试")
    print(f"服务地址: {BASE_URL}")
    print("=" * 50)

    tests = [
        ("状态查询", test_status),
        ("发送消息", test_message),
        ("查询任务", test_query_task),
        ("上下文保持", test_session_context),
    ]

    passed = 0
    for name, func in tests:
        try:
            if func():
                passed += 1
        except Exception as e:
            print(f"  [FAIL] 异常: {e}")

    print("\n" + "=" * 50)
    print(f"测试结果: {passed}/{len(tests)} 通过")
    print("=" * 50)

    sys.exit(0 if passed == len(tests) else 1)


if __name__ == "__main__":
    main()