# 反馈收件箱

## 环境变量

```env
# 逗号分隔，可登录收件箱的运维账号用户名
OPS_INBOX_USERNAMES=你的用户名

# 可选：附件目录，默认 backend/data/incidents
# INCIDENT_DATA_DIR=/var/lib/study-assistant/incidents

# 每用户最多保留条数（默认 30）
# INCIDENT_MAX_PER_USER=30

# 可选：提交反馈后邮件通知管理员（不配置则只进入收件箱）
# INCIDENT_ADMIN_EMAILS=admin@example.com
# PUBLIC_BASE_URL=https://www.study-assistant.cn
# SMTP_HOST=smtp.example.com
# SMTP_PORT=587
# SMTP_USERNAME=your-smtp-user
# SMTP_PASSWORD=your-smtp-password
# SMTP_FROM=伴学反馈 <noreply@example.com>
# SMTP_USE_TLS=true
# SMTP_USE_SSL=false
```

## 地址

- Web 收件箱：`https://你的域名/api/ops/inbox`
- 列表 API：`GET /api/ops/inbox/incidents`（需 Bearer + 收件箱账号）
- Cursor 修复包：`GET /api/ops/inbox/incidents/{id}/bundle` → zip

ZIP 内含 `incident.json`、`client_logs.json`、`screenshot.png`、`cursor_prompt.txt`、`README.md`，解压或拖入 Cursor 即可。

如果配置了 `INCIDENT_ADMIN_EMAILS` 与 `SMTP_HOST`，每次客户端提交反馈后会给管理员发一封邮件，并附带 `client_logs.json` 与 `screenshot.png`。邮件发送失败不会影响反馈落库，管理员仍可在收件箱查看。

## 部署后

1. 执行迁移 `migrations/019_add_client_incidents.sql` 或依赖 `init_db()` 建表
2. 确保 `backend/data/incidents` 可写（或设置 `INCIDENT_DATA_DIR`）
3. 配置 `OPS_INBOX_USERNAMES`
4. 如需邮件通知，配置 SMTP 相关环境变量并重启后端
