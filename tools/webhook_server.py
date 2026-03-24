#!/usr/bin/env python3
"""
Webhook 服务器 - 接收 Docker 容器的通知并触发 Agent 命令

使用方法:
    python tools/webhook_server.py --port 8765 --agent-command "claude -p --dangerously-skip-permissions /collect_tech_topic"
"""

import argparse
import json
import logging
import shlex
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class WebhookHandler(BaseHTTPRequestHandler):
    """处理 Webhook 请求"""

    agent_command = None

    def do_POST(self):
        """处理 POST 请求"""
        if self.path != '/webhook':
            self.send_error(404, "Not Found")
            return

        try:
            # 读取请求体
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode('utf-8')

            logger.info(f"收到 webhook 请求: {body}")

            # 解析 JSON 数据（可选）
            try:
                data = json.loads(body) if body else {}
            except json.JSONDecodeError:
                data = {}

            # 在后台线程中执行 Claude 命令，避免阻塞 HTTP 响应
            if self.agent_command:
                thread = threading.Thread(
                    target=self._execute_agent_command,
                    args=(data,),
                    daemon=True
                )
                thread.start()
                logger.info("Agent 命令已在后台线程中启动")

            # 立即返回成功响应
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = json.dumps({
                'status': 'success',
                'message': 'Webhook received, agent command started',
                'timestamp': datetime.now().isoformat()
            })
            self.wfile.write(response.encode('utf-8'))

        except Exception as e:
            logger.error(f"处理 webhook 失败: {e}", exc_info=True)
            self.send_error(500, str(e))

    def _execute_agent_command(self, data):
        """执行 Agent 命令"""
        try:
            cmd = shlex.split(self.agent_command)

            # 如果有额外参数，添加到命令中
            if data.get('args'):
                cmd.extend(data['args'])

            # 执行命令并等待完成
            logger.info(f"开始执行命令: {' '.join(cmd)}")
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )

            logger.info(f"命令已启动，PID: {process.pid}")

            # 等待命令完成并记录输出
            stdout, stderr = process.communicate()

            if process.returncode == 0:
                logger.info("✅ 命令执行成功")
                if stdout:
                    logger.info(f"输出:\n{stdout}")
            else:
                logger.error(f"❌ 命令执行失败，返回码: {process.returncode}")
                if stderr:
                    logger.error(f"错误:\n{stderr}")
                if stdout:
                    logger.info(f"输出:\n{stdout}")

        except Exception as e:
            logger.error(f"执行命令失败: {e}", exc_info=True)

    def do_GET(self):
        """处理 GET 请求（健康检查）"""
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = json.dumps({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat()
            })
            self.wfile.write(response.encode('utf-8'))
        else:
            self.send_error(404, "Not Found")

    def log_message(self, format, *args):
        """自定义日志格式"""
        logger.info(f"{self.address_string()} - {format % args}")


def run_server(port, agent_command):
    """启动 Webhook 服务器"""
    WebhookHandler.agent_command = agent_command

    server_address = ('', port)
    httpd = HTTPServer(server_address, WebhookHandler)

    logger.info(f"🚀 Webhook 服务器启动在端口 {port}")
    logger.info(f"📡 监听路径: http://localhost:{port}/webhook")
    logger.info(f"🤖 Agent 命令: {agent_command}")
    logger.info(f"💚 健康检查: http://localhost:{port}/health")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("\n⏹️  服务器已停止")
        httpd.shutdown()


def main():
    parser = argparse.ArgumentParser(description='Webhook 服务器 - 触发 Agent 命令')
    parser.add_argument(
        '--port',
        type=int,
        default=8765,
        help='服务器端口 (默认: 8765)'
    )
    parser.add_argument(
        '--agent-command',
        type=str,
        default='claude -p --dangerously-skip-permissions /collect_tech_topic',
        help='收到 webhook 后要执行的完整命令 (默认: claude -p --dangerously-skip-permissions /collect_tech_topic)'
    )

    args = parser.parse_args()
    run_server(args.port, args.agent_command)


if __name__ == '__main__':
    main()
