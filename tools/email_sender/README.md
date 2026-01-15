# 邮件发送脚本

一个通用的邮件发送脚本，支持多域名、多收件人、Markdown 内容和附件。适用于 Docker 环境。

## ✨ 功能特性

- 📧 **多收件人支持**：可同时发送给多个邮箱地址
- 🌐 **多域名支持**：支持 Gmail、QQ、163、Outlook 等各种邮箱服务商
- 📝 **Markdown 渲染**：自动将 Markdown 转换为精美的 HTML 邮件
- 📎 **附件支持**：可添加任意类型的附件
- 🐳 **Docker 就绪**：开箱即用的 Docker 支持
- 🎨 **美化样式**：自动应用专业的邮件样式
- 🔒 **安全配置**：支持环境变量、命令行参数，无需明文存储密码

## 🚀 快速开始

### 方式一：使用 Python

#### 1. 安装依赖

```bash
pip install -r requirements.txt
```

#### 2. 配置 SMTP 信息

**配置文件是可选的！** 你可以完全通过环境变量或命令行参数运行，无需创建配置文件。

有三种方式配置 SMTP 和认证信息，按安全性推荐：

**选项 A：环境变量（推荐，最安全，无需配置文件）**

```bash
# 设置环境变量
export SMTP_SERVER="smtp.gmail.com"
export SMTP_PORT=465
export SMTP_USE_SSL=true
export SMTP_SENDER_EMAIL="your-email@gmail.com"
export SMTP_SENDER_AUTH_CODE="your-app-password"

# 直接运行，无需 config.json
python send_email.py \
  --to recipient@example.com \
  --subject "测试" \
  --markdown "# Hello"
```

**选项 B：命令行参数（灵活性最高，无需配置文件）**

```bash
# 完全通过命令行参数
python send_email.py \
  --smtp-server smtp.gmail.com \
  --smtp-port 465 \
  --use-ssl \
  --sender-email "your-email@gmail.com" \
  --sender-password "your-app-password" \
  --to recipient@example.com \
  --subject "测试" \
  --file data/example.md
```

**选项 C：配置文件（传统方式）**

```bash
# 复制配置文件模板
cp config.json.example config.json
```

编辑 `config.json` 填入完整信息：

```json
{
  "smtp_server": "smtp.gmail.com",
  "smtp_port": 465,
  "use_ssl": true,
  "sender_email": "your-email@gmail.com",
  "sender_password": "your-app-password"
}
```

#### 3. 发送邮件

```bash
# 发送单个收件人
python send_email.py \
  --to recipient@example.com \
  --subject "测试邮件" \
  --file data/example.md

# 发送多个收件人
python send_email.py \
  --to user1@gmail.com user2@qq.com user3@163.com \
  --subject "重要通知" \
  --file data/example.md

# 带附件发送
python send_email.py \
  --to recipient@example.com \
  --subject "带附件的邮件" \
  --file data/example.md \
  --attachments file1.pdf file2.xlsx

# 使用字符串内容而非文件
python send_email.py \
  --to recipient@example.com \
  --subject "快速测试" \
  --markdown "# Hello\n这是一封测试邮件"
```

### 方式二：使用 Docker

#### 1. 构建镜像

```bash
docker build -t email-sender .
```

#### 2. 准备配置文件

```bash
cp config.json.example config.json
# 编辑 config.json（认证信息可留空，通过环境变量提供）
```

#### 3. 运行（使用环境变量传递认证信息，推荐）

```bash
docker run --rm \
  -e SMTP_SENDER_EMAIL="your-email@gmail.com" \
  -e SMTP_SENDER_AUTH_CODE="your-app-password" \
  -v $(pwd)/config.json:/app/config.json:ro \
  -v $(pwd)/data:/app/data:ro \
  email-sender \
  python send_email.py \
  --to recipient@example.com \
  --subject "来自 Docker 的邮件" \
  --file /app/data/example.md
```

### 方式三：使用 Docker Compose

#### 1. 编辑 docker-compose.yml

修改命令参数以适应你的需求：

```yaml
version: '3.8'

services:
  email-sender:
    build: .
    environment:
      - SMTP_SENDER_EMAIL=${SMTP_SENDER_EMAIL}
      - SMTP_SENDER_AUTH_CODE=${SMTP_SENDER_AUTH_CODE}
    volumes:
      - ./config.json:/app/config.json:ro
      - ./data:/app/data:ro
    command: >
      python send_email.py
      --to recipient@example.com
      --subject "测试邮件"
      --file /app/data/example.md
```

#### 2. 创建 .env 文件

```env
SMTP_SENDER_EMAIL=your-email@gmail.com
SMTP_SENDER_AUTH_CODE=your-app-password
```

#### 3. 运行

```bash
docker-compose up
```

## 📖 命令行参数

### 基本参数

| 参数 | 必需 | 说明 | 示例 |
|------|------|------|------|
| `-c, --config` | 否 | 配置文件路径 | `--config config.json` |
| `-t, --to` | 是 | 收件人邮箱（可多个） | `--to user@gmail.com` |
| `-s, --subject` | 是 | 邮件主题 | `--subject "重要通知"` |
| `-f, --file` | * | Markdown 文件路径 | `--file message.md` |
| `-m, --markdown` | * | Markdown 内容字符串 | `--markdown "# Hello"` |
| `-a, --attachments` | 否 | 附件路径（可多个） | `--attachments file.pdf` |
| `--cc` | 否 | 抄送邮箱（可多个） | `--cc user@qq.com` |
| `--bcc` | 否 | 密送邮箱（可多个） | `--bcc user@163.com` |

\* `-f` 和 `-m` 必须提供其中之一

### 文件路径支持

`--file` 和 `--attachments` 参数支持以下几种路径格式：

| 路径类型 | 说明 | 示例 |
|---------|------|------|
| **相对路径** | 相对于脚本运行目录 | `--file ./data/report.md`<br>`--file data/report.md` |
| **绝对路径** | 完整的文件系统路径 | `--file /home/user/docs/report.md`<br>`--file C:\Users\docs\report.md` (Windows) |
| **用户主目录** | 使用 `~` 表示主目录（shell 自动展开） | `--file ~/Documents/report.md` |

**示例**：

```bash
# 使用相对路径
python send_email.py --to user@example.com --subject "报告" \
  --file ./reports/daily.md

# 使用绝对路径
python send_email.py --to user@example.com --subject "报告" \
  --file /Users/username/Desktop/report.md \
  --attachments /path/to/file1.pdf /path/to/file2.xlsx

# 使用主目录路径
python send_email.py --to user@example.com --subject "报告" \
  --file ~/Documents/reports/monthly.md

# Docker 中使用挂载的绝对路径
docker run --rm \
  -v /host/path/reports:/app/reports:ro \
  email-sender \
  python send_email.py --to user@example.com --subject "报告" \
  --file /app/reports/daily.md
```

**注意事项**：
- 在 Docker 容器中使用绝对路径时，请确保路径对应容器内的文件系统（需要通过 `-v` 挂载）
- 使用 `~` 路径时，shell 会自动展开为实际的主目录路径
- 如果文件不存在，脚本会给出明确的错误提示

### SMTP 配置参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--smtp-server` | SMTP 服务器地址（覆盖配置文件） | `--smtp-server smtp.gmail.com` |
| `--smtp-port` | SMTP 端口（覆盖配置文件） | `--smtp-port 465` |
| `--use-ssl` | 使用 SSL 连接（不传默认 false） | `--use-ssl` |
| `--use-tls` | 使用 TLS 连接（不传默认 false） | `--use-tls` |

**注意**: 
- `--use-ssl` 和 `--use-tls` 是开关参数，**只有明确传递时才为 true，不传则为 false**
- 如果使用命令行参数，它们会覆盖配置文件中的设置
- SSL 和 TLS 通常不同时使用，根据邮件服务商要求选择

### 认证参数

| 参数 | 说明 | 示例 |
|------|------|------|
| `--sender-email` | 发件人邮箱（覆盖配置文件） | `--sender-email me@gmail.com` |
| `--sender-password` | 发件人密码（覆盖配置文件） | `--sender-password "***"` |

### 完全通过命令行参数发送示例

无需配置文件，完全通过命令行参数发送邮件：

**示例 1: Gmail（使用 SSL）**

```bash
python send_email.py \
  --smtp-server smtp.gmail.com \
  --smtp-port 465 \
  --use-ssl \
  --sender-email your-email@gmail.com \
  --sender-password your-app-password \
  --to recipient@example.com \
  --subject "测试邮件" \
  --markdown "# Hello\n\n这是一封测试邮件"
```

**示例 2: Outlook（使用 TLS）**

```bash
python send_email.py \
  --smtp-server smtp-mail.outlook.com \
  --smtp-port 587 \
  --use-tls \
  --sender-email your-email@outlook.com \
  --sender-password your-password \
  --to recipient@example.com \
  --subject "测试邮件" \
  --markdown "# Hello"
```

## 🔐 安全配置

### 配置优先级

脚本按以下优先级读取配置（高优先级覆盖低优先级）：

1. **命令行参数** (`--smtp-server`, `--sender-email` 等)
2. **环境变量** (`SMTP_SERVER`, `SMTP_SENDER_EMAIL` 等)
3. **配置文件** (`config.json`)

**💡 提示**: 配置文件是可选的！如果所有必需配置都通过环境变量或命令行参数提供，可以不创建 `config.json` 文件。

### 支持的环境变量

| 环境变量 | 对应配置 | 示例 |
|----------|----------|------|
| `SMTP_SERVER` | smtp_server | `export SMTP_SERVER=smtp.gmail.com` |
| `SMTP_PORT` | smtp_port | `export SMTP_PORT=465` |
| `SMTP_USE_SSL` | use_ssl | `export SMTP_USE_SSL=true` |
| `SMTP_USE_TLS` | use_tls | `export SMTP_USE_TLS=false` |
| `SMTP_SENDER_EMAIL` | sender_email | `export SMTP_SENDER_EMAIL=me@gmail.com` |
| `SMTP_SENDER_AUTH_CODE` | sender_password | `export SMTP_SENDER_AUTH_CODE=password` |

### 推荐方式

✅ **生产环境**: 使用环境变量或密钥管理服务  
✅ **Docker**: 使用环境变量或 Docker secrets  
✅ **开发环境**: 可以使用配置文件，但要确保不提交到 git  

⚠️ **不推荐**: 在命令行参数中直接传递密码（会被记录在 shell 历史中）

📚 **详细说明**: 查看 [SECURITY.md](./SECURITY.md) 了解更多安全配置方法

## ⚙️ 配置文件说明

配置文件中的 `sender_email` 和 `sender_password` 可以留空，通过环境变量或命令行参数提供。

### 常见邮箱配置

#### Gmail

```json
{
  "smtp_server": "smtp.gmail.com",
  "smtp_port": 465,
  "use_ssl": true,
  "sender_email": "your-email@gmail.com",
  "sender_password": "your-app-password"
}
```

**注意**：需要开启两步验证并使用[应用专用密码](https://myaccount.google.com/apppasswords)

#### QQ 邮箱

```json
{
  "smtp_server": "smtp.qq.com",
  "smtp_port": 465,
  "use_ssl": true,
  "sender_email": "your-email@qq.com",
  "sender_password": "授权码"
}
```

**注意**：需要在邮箱设置中开启 SMTP 服务并获取授权码

#### 163 邮箱

```json
{
  "smtp_server": "smtp.163.com",
  "smtp_port": 465,
  "use_ssl": true,
  "sender_email": "your-email@163.com",
  "sender_password": "授权码"
}
```

#### Outlook / Hotmail

```json
{
  "smtp_server": "smtp-mail.outlook.com",
  "smtp_port": 587,
  "use_ssl": false,
  "use_tls": true,
  "sender_email": "your-email@outlook.com",
  "sender_password": "your-password"
}
```

#### 企业邮箱（腾讯企业邮）

```json
{
  "smtp_server": "smtp.exmail.qq.com",
  "smtp_port": 465,
  "use_ssl": true,
  "sender_email": "your-email@yourcompany.com",
  "sender_password": "your-password"
}
```

## 📝 Markdown 支持

脚本支持完整的 Markdown 语法，并会自动渲染为精美的 HTML 邮件：

- ✅ 标题（H1-H6）
- ✅ 粗体、斜体、删除线
- ✅ 代码块（带语法高亮）
- ✅ 表格
- ✅ 列表（有序/无序）
- ✅ 引用
- ✅ 链接和图片
- ✅ 水平分隔线

查看 `data/example.md` 了解完整示例。

## 🔧 作为 Python 模块使用

```python
from send_email import EmailSender

# 初始化
sender = EmailSender('config.json')

# 发送邮件
sender.send_email(
    recipients=['user1@gmail.com', 'user2@qq.com'],
    subject='测试邮件',
    markdown_file='message.md',
    attachments=['report.pdf'],
    cc=['manager@company.com']
)

# 或使用字符串内容
sender.send_email(
    recipients=['user@example.com'],
    subject='快速通知',
    markdown_content='# 紧急通知\n\n系统将在今晚维护。'
)
```

## 🐛 故障排查

### 认证失败

- **Gmail**: 确保开启了两步验证并使用应用专用密码
- **QQ/163**: 确保获取了授权码（不是登录密码）
- 检查用户名和密码是否正确

### 连接超时

- 检查网络连接
- 确认 SMTP 服务器地址和端口正确
- 尝试切换 SSL/TLS 设置

### 附件问题

- 确保文件路径正确
- 检查文件是否存在
- 大附件可能被邮件服务商限制（通常 20-25MB）

## 📂 项目结构

```
email_sender/
├── send_email.py          # 核心脚本
├── config.json.example    # 配置文件模板
├── config.json           # 实际配置（不提交到 git）
├── requirements.txt      # Python 依赖
├── Dockerfile           # Docker 镜像定义
├── docker-compose.yml   # Docker Compose 配置
├── data/                # 数据目录
│   └── example.md       # Markdown 示例
└── README.md            # 本文档
```

## 🔐 安全建议

1. **不要提交配置文件到 Git**：`config.json` 已在 `.gitignore` 中
2. **使用应用专用密码**：避免使用账号主密码
3. **限制文件权限**：`chmod 600 config.json`
4. **使用环境变量**：生产环境建议使用环境变量或密钥管理服务

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**享受发送邮件的乐趣！** 🎉
