#!/usr/bin/env python3
"""
简单的 HTTP 服务器，接收连接并打印收到的 HTTP 消息内容
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import sys


class RequestLoggerHandler(BaseHTTPRequestHandler):
    """自定义处理器，打印完整的 HTTP 请求"""

    def do_GET(self):
        self.handle_request('GET')

    def do_POST(self):
        self.handle_request('POST')

    def do_PUT(self):
        self.handle_request('PUT')

    def do_DELETE(self):
        self.handle_request('DELETE')

    def do_PATCH(self):
        self.handle_request('PATCH')

    def do_HEAD(self):
        self.handle_request('HEAD')

    def do_OPTIONS(self):
        self.handle_request('OPTIONS')

    def handle_request(self, method):
        """处理请求并打印详细信息"""
        # 打印请求行
        print("\n" + "=" * 80)
        print(f"[{self.log_date_time_string()}] 收到 {method} 请求")
        print("=" * 80)

        # 打印请求行
        print(f"\n请求行:")
        print(f"  方法: {method}")
        print(f"  路径: {self.path}")
        print(f"  版本: {self.request_version}")

        # 打印请求头
        print(f"\n请求头:")
        for header, value in self.headers.items():
            print(f"  {header}: {value}")

        # 打印请求体
        content_length = self.headers.get('Content-Length')
        if content_length:
            content_length = int(content_length)
            body = self.rfile.read(content_length)
            print(f"\n请求体 ({content_length} 字节):")
            print(f"  {body.decode('utf-8', errors='replace')}")
        else:
            print(f"\n请求体: 无")

        print("=" * 80 + "\n")

        # 发送响应
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(b'{"status": "ok", "message": "Request logged"}')

    def log_message(self, format, *args):
        """禁用默认的日志输出（我们已经在上面自定义了）"""
        pass


def run_server(host='0.0.0.0', port=8080):
    """启动 HTTP 服务器"""
    server_address = (host, port)
    httpd = HTTPServer(server_address, RequestLoggerHandler)

    print(f"HTTP 服务器启动在 http://{host}:{port}")
    print("按 Ctrl+C 停止服务器\n")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n服务器正在关闭...")
        httpd.shutdown()
        print("服务器已关闭")


if __name__ == '__main__':
    # 可以通过命令行参数指定端口
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run_server(port=port)