#!/bin/bash
# 启动 Webhook 服务器的便捷脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBHOOK_SERVER="$SCRIPT_DIR/webhook_server.py"

# 默认配置
PORT="${WEBHOOK_PORT:-8765}"
# 收到 webhook 后要执行的完整命令（可以是 claude、gemini 或任意命令）
# AGENT_COMMAND="${AGENT_COMMAND:-claude -p --dangerously-skip-permissions /collect_tech_topic}"
AGENT_COMMAND="${AGENT_COMMAND:-gemini -m gemini-3.1-pro-preview -p /collect_tech_topic}"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 python3"
    exit 1
fi

# 检查服务器脚本
if [ ! -f "$WEBHOOK_SERVER" ]; then
    echo "❌ 错误: 未找到 webhook_server.py"
    exit 1
fi

echo "🚀 启动 Webhook 服务器..."
echo "📡 端口: $PORT"
echo "🤖 Agent 命令: $AGENT_COMMAND"
echo ""
echo "💡 提示: 按 Ctrl+C 停止服务器"
echo ""

# 启动服务器
python3 "$WEBHOOK_SERVER" --port "$PORT" --agent-command "$AGENT_COMMAND"
