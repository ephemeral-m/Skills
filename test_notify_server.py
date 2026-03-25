#!/usr/bin/env python3
"""
简单的通知接收服务器
用于测试 Claude Code 的通知功能
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
from datetime import datetime


class NotificationHandler(BaseHTTPRequestHandler):
    """处理通知请求"""

    def do_POST(self):
        """处理 POST 请求"""
        if self.path == '/notify':
            # 读取请求体
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)

            try:
                # 解析 JSON
                data = json.loads(body.decode('utf-8'))

                # 打印通知
                print("\n" + "=" * 60)
                print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] 收到通知")
                print("=" * 60)
                print(f"事件类型: {data.get('event_type', 'N/A')}")
                print(f"标题: {data.get('title', 'N/A')}")
                print(f"消息: {data.get('message', 'N/A')}")
                print(f"时间戳: {data.get('timestamp', 'N/A')}")

                details = data.get('details', {})
                if details:
                    print("\n详细信息:")
                    for key, value in details.items():
                        print(f"  {key}: {value}")

                print("=" * 60 + "\n")

                # 返回成功响应
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ok"}).encode('utf-8'))

            except json.JSONDecodeError as e:
                print(f"JSON 解析错误: {e}")
                self.send_response(400)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        """禁用默认的日志输出"""
        pass


def main():
    """启动服务器"""
    host = '127.0.0.1'
    port = 8081

    server = HTTPServer((host, port), NotificationHandler)

    print(f"通知接收服务器已启动")
    print(f"监听地址: http://{host}:{port}")
    print(f"通知端点: http://{host}:{port}/notify")
    print("\n等待通知... (按 Ctrl+C 停止)\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\n服务器已停止")
        server.shutdown()


if __name__ == "__main__":
    main()