#!/bin/bash
set -e

# 检查配置文件
if [ ! -f "/app/config/config.yaml" ] || [ ! -f "/app/config/frequency_words.txt" ]; then
    echo "❌ 配置文件缺失"
    exit 1
fi

# 保存环境变量
env >> /etc/environment

# Git 自动提交推送函数
git_auto_push() {
    if [ "${GIT_AUTO_PUSH:-false}" != "true" ]; then
        return 0
    fi

    # 检查 .git 目录是否存在
    if [ ! -d "/app/.git" ]; then
        echo "⚠️ Git 仓库未挂载，跳过 git 推送"
        return 0
    fi

    cd /app

    # 配置 git 用户信息（如果提供了环境变量）
    if [ -n "$GIT_USER_NAME" ]; then
        git config user.name "$GIT_USER_NAME"
    fi
    if [ -n "$GIT_USER_EMAIL" ]; then
        git config user.email "$GIT_USER_EMAIL"
    fi

    # 配置 SSH 密钥（如果挂载了）
    if [ -f "/root/.ssh/id_rsa" ] || [ -f "/root/.ssh/id_ed25519" ]; then
        chmod 600 /root/.ssh/id_* 2>/dev/null || true
        chmod 700 /root/.ssh 2>/dev/null || true
        # 添加 GitHub 等常用主机到 known_hosts
        if [ ! -f "/root/.ssh/known_hosts" ]; then
            ssh-keyscan -t rsa github.com gitlab.com gitee.com >> /root/.ssh/known_hosts 2>/dev/null || true
        fi
        # 忽略 macOS 特有的 SSH 配置选项（如 UseKeychain），避免在 Linux 容器中报错
        export GIT_SSH_COMMAND="ssh -F /dev/null -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa -i /root/.ssh/id_ed25519"
    fi

    # 检查 output 目录是否有更改
    if git diff --quiet -- output/ && git diff --cached --quiet -- output/; then
        echo "📝 output 目录没有文件变更，跳过 git 提交"
        return 0
    fi

    # 获取当前时间戳
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    COMMIT_MSG="${GIT_COMMIT_PREFIX:-TrendRadar Update} - ${TIMESTAMP}"

    echo "📤 正在提交 output 目录到 Git..."
    git add output/
    git commit -m "$COMMIT_MSG" || {
        echo "⚠️ Git 提交失败（可能没有更改）"
        return 0
    }

    echo "🚀 正在推送到远端..."
    if git push; then
        echo "✅ Git 推送成功: $COMMIT_MSG"
    else
        echo "❌ Git 推送失败，请检查网络或认证配置"
        return 1
    fi
}

# 执行 trendradar 并在成功后进行 git 推送
run_trendradar_with_git() {
    /usr/local/bin/python -m trendradar
    git_auto_push
}

case "${RUN_MODE:-cron}" in
"once")
    echo "🔄 单次执行"
    # exec /usr/local/bin/python -m trendradar
    run_trendradar_with_git
    ;;
"cron")
    # 生成 crontab（包含 git 推送）
    if [ "${GIT_AUTO_PUSH:-false}" = "true" ]; then
        echo "${CRON_SCHEDULE:-*/30 * * * *} cd /app && /usr/local/bin/python -m trendradar && /entrypoint.sh git_push_only" > /tmp/crontab
    else
        echo "${CRON_SCHEDULE:-*/30 * * * *} cd /app && /usr/local/bin/python -m trendradar" > /tmp/crontab
    fi
    
    echo "📅 生成的crontab内容:"
    cat /tmp/crontab

    if ! /usr/local/bin/supercronic -test /tmp/crontab; then
        echo "❌ crontab格式验证失败"
        exit 1
    fi

    # 立即执行一次（如果配置了）
    if [ "${IMMEDIATE_RUN:-false}" = "true" ]; then
        echo "▶️ 立即执行一次"
        # /usr/local/bin/python -m trendradar
        run_trendradar_with_git
    fi

    # 启动 Web 服务器（如果配置了）
    if [ "${ENABLE_WEBSERVER:-false}" = "true" ]; then
        echo "🌐 启动 Web 服务器..."
        /usr/local/bin/python manage.py start_webserver
    fi

    echo "⏰ 启动supercronic: ${CRON_SCHEDULE:-*/30 * * * *}"
    echo "🎯 supercronic 将作为 PID 1 运行"

    exec /usr/local/bin/supercronic -passthrough-logs /tmp/crontab
    ;;
*)
    exec "$@"
    ;;
esac