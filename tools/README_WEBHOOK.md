# Webhook 集成快速开始

## 一分钟快速启动

### 1. 启动 Webhook 服务（宿主机）

```bash
./tools/start_webhook.sh
```

### 2. 启用 Webhook 功能（Docker）

编辑 `docker/.env`:

```bash
ENABLE_WEBHOOK=true
```

### 3. 重启 Docker 容器

```bash
cd docker
docker-compose restart
```

### 4. 测试

```bash
./tools/test_webhook.sh
```

## 工作原理

```
Docker 容器完成任务 → 发送 HTTP 请求 → 宿主机 Webhook 服务 → 执行 Claude 命令
```

## 详细文档

查看 [docs/WEBHOOK_INTEGRATION.md](../docs/WEBHOOK_INTEGRATION.md) 获取完整文档。

## 文件说明

- `tools/webhook_server.py` - Webhook 服务器
- `tools/start_webhook.sh` - 启动脚本
- `tools/test_webhook.sh` - 测试脚本
- `docker/entrypoint.sh` - 包含 webhook 触发逻辑
- `docker/.env` - 环境变量配置

## 故障排查

### Webhook 服务无法启动

```bash
# 检查端口是否被占用
lsof -i :8765

# 使用其他端口
WEBHOOK_PORT=9000 ./tools/start_webhook.sh
```

### 容器无法连接宿主机

```bash
# 从容器内测试连接
docker exec trendradar curl http://host.docker.internal:8765/health
```

### Claude 命令未执行

```bash
# 检查 Claude CLI 是否安装
which claude

# 查看 Webhook 服务日志
# 日志会实时显示在终端
```
