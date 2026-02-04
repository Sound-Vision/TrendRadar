#!/bin/bash
# 启动 Webhook 服务器的便捷脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBHOOK_SERVER="$SCRIPT_DIR/webhook_server.py"

# 默认配置
PORT="${WEBHOOK_PORT:-8765}"
CLAUDE_COMMAND="${CLAUDE_COMMAND:--p --dangerously-skip-permissions /collect_tech_topic}"

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
echo "🤖 Claude 命令: $CLAUDE_COMMAND"
echo ""
echo "💡 提示: 按 Ctrl+C 停止服务器"
echo ""

# 启动服务器
python3 "$WEBHOOK_SERVER" --port "$PORT" --claude-command "$CLAUDE_COMMAND"
