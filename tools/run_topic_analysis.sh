#!/bin/bash

# Cursor Cloud Agent 运行脚本
# 用于创建 Agent 并执行 /collect_tech_topic 命令
# 参数优先级：
# 1. 外部环境变量（例如在 GitHub Action 中通过 inputs 传入）
# 2. config/topic.conf 中的配置

set -e  # 遇到错误立即退出

# 预先保存外部传入的参数（例如 GitHub Actions 的 env 变量）
EXTERNAL_CURSOR_KEY="$CURSOR_KEY"

# 获取脚本所在目录的父目录（项目根目录）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 切换到项目根目录
cd "$PROJECT_ROOT"

# # 从配置文件读取 API Key 和 Topic
# CONFIG_FILE="$PROJECT_ROOT/config/topic.conf"
# if [ ! -f "$CONFIG_FILE" ]; then
#     echo "错误: 配置文件 $CONFIG_FILE 不存在"
#     exit 1
# fi

# # 读取配置
# source "$CONFIG_FILE"

# 如果外部环境有传入参数，则覆盖配置文件中的值
if [ -n "$EXTERNAL_CURSOR_KEY" ]; then
    CURSOR_KEY="$EXTERNAL_CURSOR_KEY"
fi

# 检查必要的变量
if [ -z "$CURSOR_KEY" ]; then
    echo "错误: 未找到有效的 CURSOR_KEY"
    echo "请使用以下任一方式提供 CURSOR_KEY："
    echo "  1. 在运行环境中设置环境变量 CURSOR_KEY（例如 GitHub Actions 的 env.CURSOR_KEY，来源于 inputs.cursor_key）"
    echo "  2. 在 $CONFIG_FILE 中配置 CURSOR_KEY=\"your_key\""
    exit 1
fi

# API 配置
API_BASE_URL="https://api.cursor.com"
API_KEY="$CURSOR_KEY"

# 项目配置
REPO_URL="https://github.com/Sound-Vision/TrendRadar"
SOURCE_BRANCH="feature/topic_collection"
TARGET_BRANCH="feature/topic_collection"
PROMPT_TEXT="/collect_tech_topic"
AGENT_NAME="Event Pipeline Agent - $(date +%Y%m%d_%H%M%S)"

echo "=========================================="
echo "Cursor Cloud Agent 执行话题分析"
echo "=========================================="
echo "仓库: $REPO_URL"
echo "源分支: $SOURCE_BRANCH"
echo "目标分支: $TARGET_BRANCH"
echo "Prompt: $PROMPT_TEXT"
echo "=========================================="
echo ""

# 创建 Agent
echo "正在创建 Agent..."
CREATE_RESPONSE=$(curl --request POST \
  --url "${API_BASE_URL}/v0/agents" \
  -u "${API_KEY}:" \
  --header 'Content-Type: application/json' \
  --data "{
    \"prompt\": {
      \"text\": \"${PROMPT_TEXT}\"
    },
    \"source\": {
      \"repository\": \"${REPO_URL}\",
      \"ref\": \"${SOURCE_BRANCH}\"
    },
    \"target\": {
      \"autoCreatePr\": false,
      \"branchName\": \"${TARGET_BRANCH}\"
    }
  }")

# 检查响应是否包含错误
if echo "$CREATE_RESPONSE" | grep -q '"error"'; then
    echo "错误: 创建 Agent 失败"
    echo "响应: $CREATE_RESPONSE"
    exit 1
fi

# 提取 Agent ID（优先使用 jq，否则使用 grep）
if command -v jq &> /dev/null; then
    AGENT_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id // empty')
    AGENT_URL=$(echo "$CREATE_RESPONSE" | jq -r '.target.url // empty')
else
    AGENT_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    AGENT_URL=$(echo "$CREATE_RESPONSE" | grep -o '"url":"[^"]*' | cut -d'"' -f4)
fi

if [ -z "$AGENT_ID" ] || [ "$AGENT_ID" == "null" ] || [ "$AGENT_ID" == "" ]; then
    echo "错误: 无法从响应中提取 Agent ID"
    echo "响应: $CREATE_RESPONSE"
    exit 1
fi

echo "✓ Agent 创建成功!"
echo "  Agent ID: $AGENT_ID"
echo "  Agent 名称: $AGENT_NAME"
echo ""

# 显示 Agent 详情 URL（如果响应中包含）
if [ -n "$AGENT_URL" ] && [ "$AGENT_URL" != "null" ]; then
    echo "  Agent 详情页: $AGENT_URL"
    echo ""
fi

# 删除 Agent 的函数
delete_agent() {
    local agent_id="$1"
    if [ -z "$agent_id" ]; then
        return 1
    fi
    
    echo ""
    echo "正在删除 Agent (ID: $agent_id)..."
    DELETE_RESPONSE=$(curl --request DELETE \
      --url "${API_BASE_URL}/v0/agents/${agent_id}" \
      -u "${API_KEY}:" \
      -s -w "\n%{http_code}")
    
    # 分离响应体和状态码
    HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$DELETE_RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 204 ]; then
        echo "✓ Agent 删除成功!"
        return 0
    else
        echo "⚠ 删除 Agent 失败 (HTTP $HTTP_CODE)"
        if [ -n "$RESPONSE_BODY" ]; then
            echo "  响应: $RESPONSE_BODY"
        fi
        return 1
    fi
}

# 轮询检查 Agent 状态
echo "正在监控 Agent 状态..."
STATUS_CHECK_COUNT=0
MAX_STATUS_CHECKS=360  # 最多检查 360 次（1小时，每10秒一次）

while [ $STATUS_CHECK_COUNT -lt $MAX_STATUS_CHECKS ]; do
    sleep 10
    
    STATUS_RESPONSE=$(curl -s -X GET \
      "${API_BASE_URL}/v0/agents/${AGENT_ID}" \
      -u "${API_KEY}:")
    
    # 解析状态（优先使用 jq，否则使用 grep）
    if command -v jq &> /dev/null; then
        STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // empty')
    else
        STATUS=$(echo "$STATUS_RESPONSE" | grep -o '"status":"[^"]*' | cut -d'"' -f4)
    fi
    
    STATUS_CHECK_COUNT=$((STATUS_CHECK_COUNT + 1))
    
    case "$STATUS" in
        "RUNNING")
            echo "[$(date +%H:%M:%S)] Agent 正在运行中... (检查次数: $STATUS_CHECK_COUNT)"
            ;;
        "FINISHED")
            echo ""
            echo "✓ Agent 执行完成!"
            
            # 显示摘要和链接（优先使用 jq，否则使用 grep）
            if command -v jq &> /dev/null; then
                SUMMARY=$(echo "$STATUS_RESPONSE" | jq -r '.summary // empty')
                PR_URL=$(echo "$STATUS_RESPONSE" | jq -r '.target.prUrl // empty')
                AGENT_URL=$(echo "$STATUS_RESPONSE" | jq -r '.target.url // empty')
            else
                SUMMARY=$(echo "$STATUS_RESPONSE" | grep -o '"summary":"[^"]*' | cut -d'"' -f4)
                PR_URL=$(echo "$STATUS_RESPONSE" | grep -o '"prUrl":"[^"]*' | cut -d'"' -f4)
                AGENT_URL=$(echo "$STATUS_RESPONSE" | grep -o '"url":"[^"]*' | cut -d'"' -f4)
            fi
            
            if [ -n "$SUMMARY" ] && [ "$SUMMARY" != "null" ]; then
                echo "  摘要: $SUMMARY"
            fi
            
            if [ -n "$PR_URL" ] && [ "$PR_URL" != "null" ]; then
                echo "  PR 链接: $PR_URL"
            fi
            
            if [ -n "$AGENT_URL" ] && [ "$AGENT_URL" != "null" ]; then
                echo "  Agent 详情: $AGENT_URL"
            fi
            
            # Agent 完成后删除
            delete_agent "$AGENT_ID"
            
            exit 0
            ;;
        "FAILED"|"ERROR")
            echo ""
            echo "✗ Agent 执行失败!"
            echo "  状态: $STATUS"
            echo "  响应: $STATUS_RESPONSE"
            
            # Agent 失败后也删除
            delete_agent "$AGENT_ID"
            
            exit 1
            ;;
        "STOPPED")
            echo ""
            echo "⚠ Agent 已停止"
            
            # Agent 停止后也删除
            delete_agent "$AGENT_ID"
            
            exit 0
            ;;
        *)
            echo "[$(date +%H:%M:%S)] Agent 状态: $STATUS (检查次数: $STATUS_CHECK_COUNT)"
            ;;
    esac
done

echo ""
echo "⚠ 达到最大检查次数，停止监控"
echo "  你可以稍后使用以下命令查看状态:"
echo "  curl -X GET \"${API_BASE_URL}/v0/agents/${AGENT_ID}\" -u \"${API_KEY}:\""
echo ""
echo "  或者删除 Agent:"
echo "  curl -X DELETE \"${API_BASE_URL}/v0/agents/${AGENT_ID}\" -u \"${API_KEY}:\""
echo ""
echo "  Agent ID: $AGENT_ID"

