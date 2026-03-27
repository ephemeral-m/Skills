#!/usr/bin/env python3
"""
Claude Code HTTP Gateway - 简化版

功能：
  劫持 Claude Code 终端，通过 HTTP API 发送消息

使用方式：
  python claude-http.py

API 端点：
  POST /message      发送消息
  GET  /task/{id}    查询结果
  GET  /status       服务状态
"""

import subprocess
import json
import sys
import os
import uuid
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum

# ========== 配置 ==========

PORT = 9876
DEFAULT_TIMEOUT = 600.0  # 10 分钟

# ========== 日志 ==========

LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gateway.log")
_log_handle = None


def log(level: str, message: str):
    """统一日志输出"""
    timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
    line = f"[{timestamp}] [{level}] {message}"

    # 写入文件
    global _log_handle
    if _log_handle:
        try:
            _log_handle.write(line + '\n')
        except Exception:
            pass

    # 输出控制台
    try:
        print(line, flush=True)
    except UnicodeEncodeError:
        try:
            print(line.encode('gbk', errors='replace').decode('gbk'), flush=True)
        except Exception:
            pass


# ========== 任务状态 ==========

class Status(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


# ========== Claude 执行器 ==========

class ClaudeExecutor:
    """Claude CLI 执行器"""

    def __init__(self):
        self.work_dir = os.getcwd()
        self.session_id = str(uuid.uuid4())
        self.is_first_run = True
        log("INFO", f"工作目录: {self.work_dir}")
        log("INFO", f"会话 ID: {self.session_id}")

    def execute(self, prompt: str, timeout: float = DEFAULT_TIMEOUT) -> Dict[str, Any]:
        """执行 Claude 命令"""
        start_time = datetime.now()

        # 打印用户输入
        log("USER", "=" * 50)
        log("USER", f"Prompt ({len(prompt)} 字符):")
        for line in prompt.split('\n'):
            log("USER", f"  {line}")
        log("USER", "=" * 50)

        try:
            # 构建命令
            if self.is_first_run:
                cmd = ["claude", "-p", "--session-id", self.session_id]
                self.is_first_run = False
            else:
                cmd = ["claude", "-p", "--resume", self.session_id]

            log("PROC", f"执行: {' '.join(cmd[:4])}...")

            # 启动进程
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding='utf-8',
                errors='replace',
                cwd=self.work_dir
            )

            # 写入 prompt
            process.stdin.write(prompt)
            process.stdin.close()

            # 等待完成
            stdout, stderr = process.communicate(timeout=timeout)

            duration = (datetime.now() - start_time).total_seconds()

            if process.returncode != 0:
                error = stderr.strip() if stderr else f"退出码: {process.returncode}"
                log("ERROR", f"执行失败: {error}")
                return {"success": False, "error": error, "duration": duration}

            # 解析输出
            response = self._parse_output(stdout)
            self._log_response(response, duration)

            return {"success": True, "response": response, "duration": duration}

        except subprocess.TimeoutExpired:
            process.kill()
            duration = (datetime.now() - start_time).total_seconds()
            log("ERROR", f"执行超时 ({timeout}s)")
            return {"success": False, "error": f"超时 ({timeout}s)", "duration": duration}

        except Exception as e:
            duration = (datetime.now() - start_time).total_seconds()
            log("ERROR", f"异常: {e}")
            return {"success": False, "error": str(e), "duration": duration}

    def _parse_output(self, output: str) -> str:
        """解析输出（默认纯文本模式）"""
        return output.strip()

    def _log_response(self, response: str, duration: float):
        """打印响应"""
        log("AI", "=" * 50)
        log("AI", f"Response ({duration:.2f}s, {len(response)} 字符):")
        lines = response.split('\n')
        if len(lines) <= 30:
            for line in lines:
                log("AI", f"  {line}")
        else:
            for line in lines[:15]:
                log("AI", f"  {line}")
            log("AI", f"  ... (省略 {len(lines) - 30} 行) ...")
            for line in lines[-15:]:
                log("AI", f"  {line}")
        log("AI", "=" * 50)


# ========== 任务管理 ==========

class TaskManager:
    """任务管理器"""

    def __init__(self, executor: ClaudeExecutor):
        self.executor = executor
        self.tasks: Dict[str, Dict] = {}
        self.lock = threading.Lock()

    def submit(self, prompt: str, timeout: float = DEFAULT_TIMEOUT) -> str:
        """提交任务（异步执行）"""
        task_id = str(uuid.uuid4())[:8]

        with self.lock:
            self.tasks[task_id] = {
                "task_id": task_id,
                "prompt": prompt,
                "status": Status.PENDING.value,
                "created_at": datetime.now().isoformat()
            }

        # 后台线程执行
        threading.Thread(target=self._execute, args=(task_id, prompt, timeout), daemon=True).start()

        return task_id

    def _execute(self, task_id: str, prompt: str, timeout: float):
        """执行任务"""
        with self.lock:
            self.tasks[task_id]["status"] = Status.RUNNING.value

        result = self.executor.execute(prompt, timeout)

        with self.lock:
            self.tasks[task_id].update({
                "status": Status.COMPLETED.value if result["success"] else Status.FAILED.value,
                "response": result.get("response"),
                "error": result.get("error"),
                "duration": round(result.get("duration", 0), 2),
                "completed_at": datetime.now().isoformat()
            })

    def get(self, task_id: str) -> Optional[Dict]:
        with self.lock:
            return self.tasks.get(task_id)

    def status(self) -> Dict:
        return {
            "total_tasks": len(self.tasks),
            "session_id": self.executor.session_id,
            "work_dir": self.executor.work_dir
        }


# ========== HTTP 处理器 ==========

class Handler(BaseHTTPRequestHandler):
    """HTTP 请求处理器"""

    task_manager: TaskManager = None

    def log_message(self, *args):
        pass  # 禁用默认日志

    def _json(self, data: Dict, status: int = 200):
        """发送 JSON 响应"""
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False, indent=2).encode('utf-8'))

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        """处理 GET 请求"""
        if self.path == '/status':
            self._json(self.task_manager.status())
        elif self.path.startswith('/task/'):
            task_id = self.path[6:].split('?')[0]
            task = self.task_manager.get(task_id)
            if task:
                self._json(task)
            else:
                self._json({"error": "任务不存在"}, 404)
        else:
            self._json({"error": "未知路径"}, 404)

    def do_POST(self):
        """处理 POST 请求"""
        if self.path == '/message':
            self._handle_message()
        else:
            self._json({"error": "未知路径"}, 404)

    def _handle_message(self):
        """处理消息请求"""
        length = int(self.headers.get('Content-Length', 0))
        if length == 0:
            self._json({"error": "请求体为空"}, 400)
            return

        try:
            body = self.rfile.read(length)
            text = body.decode('utf-8')
            data = json.loads(text)
        except UnicodeDecodeError:
            text = body.decode('gbk', errors='replace')
            data = json.loads(text)
        except json.JSONDecodeError:
            # 纯文本模式
            data = {"prompt": text.strip().strip("'\"")}

        prompt = data.get('prompt', '').strip()
        if not prompt:
            self._json({"error": "prompt 不能为空"}, 400)
            return

        timeout = data.get('timeout', DEFAULT_TIMEOUT)
        if timeout <= 0:
            timeout = None

        task_id = self.task_manager.submit(prompt, timeout)

        log("HTTP", f"POST /message -> {task_id}")

        self._json({
            "task_id": task_id,
            "status": "pending",
            "hint": f"curl http://127.0.0.1:{PORT}/task/{task_id}"
        })


# ========== 主程序 ==========

def main():
    global _log_handle
    _log_handle = open(LOG_FILE, 'a', encoding='utf-8', buffering=1)

    print("=" * 60)
    print("Claude Code HTTP Gateway")
    print("=" * 60)
    log("INFO", f"日志文件: {LOG_FILE}")

    # 初始化
    executor = ClaudeExecutor()
    task_manager = TaskManager(executor)
    Handler.task_manager = task_manager

    # 启动服务器
    server = HTTPServer(('127.0.0.1', PORT), Handler)

    print("")
    print(f"服务已启动: http://127.0.0.1:{PORT}")
    print("")
    print("API 端点:")
    print(f"  POST /message      发送消息")
    print(f"  GET  /task/{{id}}    查询结果")
    print(f"  GET  /status       服务状态")
    print("")
    print("Windows CMD 使用示例:")
    print(f'  curl -X POST http://127.0.0.1:{PORT}/message -H "Content-Type: application/json" -d "{{\\"prompt\\": \\"你好\\"}}"')
    print("")
    print("PowerShell 使用示例:")
    print(f'  Invoke-RestMethod -Uri http://127.0.0.1:{PORT}/message -Method POST -Body \'{{\\"prompt\\": \\"你好\\"}}\' -ContentType application/json')
    print("")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("INFO", "服务停止")
    finally:
        _log_handle.close()


if __name__ == '__main__':
    main()