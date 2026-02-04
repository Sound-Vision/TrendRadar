# Docker Webhook 集成说明

## 功能说明

当 Docker 容器内的 TrendRadar 任务完成后，自动触发宿主机的 Claude 命令进行话题分析。

## 架构

```
┌─────────────────┐         HTTP POST          ┌──────────────────┐
│  Docker 容器    │  ───────────────────────>  │  宿主机          │
│  (TrendRadar)   │   host.docker.internal     │  (Webhook 服务)  │
└─────────────────┘                             └──────────────────┘
                                                         │
                                                         ▼
                                                  ┌──────────────┐
                                                  │ Claude 命令  │
                                                  └──────────────┘
```

## 使用步骤

### 1. 启动宿主机 Webhook 服务

在宿主机终端运行:

```bash
# 使用默认配置（端口 8765，命令 -p --dangerously-skip-permissions /collect_tech_topic）
./tools/start_webhook.sh

# 或自定义配置
WEBHOOK_PORT=9000 CLAUDE_COMMAND="-p /your_command" ./tools/start_webhook.sh
```

服务启动后会显示:
```
🚀 Webhook 服务器启动在端口 8765
📡 监听路径: http://localhost:8765/webhook
🤖 Claude 命令: -p --dangerously-skip-permissions /collect_tech_topic
💚 健康检查: http://localhost:8765/health
```

### 2. 配置 Docker 环境变量

在 `docker-compose.yml` 或启动命令中添加环境变量:

```yaml
environment:
  - ENABLE_WEBHOOK=true
  - WEBHOOK_URL=http://host.docker.internal:8765/webhook
```

或使用命令行:

```bash
docker run -e ENABLE_WEBHOOK=true \
           -e WEBHOOK_URL=http://host.docker.internal:8765/webhook \
           your-image
```

### 3. 启动 Docker 容器

```bash
docker-compose up -d
```

## 工作流程

1. Docker 容器执行 `trendradar` 任务
2. 任务完成后，`run_trendradar_with_hook()` 调用 `trigger_host_webhook()`
3. 容器通过 `host.docker.internal` 向宿主机发送 HTTP POST 请求
4. 宿主机 Webhook 服务接收请求并立即返回响应（避免超时）
5. Webhook 服务在后台线程中执行配置的 Claude 命令
6. Claude 命令执行完成后，输出会记录在 Webhook 服务的日志中
7. Claude 开始分析话题

**注意**: Claude 命令会等待执行完成，所有输出都会实时显示在 Webhook 服务的终端日志中。

## 测试

### 测试 Webhook 服务

```bash
# 健康检查
curl http://localhost:8765/health

# 手动触发 webhook
curl -X POST http://localhost:8765/webhook \
     -H "Content-Type: application/json" \
     -d '{"event":"test","timestamp":"2026-02-04 10:00:00"}'
```

### 从容器内测试

```bash
# 进入容器
docker exec -it <container_id> bash

# 测试连接
curl -X POST http://host.docker.internal:8765/webhook \
     -H "Content-Type: application/json" \
     -d '{"event":"test"}'
```

## 环境变量说明

### 容器环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ENABLE_WEBHOOK` | `false` | 是否启用 webhook 功能 |
| `WEBHOOK_URL` | `http://host.docker.internal:8765/webhook` | Webhook 服务地址 |

### 宿主机环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `WEBHOOK_PORT` | `8765` | Webhook 服务监听端口 |
| `CLAUDE_COMMAND` | `-p --dangerously-skip-permissions /collect_tech_topic` | 要执行的 Claude 命令 |

## 故障排查

### 1. 容器无法连接到宿主机

**问题**: `curl: (7) Failed to connect to host.docker.internal`

**解决方案**:
- 确认 Webhook 服务已在宿主机启动
- 检查防火墙是否阻止了端口
- 在 Linux 上，可能需要使用 `--add-host=host.docker.internal:host-gateway`

### 2. Webhook 服务收不到请求

**检查**:
```bash
# 查看服务日志
# 服务会实时显示收到的请求

# 检查端口是否被占用
lsof -i :8765
```

### 3. Claude 命令未执行

**检查**:
- 确认 Claude CLI 已正确安装: `which claude`
- 查看 Webhook 服务日志中的错误信息
- 确认命令参数正确（如 `-p --dangerously-skip-permissions /collect_tech_topic`）

## 高级配置

### 查看 Claude 命令执行日志

Claude 命令的所有输出都会实时显示在 Webhook 服务的终端中：

```bash
# 启动 Webhook 服务后，日志会显示：
2026-02-04 10:30:00 - INFO - 收到 webhook 请求: {"event":"trendradar_completed"}
2026-02-04 10:30:00 - INFO - Claude 命令已在后台线程中启动
2026-02-04 10:30:00 - INFO - 执行 Claude 命令: claude -p --dangerously-skip-permissions /collect_tech_topic
2026-02-04 10:30:00 - INFO - 开始执行 Claude 命令...
2026-02-04 10:30:01 - INFO - Claude 命令已启动，PID: 12345
# ... Claude 执行过程 ...
2026-02-04 10:35:00 - INFO - ✅ Claude 命令执行成功
2026-02-04 10:35:00 - INFO - Claude 输出:
[Claude 的完整输出内容]
```

### 后台运行 Webhook 服务

使用 `nohup` 或 `screen`:

```bash
# 使用 nohup
nohup ./tools/start_webhook.sh > webhook.log 2>&1 &

# 使用 screen
screen -S webhook
./tools/start_webhook.sh
# 按 Ctrl+A, D 分离会话
```

### 自定义 Webhook 处理

编辑 `tools/webhook_server.py` 的 `_execute_claude_command` 方法来自定义行为。

### 传递额外参数

在容器中发送请求时可以传递额外参数:

```bash
curl -X POST http://host.docker.internal:8765/webhook \
     -H "Content-Type: application/json" \
     -d '{"event":"trendradar_completed","args":["--date","2026-02-04"]}'
```

## 安全建议

1. **仅监听本地**: Webhook 服务默认监听 `0.0.0.0`，建议在生产环境中限制为 `127.0.0.1`
2. **添加认证**: 可以在 Webhook 服务中添加 token 验证
3. **限制请求频率**: 防止恶意请求

## 相关文件

- `tools/webhook_server.py` - Webhook 服务器主程序
- `tools/start_webhook.sh` - 启动脚本
- `docker/entrypoint.sh` - 容器启动脚本（包含 webhook 触发逻辑）
