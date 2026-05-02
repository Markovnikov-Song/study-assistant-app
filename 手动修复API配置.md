# 手动修复 API 配置 404 问题

## 方法 1：使用简化脚本

```powershell
.\deploy_api_config_only.ps1
```

## 方法 2：完全手动操作

### 步骤 1：上传文件

```powershell
scp backend/routers/api_config.py admin@47.104.165.105:/home/admin/study-assistant-app/backend/routers/
```

输入密码，等待上传完成。

### 步骤 2：SSH 登录服务器

```powershell
ssh admin@47.104.165.105
```

### 步骤 3：验证文件

```bash
ls -lh /home/admin/study-assistant-app/backend/routers/api_config.py
```

应该看到文件存在。

### 步骤 4：重启服务

```bash
# 停止旧服务
pkill -f 'uvicorn main:app'

# 等待 2 秒
sleep 2

# 启动新服务
cd /home/admin/study-assistant-app/backend
nohup venv/bin/python3 venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &

# 等待 3 秒
sleep 3

# 查看日志（可选）
tail -f /tmp/uvicorn.log
```

按 `Ctrl+C` 退出日志查看。

### 步骤 5：测试 API

```bash
curl http://localhost:8000/api/api-config/config-status
```

应该返回 JSON 数据（可能是 401 未授权，这是正常的）。

### 步骤 6：退出服务器

```bash
exit
```

## 测试

1. 打开应用
2. 进入：我的 → AI 模型配置
3. 404 错误应该消失了

## 如果还是 404

检查服务器日志：

```bash
ssh admin@47.104.165.105
tail -100 /tmp/uvicorn.log
```

查找是否有错误信息。

## 常见问题

### Q: scp 上传失败？
A: 检查：
- 网络连接是否正常
- 服务器 IP 是否正确
- 密码是否正确
- 本地文件路径是否正确

### Q: 服务重启后还是 404？
A: 可能原因：
- 文件没有上传成功
- 服务没有正确重启
- 路由没有注册

检查 main.py 是否有这一行：
```python
app.include_router(api_config.router, prefix="/api/api-config", tags=["api-config"])
```

### Q: 如何确认服务是否在运行？
A: 
```bash
ssh admin@47.104.165.105
ps aux | grep uvicorn
```

应该看到 uvicorn 进程。

## 完成

修复完成后，API 配置页面应该能正常使用了！
