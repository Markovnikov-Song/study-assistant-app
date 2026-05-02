# 简单部署脚本 - 避免换行符问题
param(
    [string]$ServerUser = "admin",
    [string]$ServerIP = "47.104.165.105"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Simple Deploy v1.2.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 上传 api_config.py
Write-Host "[1/4] Uploading api_config.py..." -ForegroundColor Yellow
scp backend/routers/api_config.py "${ServerUser}@${ServerIP}:/home/admin/study-assistant-app/backend/routers/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Done" -ForegroundColor Green
} else {
    Write-Host "Failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 2. 更新 .env（分步执行，避免换行符问题）
Write-Host "[2/4] Updating .env..." -ForegroundColor Yellow
ssh "${ServerUser}@${ServerIP}" "cd /home/admin/study-assistant-app/backend && cp .env .env.backup"
ssh "${ServerUser}@${ServerIP}" "cd /home/admin/study-assistant-app/backend && sed -i 's/^APP_VERSION=.*/APP_VERSION=1.2.0/' .env"
ssh "${ServerUser}@${ServerIP}" "cd /home/admin/study-assistant-app/backend && sed -i 's|^APP_DOWNLOAD_URL=.*|APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v1.2.0.apk|' .env"
Write-Host "Done" -ForegroundColor Green
Write-Host ""

# 3. 停止旧服务
Write-Host "[3/4] Stopping old service..." -ForegroundColor Yellow
ssh "${ServerUser}@${ServerIP}" "pkill -f 'uvicorn main:app'"
Start-Sleep -Seconds 2
Write-Host "Done" -ForegroundColor Green
Write-Host ""

# 4. 启动新服务
Write-Host "[4/4] Starting new service..." -ForegroundColor Yellow
ssh "${ServerUser}@${ServerIP}" "cd /home/admin/study-assistant-app/backend && nohup venv/bin/python3 venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &"
Start-Sleep -Seconds 5
Write-Host "Done" -ForegroundColor Green
Write-Host ""

# 5. 测试
Write-Host "Testing API..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get
    Write-Host "✓ Version: $($response.version)" -ForegroundColor Green
    Write-Host "✓ Download URL: $($response.downloadUrl)" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not verify (service may still be starting)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: Open app and go to 我的 → AI 模型配置" -ForegroundColor Yellow
