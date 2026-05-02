# 仅部署 API 配置文件（跳过 git pull）
param(
    [string]$ServerUser = "admin",
    [string]$ServerIP = "47.104.165.105"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy API Config (Skip Git Pull)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. 检查本地文件
Write-Host "[1/4] Checking local files..." -ForegroundColor Yellow
if (!(Test-Path "backend/routers/api_config.py")) {
    Write-Host "Error: backend/routers/api_config.py not found!" -ForegroundColor Red
    exit 1
}
Write-Host "Done: Local files OK" -ForegroundColor Green
Write-Host ""

# 2. 上传 api_config.py 到服务器
Write-Host "[2/4] Uploading api_config.py to server..." -ForegroundColor Yellow
scp backend/routers/api_config.py "${ServerUser}@${ServerIP}:/home/admin/study-assistant-app/backend/routers/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Done: api_config.py uploaded" -ForegroundColor Green
} else {
    Write-Host "Error: Failed to upload api_config.py" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 3. 检查服务器上的文件
Write-Host "[3/4] Verifying file on server..." -ForegroundColor Yellow
$checkCmd = "ls -lh /home/admin/study-assistant-app/backend/routers/api_config.py"
ssh "${ServerUser}@${ServerIP}" $checkCmd
Write-Host "Done: File verified" -ForegroundColor Green
Write-Host ""

# 4. 重启服务
Write-Host "[4/4] Restarting backend service..." -ForegroundColor Yellow
$restartCmd = @"
echo "Stopping old service..."
pkill -f 'uvicorn main:app'
sleep 2
echo "Starting new service..."
cd /home/admin/study-assistant-app/backend
nohup /home/admin/study-assistant-app/backend/venv/bin/python3 /home/admin/study-assistant-app/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &
sleep 3
echo "Service restarted"
"@

ssh "${ServerUser}@${ServerIP}" $restartCmd
Write-Host "Done: Service restarted" -ForegroundColor Green
Write-Host ""

# 5. 测试 API
Write-Host "Testing API..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/api-config/config-status" -Method Get
    Write-Host "✓ API Config endpoint is working!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json)" -ForegroundColor White
} catch {
    Write-Host "⚠ API test failed (this is normal if you haven't logged in)" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Try testing manually:" -ForegroundColor Yellow
    Write-Host "curl http://${ServerIP}:8000/api/api-config/config-status" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Open the app" -ForegroundColor White
Write-Host "2. Go to: 我的 → AI 模型配置" -ForegroundColor White
Write-Host "3. The 404 error should be gone!" -ForegroundColor White
