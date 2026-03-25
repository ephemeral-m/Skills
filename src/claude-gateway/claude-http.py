#!/usr/bin/env python3
"""
Claude Code HTTP Gateway - 异步版本

使用方式：
  python claude-http.py [工作目录]

功能：
  - HTTP API 接口（端口 9876）
    - POST /message    提交消息，立即返回 task_id
    - GET  /task/{id}  查询任务状态和结果
    - POST /task/{id}/cancel  取消任务
    - GET  /status     获取服务状态
    - GET  /history    获取历史记录

技术说明：
  - 异步任务模型，避免请求超时
  - 支持长时间运行的任务
  - Windows 上通过 Git Bash 管道模式调用 Claude CLI
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
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum
from queue import Queue


def get_project_root() -> str:
    """获取项目根目录"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.dirname(os.path.dirname(script_dir))


def get_log_file() -> str:
    """获取日志文件路径"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, "gateway.log")


# 全局日志文件句柄
_log_file_handle: Optional[Any] = None


def _init_logging():
    """初始化日志系统"""
    global _log_file_handle
    log_file = get_log_file()
    # 使用 UTF-8 编码写入日志文件
    _log_file_handle = open(log_file, 'a', encoding='utf-8', buffering=1)  # 行缓冲


def _close_logging():
    """关闭日志系统"""
    global _log_file_handle
    if _log_file_handle:
        _log_file_handle.close()
        _log_file_handle = None


def log(level: str, message: str):
    """统一日志输出 - 同时写入控制台和文件"""
    timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
    log_line = f"[{timestamp}] [{level}] {message}"

    # 写入文件 (UTF-8)
    global _log_file_handle
    if _log_file_handle:
        try:
            _log_file_handle.write(log_line + '\n')
        except Exception:
            pass

    # 输出到控制台 (处理编码问题)
    try:
        print(log_line, flush=True)
    except UnicodeEncodeError:
        # Windows 控制台可能不支持 UTF-8，使用 GBK 替换
        try:
            safe_msg = message.encode('gbk', errors='replace').decode('gbk')
            print(f"[{timestamp}] [{level}] {safe_msg}", flush=True)
        except Exception:
            pass


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
    return result if result else None


class TaskStatus(Enum):
    """任务状态"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class Task:
    """任务对象"""

    def __init__(self, task_id: str, prompt: str, timeout: Optional[float] = 600.0):
        self.task_id = task_id
        self.prompt = prompt
        self.timeout = timeout  # None 表示无限制
        self.status = TaskStatus.PENDING
        self.response: Optional[str] = None
        self.error: Optional[str] = None
        self.created_at = datetime.now().isoformat()
        self.started_at: Optional[str] = None
        self.completed_at: Optional[str] = None
        self.duration: Optional[float] = None
        self.process: Optional[subprocess.Popen] = None

    def to_dict(self) -> Dict[str, Any]:
        result = {
            "task_id": self.task_id,
            "prompt": self.prompt,
            "status": self.status.value,
            "timeout": "无限制" if self.timeout is None else self.timeout,
            "created_at": self.created_at,
        }
        if self.started_at:
            result["started_at"] = self.started_at
        if self.completed_at:
            result["completed_at"] = self.completed_at
        if self.duration is not None:
            result["duration"] = round(self.duration, 2)
        if self.response:
            result["response"] = self.response
        if self.error:
            result["error"] = self.error
        return result


class ClaudeGateway:
    """Claude Code 网关 - 异步版本"""

    def __init__(self, work_dir: Optional[str] = None, max_workers: int = 1):
        self.tasks: Dict[str, Task] = {}
        self.history: List[Dict[str, Any]] = []
        self.lock = threading.Lock()
        self.git_bash: Optional[str] = None
        self.request_count = 0

        # 工作目录
        self.work_dir = work_dir if work_dir else get_project_root()

        # 任务队列和工作线程
        self.task_queue: Queue = Queue()
        self.max_workers = max_workers
        self.running = True

        # 初始化 Git Bash
        if platform.system() == 'Windows':
            self.git_bash = _find_git_bash()
            if self.git_bash:
                log("INFO", f"Git Bash: {self.git_bash}")

        log("INFO", f"工作目录: {self.work_dir}")

        # 启动工作线程
        for _ in range(max_workers):
            worker = threading.Thread(target=self._worker_loop, daemon=True)
            worker.start()

    def _worker_loop(self):
        """工作线程循环"""
        while self.running:
            try:
                task = self.task_queue.get(timeout=1.0)
                if task:
                    self._execute_task(task)
            except Exception:
                continue

    def _execute_task(self, task: Task):
        """执行任务"""
        task.status = TaskStatus.RUNNING
        task.started_at = datetime.now().isoformat()
        start_time = time.time()

        log("TASK", f"[{task.task_id[:8]}] 开始执行 (超时: {'无限制' if task.timeout is None else f'{task.timeout}s'})")
        log("TASK", f"[{task.task_id[:8]}] Prompt: {task.prompt}")

        try:
            env = os.environ.copy()
            if self.git_bash:
                env['CLAUDE_CODE_GIT_BASH_PATH'] = self.git_bash.replace('/', '\\')

            # 构建命令
            if platform.system() == 'Windows' and self.git_bash:
                escaped = task.prompt.replace("'", "'\\''")
                cmd = [self.git_bash, '-c', f"echo '{escaped}' | claude"]
            else:
                claude_path = shutil.which('claude')
                if not claude_path:
                    task.status = TaskStatus.FAILED
                    task.error = "未找到 claude 命令"
                    log("TASK", f"[{task.task_id[:8]}] 错误: {task.error}")
                    return
                cmd = [claude_path]

            proc = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE if platform.system() != 'Windows' else None,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=env,
                encoding='utf-8',
                errors='replace',
                cwd=self.work_dir
            )
            task.process = proc

            try:
                # timeout=None 表示无限等待
                stdout, stderr = proc.communicate(timeout=task.timeout)
            except subprocess.TimeoutExpired:
                proc.kill()
                task.status = TaskStatus.FAILED
                task.error = f"执行超时 (限制: {task.timeout}s)"
                task.duration = time.time() - start_time
                log("TASK", f"[{task.task_id[:8]}] 超时 (限制: {task.timeout}s)")
                return

            task.duration = time.time() - start_time

            if task.status == TaskStatus.CANCELLED:
                log("TASK", f"[{task.task_id[:8]}] 已取消")
                return

            if proc.returncode != 0:
                task.status = TaskStatus.FAILED
                task.error = stderr.strip() if stderr else f"退出码: {proc.returncode}"
                log("TASK", f"[{task.task_id[:8]}] 失败: {task.error}")
                return

            task.response = stdout.strip()
            task.status = TaskStatus.COMPLETED
            task.completed_at = datetime.now().isoformat()

            # 记录历史
            self.request_count += 1
            self.history.append({
                "id": self.request_count,
                "task_id": task.task_id,
                "timestamp": task.created_at,
                "prompt": task.prompt,
                "response": task.response,
                "duration": round(task.duration, 2)
            })

            # 输出详细响应日志
            log("TASK", f"[{task.task_id[:8]}] ====== 任务完成 ======")
            log("TASK", f"[{task.task_id[:8]}] 耗时: {task.duration:.2f}s")
            log("TASK", f"[{task.task_id[:8]}] 响应长度: {len(task.response)} 字符")

            lines = task.response.split('\n')
            if len(lines) <= 20:
                log("TASK", f"[{task.task_id[:8]}] 响应内容:")
                for line in lines:
                    log("TASK", f"[{task.task_id[:8]}]   {line}")
            else:
                log("TASK", f"[{task.task_id[:8]}] 响应内容 (共 {len(lines)} 行):")
                for line in lines[:10]:
                    log("TASK", f"[{task.task_id[:8]}]   {line}")
                log("TASK", f"[{task.task_id[:8]}]   ... (省略 {len(lines) - 15} 行) ...")
                for line in lines[-5:]:
                    log("TASK", f"[{task.task_id[:8]}]   {line}")

            log("TASK", f"[{task.task_id[:8]}] ======================")

        except Exception as e:
            task.status = TaskStatus.FAILED
            task.error = str(e)
            task.duration = time.time() - start_time
            log("ERROR", f"[{task.task_id[:8]}] 异常: {e}")

    def submit_task(self, prompt: str, timeout: Optional[float] = 600.0) -> str:
        """提交任务"""
        task_id = str(uuid.uuid4())
        task = Task(task_id, prompt, timeout)

        with self.lock:
            self.tasks[task_id] = task

        self.task_queue.put(task)
        log("TASK", f"[{task_id[:8]}] 任务已提交")
        return task_id

    def get_task(self, task_id: str) -> Optional[Task]:
        return self.tasks.get(task_id)

    def cancel_task(self, task_id: str) -> bool:
        task = self.tasks.get(task_id)
        if not task:
            return False

        if task.status == TaskStatus.PENDING:
            task.status = TaskStatus.CANCELLED
            log("TASK", f"[{task_id[:8]}] 已取消 (等待中)")
            return True

        if task.status == TaskStatus.RUNNING and task.process:
            task.process.kill()
            task.status = TaskStatus.CANCELLED
            log("TASK", f"[{task_id[:8]}] 已取消 (执行中)")
            return True

        return False

    def get_status(self) -> Dict[str, Any]:
        pending = sum(1 for t in self.tasks.values() if t.status == TaskStatus.PENDING)
        running = sum(1 for t in self.tasks.values() if t.status == TaskStatus.RUNNING)

        return {
            "status": "running",
            "work_dir": self.work_dir,
            "platform": platform.system(),
            "git_bash": self.git_bash,
            "max_workers": self.max_workers,
            "queue_size": self.task_queue.qsize(),
            "pending_tasks": pending,
            "running_tasks": running,
            "total_tasks": len(self.tasks),
            "history_count": len(self.history),
        }

    def get_history(self) -> List[Dict[str, Any]]:
        return self.history.copy()

    def stop(self):
        self.running = False
        for task in self.tasks.values():
            if task.status == TaskStatus.RUNNING and task.process:
                task.process.kill()


class RequestHandler(BaseHTTPRequestHandler):
    """HTTP 请求处理器"""

    gateway: ClaudeGateway = None

    def log_message(self, format, *args):
        pass

    def _send_json(self, data: Dict[str, Any], status: int = 200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        self.wfile.write(json.dumps(data, ensure_ascii=False).encode('utf-8'))

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        # /task/{id}
        match = re.match(r'^/task/([a-f0-9-]+)$', self.path)
        if match:
            self._handle_get_task(match.group(1))
            return

        if self.path == '/status':
            self._handle_status()
        elif self.path == '/history':
            self._handle_history()
        else:
            self._send_json({"error": "未知路径"}, 404)

    def do_POST(self):
        # /task/{id}/cancel
        match = re.match(r'^/task/([a-f0-9-]+)/cancel$', self.path)
        if match:
            self._handle_cancel_task(match.group(1))
            return

        if self.path == '/message':
            self._handle_submit()
        else:
            self._send_json({"error": "未知路径"}, 404)

    def _handle_submit(self):
        if not self.gateway:
            self._send_json({"error": "未初始化"}, 500)
            return

        length = int(self.headers.get('Content-Length', 0))
        if length == 0:
            self._send_json({"error": "请求体为空"}, 400)
            return

        try:
            body = self.rfile.read(length)
            # 尝试 UTF-8，失败则尝试系统默认编码
            try:
                data = json.loads(body.decode('utf-8'))
            except UnicodeDecodeError:
                data = json.loads(body.decode('gbk', errors='replace'))
        except (json.JSONDecodeError, UnicodeDecodeError) as e:
            self._send_json({"error": f"无效的 JSON: {e}"}, 400)
            return

        prompt = data.get('prompt', '').strip() if isinstance(data, dict) else ''
        if not prompt:
            self._send_json({"error": "prompt 不能为空"}, 400)
            return

        timeout = data.get('timeout', 600.0)  # 默认 10 分钟
        # timeout <= 0 表示不限制
        if timeout <= 0:
            timeout = None  # 无限等待

        task_id = self.gateway.submit_task(prompt, timeout)

        log("HTTP", f"<-- POST /message -> {task_id[:8]} (timeout: {'无限制' if timeout is None else f'{timeout}s'})")
        self._send_json({
            "task_id": task_id,
            "status": "pending",
            "message": "任务已提交",
            "timeout": timeout,
            "hint": f"GET /task/{task_id} 查询结果"
        })

    def _handle_get_task(self, task_id: str):
        if not self.gateway:
            self._send_json({"error": "未初始化"}, 500)
            return

        task = self.gateway.get_task(task_id)
        if not task:
            self._send_json({"error": "任务不存在"}, 404)
            return

        log("HTTP", f"<-- GET /task/{task_id[:8]} ({task.status.value})")
        self._send_json(task.to_dict())

    def _handle_cancel_task(self, task_id: str):
        if not self.gateway:
            self._send_json({"error": "未初始化"}, 500)
            return

        success = self.gateway.cancel_task(task_id)
        if success:
            log("HTTP", f"<-- POST /task/{task_id[:8]}/cancel")
            self._send_json({"task_id": task_id, "status": "cancelled", "message": "已取消"})
        else:
            self._send_json({"error": "无法取消"}, 400)

    def _handle_status(self):
        if not self.gateway:
            self._send_json({"error": "未初始化"}, 500)
            return
        self._send_json(self.gateway.get_status())

    def _handle_history(self):
        if not self.gateway:
            self._send_json({"error": "未初始化"}, 500)
            return
        self._send_json({"history": self.gateway.get_history(), "count": len(self.gateway.history)})


def main():
    work_dir = None
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ('-h', '--help'):
            print("用法: python claude-http.py [工作目录]")
            print("\nAPI 端点:")
            print("  POST /message          提交任务")
            print("  GET  /task/{id}        查询任务")
            print("  POST /task/{id}/cancel 取消任务")
            sys.exit(0)
        work_dir = arg

    # 初始化日志系统
    _init_logging()

    print("=" * 60)
    print("Claude Code HTTP Gateway (异步版)")
    print("=" * 60)
    log("INFO", f"日志文件: {get_log_file()}")

    gateway = ClaudeGateway(work_dir=work_dir)

    log("INFO", "测试 Claude CLI...")
    test_id = gateway.submit_task("说 '服务启动成功'", timeout=30)

    for _ in range(60):
        task = gateway.get_task(test_id)
        if task and task.status in (TaskStatus.COMPLETED, TaskStatus.FAILED):
            break
        time.sleep(0.5)

    test_task = gateway.get_task(test_id)
    if test_task and test_task.status == TaskStatus.COMPLETED:
        log("INFO", "Claude CLI 测试成功")
    else:
        log("ERROR", f"Claude CLI 测试失败: {test_task.error if test_task else '未知'}")

    RequestHandler.gateway = gateway
    server = HTTPServer(('127.0.0.1', 9876), RequestHandler)

    log("INFO", "HTTP 服务器启动在 http://127.0.0.1:9876")
    log("INFO", "API 端点:")
    log("INFO", "  POST /message          提交任务")
    log("INFO", "  GET  /task/{id}        查询任务")
    log("INFO", "  POST /task/{id}/cancel 取消任务")
    log("INFO", "  GET  /status           获取状态")
    log("INFO", "  GET  /history          获取历史")
    print("")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("INFO", "服务停止")
        gateway.stop()
    finally:
        _close_logging()


if __name__ == '__main__':
    main()