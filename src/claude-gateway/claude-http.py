#!/usr/bin/env python3
"""
Claude Code HTTP Gateway - 通过 HTTP 与 Claude Code 交互

使用方式：
  python claude-http.py [工作目录]

  # 使用默认工作目录（项目根目录）
  python claude-http.py

  # 指定工作目录
  python claude-http.py /path/to/project

功能：
  - HTTP API 接口（端口 9876）
    - POST /message  发送消息，同步等待响应
    - POST /approve  授权待审批的操作
    - GET  /history  获取对话历史
    - GET  /status   获取服务状态
    - GET  /pending  获取待授权的操作

技术说明：
  - Windows 上通过 Git Bash 管道模式调用 Claude CLI
  - 每次请求创建独立进程，保证稳定性
  - 支持 Claude Code 权限请求的授权流程
"""

import subprocess
import threading
import json
import sys
import time
import re
import shutil
import os
import platform
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional, List, Dict, Any
from datetime import datetime


def get_project_root() -> str:
    """获取项目根目录（从当前脚本位置向上推导）"""
    # 脚本位于 src/claude-gateway/claude-http.py
    # 项目根目录是脚本的上两级目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(script_dir))
    return project_root


def log(level: str, message: str):
    """统一日志输出"""
    timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
    try:
        print(f"[{timestamp}] [{level}] {message}")
    except UnicodeEncodeError:
        # Windows 控制台编码问题，尝试安全输出
        safe_msg = message.encode('utf-8', errors='replace').decode('utf-8')
        print(f"[{timestamp}] [{level}] {safe_msg}")


def _find_git_bash() -> Optional[str]:
    """查找 Git Bash 路径（Windows 需要）"""
    if platform.system() != 'Windows':
        return None

    possible_paths = [
        r"D:\Program Files (x86)\Git\bin\bash.exe",
        r"D:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files (x86)\Git\bin\bash.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Programs\Git\bin\bash.exe"),
        os.path.expandvars(r"%PROGRAMFILES%\Git\bin\bash.exe"),
        os.path.expandvars(r"%PROGRAMFILES(X86)%\Git\bin\bash.exe"),
    ]

    for path in possible_paths:
        if os.path.exists(path):
            return path

    result = shutil.which('bash.exe')
    if result:
        return result

    return None


class ClaudeGateway:
    """Claude Code 网关 - 一次一问模式"""

    # 状态常量
    STATUS_IDLE = "idle"                    # 空闲
    STATUS_PROCESSING = "processing"        # 处理中
    STATUS_WAITING_APPROVAL = "waiting_approval"  # 等待授权
    STATUS_ERROR = "error"                  # 错误

    def __init__(self, work_dir: Optional[str] = None):
        self.history: List[Dict[str, Any]] = []
        self.lock = threading.Lock()
        self.status = self.STATUS_IDLE
        self.git_bash: Optional[str] = None
        self.request_count = 0

        # 工作目录
        if work_dir:
            self.work_dir = os.path.abspath(work_dir)
        else:
            self.work_dir = get_project_root()

        # 验证工作目录
        if not os.path.isdir(self.work_dir):
            log("WARN", f"工作目录不存在: {self.work_dir}")

        # 当前处理信息
        self.current_prompt: Optional[str] = None
        self.current_start_time: Optional[float] = None

        # 待授权操作
        self.pending_approvals: List[Dict[str, Any]] = []
        self.approval_response: Optional[str] = None
        self.approval_event = threading.Event()

        # 初始化 Git Bash 路径
        if platform.system() == 'Windows':
            self.git_bash = _find_git_bash()
            if self.git_bash:
                log("INFO", f"Git Bash: {self.git_bash}")
            else:
                log("WARN", "未找到 Git Bash")

        log("INFO", f"工作目录: {self.work_dir}")

    def _parse_permission_request(self, output: str) -> Optional[Dict[str, Any]]:
        """解析 Claude 输出中的权限请求"""
        # Claude Code 权限请求模式
        patterns = [
            # 工具使用请求
            r'(?:Do you want to|Should I|Allow).*\?.*\[([Yy]/[Nn])\]',
            r'Permission required.*?(\S+)',
            r'Allow.*?tool.*?(\S+)',
            # Bash 命令执行
            r'Run command:\s*`([^`]+)`',
            # 文件操作
            r'(?:Read|Write|Edit|Delete)\s+(?:file|files?):\s*(\S+)',
        ]

        for pattern in patterns:
            match = re.search(pattern, output, re.IGNORECASE | re.DOTALL)
            if match:
                return {
                    "type": "permission",
                    "content": match.group(0),
                    "detail": match.group(1) if match.lastindex else None,
                    "timestamp": datetime.now().isoformat()
                }
        return None

    def send_message(self, prompt: str, timeout: float = 300.0) -> Dict[str, Any]:
        """发送消息并获取响应（一次一问模式）"""
        with self.lock:
            if self.status == self.STATUS_PROCESSING:
                return {"error": "正在处理上一条消息", "status": "busy"}
            if self.status == self.STATUS_WAITING_APPROVAL:
                return {"error": "有待授权的操作，请先处理", "status": "waiting_approval"}
            self.status = self.STATUS_PROCESSING
            self.current_prompt = prompt
            self.current_start_time = time.time()

        log("REQUEST", f"收到请求: {prompt[:100]}{'...' if len(prompt) > 100 else ''}")

        try:
            # 准备环境
            env = os.environ.copy()
            if self.git_bash:
                env['CLAUDE_CODE_GIT_BASH_PATH'] = self.git_bash.replace('/', '\\')

            # 构建命令
            if platform.system() == 'Windows' and self.git_bash:
                escaped_prompt = prompt.replace("'", "'\\''")
                cmd = [self.git_bash, '-c', f"echo '{escaped_prompt}' | claude"]
            else:
                claude_path = shutil.which('claude')
                if not claude_path:
                    self.status = self.STATUS_ERROR
                    return {"error": "未找到 claude 命令", "status": "error"}
                cmd = [claude_path]
                env['INPUT'] = prompt

            # 执行命令
            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE if platform.system() != 'Windows' else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
                encoding='utf-8',
                errors='replace',
                cwd=self.work_dir  # 设置工作目录
            )

            if platform.system() != 'Windows':
                proc.stdin.write(prompt + '\n')
                proc.stdin.close()

            try:
                stdout, stderr = proc.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                proc.kill()
                self.status = self.STATUS_ERROR
                log("ERROR", "响应超时")
                return {"error": "响应超时", "status": "timeout"}

            duration = time.time() - self.current_start_time

            # 检查是否有权限请求
            permission = self._parse_permission_request(stdout + stderr)

            if permission:
                self.status = self.STATUS_WAITING_APPROVAL
                self.pending_approvals.append(permission)
                log("PENDING", f"检测到权限请求: {permission['content'][:100]}")
                return {
                    "status": "waiting_approval",
                    "message": "Claude 请求授权执行操作",
                    "permission": permission,
                    "hint": "使用 POST /approve 授权，或 POST /approve {\"deny\": true} 拒绝"
                }

            if proc.returncode != 0:
                error_msg = stderr.strip() if stderr else f"退出码: {proc.returncode}"
                self.status = self.STATUS_ERROR
                log("ERROR", f"执行失败: {error_msg}")
                return {"error": error_msg, "status": "error", "duration": duration}

            response_text = stdout.strip()

            # 记录历史
            self.request_count += 1
            history_entry = {
                "id": self.request_count,
                "timestamp": datetime.now().isoformat(),
                "prompt": prompt,
                "response": response_text,
                "duration": round(duration, 2)
            }
            self.history.append(history_entry)

            self.status = self.STATUS_IDLE
            log("RESPONSE", f"响应完成 ({duration:.2f}s): {response_text[:100]}{'...' if len(response_text) > 100 else ''}")

            return {
                "response": response_text,
                "status": "success",
                "duration": round(duration, 2)
            }

        except Exception as e:
            self.status = self.STATUS_ERROR
            log("ERROR", f"异常: {str(e)}")
            return {"error": str(e), "status": "error"}
        finally:
            if self.status == self.STATUS_PROCESSING:
                self.status = self.STATUS_IDLE
            self.current_prompt = None
            self.current_start_time = None

    def approve(self, deny: bool = False, message: str = None) -> Dict[str, Any]:
        """处理授权请求"""
        with self.lock:
            if self.status != self.STATUS_WAITING_APPROVAL:
                return {"error": "没有待授权的操作", "status": "error"}

            if not self.pending_approvals:
                self.status = self.STATUS_IDLE
                return {"error": "授权队列为空", "status": "error"}

            pending = self.pending_approvals.pop(0)
            action = "拒绝" if deny else "授权"
            log("APPROVE", f"{action}操作: {pending.get('content', '')[:50]}")

            # 更新状态
            if not self.pending_approvals:
                self.status = self.STATUS_IDLE

            return {
                "status": "success",
                "action": "denied" if deny else "approved",
                "permission": pending,
                "message": f"已{action}该操作",
                "remaining": len(self.pending_approvals)
            }

    def get_pending_approvals(self) -> List[Dict[str, Any]]:
        """获取待授权操作列表"""
        return self.pending_approvals.copy()

    def get_history(self) -> List[Dict[str, Any]]:
        """获取对话历史"""
        return self.history.copy()

    def get_status(self) -> Dict[str, Any]:
        """获取服务状态"""
        status_info = {
            "status": self.status,
            "status_text": {
                self.STATUS_IDLE: "空闲",
                self.STATUS_PROCESSING: "处理中",
                self.STATUS_WAITING_APPROVAL: "等待授权",
                self.STATUS_ERROR: "错误"
            }.get(self.status, "未知"),
            "is_processing": self.status == self.STATUS_PROCESSING,
            "history_count": len(self.history),
            "request_count": self.request_count,
            "platform": platform.system(),
            "git_bash": self.git_bash,
            "work_dir": self.work_dir,
            "pending_approvals": len(self.pending_approvals)
        }

        # 如果正在处理，添加当前任务信息
        if self.status == self.STATUS_PROCESSING:
            status_info["current_prompt"] = self.current_prompt
            if self.current_start_time:
                status_info["elapsed_time"] = round(time.time() - self.current_start_time, 2)

        # 如果有待授权操作
        if self.pending_approvals:
            status_info["pending_list"] = self.pending_approvals

        return status_info


class RequestHandler(BaseHTTPRequestHandler):
    """HTTP 请求处理器"""

    gateway: ClaudeGateway = None

    def log_message(self, format, *args):
        """自定义日志格式 - 简化基础日志"""
        pass  # 由具体处理函数输出详细日志

    def _log_request(self, method: str, path: str, body: Any = None):
        """记录请求日志"""
        log("HTTP", f"<-- {method} {path}")
        if body:
            body_str = json.dumps(body, ensure_ascii=False)
            if len(body_str) > 200:
                body_str = body_str[:200] + "..."
            log("HTTP", f"    Body: {body_str}")

    def _log_response(self, status: int, data: Any = None):
        """记录响应日志"""
        log("HTTP", f"--> {status}")
        if data:
            data_str = json.dumps(data, ensure_ascii=False)
            if len(data_str) > 300:
                data_str = data_str[:300] + "..."
            log("HTTP", f"    Response: {data_str}")

    def _send_json_response(self, data: Dict[str, Any], status: int = 200):
        """发送 JSON 响应"""
        self._log_response(status, data)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

    def _send_error_response(self, message: str, status: int = 500):
        """发送错误响应"""
        self._send_json_response({"error": message, "status": "error"}, status)

    def do_OPTIONS(self):
        """处理 CORS 预检请求"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        """处理 GET 请求"""
        self._log_request("GET", self.path)
        if self.path == '/history':
            self._handle_history()
        elif self.path == '/status':
            self._handle_status()
        elif self.path == '/pending':
            self._handle_pending()
        else:
            self._send_error_response("未知路径，可用: /status, /history, /pending", 404)

    def do_POST(self):
        """处理 POST 请求"""
        # 读取请求体用于日志
        content_length = int(self.headers.get('Content-Length', 0))
        body_data = None
        if content_length > 0:
            try:
                body = self.rfile.read(content_length)
                body_data = json.loads(body.decode('utf-8'))
            except:
                body_data = {"raw": f"<{content_length} bytes>"}

        self._log_request("POST", self.path, body_data)

        if self.path == '/message':
            self._handle_message(body_data)
        elif self.path == '/approve':
            self._handle_approve(body_data)
        else:
            self._send_error_response("未知路径，可用: /message, /approve", 404)

    def _handle_message(self, body_data: Any = None):
        """处理消息发送"""
        if not self.gateway:
            self._send_error_response("Gateway 未初始化")
            return

        if body_data is None:
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length == 0:
                self._send_error_response("请求体为空", 400)
                return
            try:
                body = self.rfile.read(content_length)
                body_data = json.loads(body.decode('utf-8'))
            except json.JSONDecodeError:
                self._send_error_response("无效的 JSON", 400)
                return

        prompt = body_data.get('prompt', '') if isinstance(body_data, dict) else ''
        if isinstance(prompt, str):
            prompt = prompt.strip()
        else:
            prompt = str(prompt).strip()

        if not prompt:
            self._send_error_response("prompt 字段不能为空", 400)
            return

        timeout = body_data.get('timeout', 300.0) if isinstance(body_data, dict) else 300.0

        result = self.gateway.send_message(prompt, timeout)
        status = 200 if result.get('status') in ('success', 'waiting_approval') else 500
        self._send_json_response(result, status)

    def _handle_approve(self, body_data: Any = None):
        """处理授权请求"""
        if not self.gateway:
            self._send_error_response("Gateway 未初始化")
            return

        deny = False
        message = None
        if body_data and isinstance(body_data, dict):
            deny = body_data.get('deny', False)
            message = body_data.get('message')

        result = self.gateway.approve(deny=deny, message=message)
        status = 200 if result.get('status') == 'success' else 400
        self._send_json_response(result, status)

    def _handle_pending(self):
        """处理待授权列表请求"""
        if not self.gateway:
            self._send_error_response("Gateway 未初始化")
            return

        pending = self.gateway.get_pending_approvals()
        self._send_json_response({
            "count": len(pending),
            "pending": pending,
            "status": "success"
        })

    def _handle_history(self):
        """处理历史记录请求"""
        if not self.gateway:
            self._send_error_response("Gateway 未初始化")
            return

        history = self.gateway.get_history()
        self._send_json_response({
            "history": history,
            "count": len(history),
            "status": "success"
        })

    def _handle_status(self):
        """处理状态请求"""
        if not self.gateway:
            self._send_error_response("Gateway 未初始化")
            return

        status = self.gateway.get_status()
        self._send_json_response(status)


def run_http_server(gateway: ClaudeGateway, port: int = 9876):
    """运行 HTTP 服务器"""
    RequestHandler.gateway = gateway
    server = HTTPServer(('127.0.0.1', port), RequestHandler)
    log("INFO", f"HTTP 服务器启动在 http://127.0.0.1:{port}")
    log("INFO", "API 端点:")
    log("INFO", "  POST /message  发送消息")
    log("INFO", "  POST /approve  授权操作")
    log("INFO", "  GET  /status   获取状态")
    log("INFO", "  GET  /history  获取历史")
    log("INFO", "  GET  /pending  获取待授权列表")
    server.serve_forever()


def main():
    """主函数"""
    # 解析命令行参数
    work_dir = None
    if len(sys.argv) > 1:
        work_dir = sys.argv[1]
        if work_dir in ('-h', '--help'):
            print("用法: python claude-http.py [工作目录]")
            print("")
            print("参数:")
            print("  工作目录    Claude Code 的工作目录 (默认: 项目根目录)")
            print("")
            print("示例:")
            print("  python claude-http.py                    # 使用项目根目录")
            print("  python claude-http.py /path/to/project   # 指定工作目录")
            sys.exit(0)

    print("=" * 60)
    print("Claude Code HTTP Gateway")
    print("=" * 60)

    # 初始化 Gateway
    gateway = ClaudeGateway(work_dir=work_dir)

    # 测试 Claude 是否可用
    log("INFO", "测试 Claude CLI...")
    test_result = gateway.send_message("说 '服务启动成功'", timeout=30)
    if test_result.get('status') != 'success':
        log("ERROR", f"Claude CLI 测试失败: {test_result.get('error')}")
        sys.exit(1)
    log("INFO", f"Claude CLI 测试成功: {test_result.get('response', '')[:50]}...")

    # 启动 HTTP 服务器
    print("")
    try:
        run_http_server(gateway)
    except KeyboardInterrupt:
        log("INFO", "服务停止")


if __name__ == '__main__':
    main()