# 部署 v1.2.0 到服务器
param(
    [string]$ServerUser = "admin",
    [string]$ServerIP = "47.104.165.105"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy v1.2.0 to Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查本地文件
Write-Host "[1/6] Checking local files..." -ForegroundColor Yellow
if (!(Test-Path "backend/routers/api_config.py")) {
    Write-Host "Error: backend/routers/api_config.py not found!" -ForegroundColor Red
    exit 1
}
Write-Host "Done: Local files OK" -ForegroundColor Green
Write-Host ""

# 2. 上传 api_config.py 到服务器
Write-Host "[2/6] Uploading api_config.py to server..." -ForegroundColor Yellow
scp backend/routers/api_config.py "${ServerUser}@${ServerIP}:/home/admin/study-assistant-app/backend/routers/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Done: api_config.py uploaded" -ForegroundColor Green
} else {
    Write-Host "Error: Failed to upload api_config.py" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 3. 拉取最新代码
Write-Host "[3/6] Pulling latest code on server..." -ForegroundColor Yellow
ssh "${ServerUser}@${ServerIP}" "cd /home/admin/study-assistant-app && git pull origin master"
Write-Host "Done: Code updated" -ForegroundColor Green
Write-Host ""

# 4. 更新 .env 文件
Write-Host "[4/6] Updating .env on server..." -ForegroundColor Yellow
$envUpdate = @'
cd /home/admin/study-assistant-app/backend
cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
sed -i 's/^APP_VERSION=.*/APP_VERSION=1.2.0/' .env
sed -i 's|^APP_DOWNLOAD_URL=.*|APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v1.2.0.apk|' .env
sed -i '/^APP_CHANGELOG=/d' .env
cat >> .env << 'EOFMARKER'
APP_CHANGELOG=✨ 新增 API 配置功能：支持自定义 API Key\n🔧 移除付费模块，改为开源模式\n🔒 增强 API Key 安全存储\n🎨 优化聊天气泡UI，改为渐变背景\n🛠️ 工具箱支持自定义排序\n📱 后台保活优化，AI 输出和下载不再中断
EOFMARKER
echo "✓ .env updated"
grep APP_VERSION .env
grep APP_DOWNLOAD_URL .env
'@

ssh "${ServerUser}@${ServerIP}" $envUpdate
Write-Host "Done: .env updated" -ForegroundColor Green
Write-Host ""

# 5. 重启服务
Write-Host "[5/6] Restarting backend service..." -ForegroundColor Yellow
$restartCmd = @'
pkill -f 'uvicorn main:app'
sleep 2
cd /home/admin/study-assistant-app/backend
nohup /home/admin/study-assistant-app/backend/venv/bin/python3 /home/admin/study-assistant-app/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &
echo "✓ Service restarted"
'@

ssh "${ServerUser}@${ServerIP}" $restartCmd
Start-Sleep -Seconds 5
Write-Host "Done: Service restarted" -ForegroundColor Green
Write-Host ""

# 6. 验证部署
Write-Host "[6/6] Verifying deployment..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get
    Write-Host "Done: Deployment verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Version Info:" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Version: $($response.version)" -ForegroundColor White
    Write-Host "Min Version: $($response.minVersion)" -ForegroundColor White
    Write-Host "Download URL: $($response.downloadUrl)" -ForegroundColor White
    Write-Host ""
    Write-Host "Changelog:" -ForegroundColor Cyan
    Write-Host "$($response.changelog)" -ForegroundColor White
    Write-Host ""
    
    if ($response.version -eq "1.2.0") {
        Write-Host "✓ Version 1.2.0 deployed successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠ Version mismatch: expected 1.2.0, got $($response.version)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Warning: Could not verify deployment" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "The service may still be restarting. Try manually:" -ForegroundColor Yellow
    Write-Host "curl http://${ServerIP}:8000/api/app/version" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test API config: http://47.104.165.105:8000/api/api-config/config-status" -ForegroundColor White
Write-Host "2. Open the app and check for update prompt" -ForegroundColor White
Write-Host "3. Test new features: chat bubble UI, toolkit sorting" -ForegroundColor White
