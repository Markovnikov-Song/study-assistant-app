# Deploy to Server Script
# Usage: .\deploy_to_server.ps1 -Version "1.2.0"

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ServerIP = "47.104.165.105"
$ServerUser = "admin"
$ProjectPath = "/home/admin/study-assistant-app"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploy to Server: v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if APK exists
$apkPath = "backend\downloads\app-v$Version.apk"
if (-not (Test-Path $apkPath)) {
    Write-Host "Error: APK not found at $apkPath" -ForegroundColor Red
    Write-Host "Please build the APK first using release.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "APK found: $apkPath" -ForegroundColor Green
$apkSize = (Get-Item $apkPath).Length / 1MB
Write-Host "APK size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
Write-Host ""

# Step 1: Upload APK
Write-Host "[1/5] Uploading APK to server..." -ForegroundColor Yellow
Write-Host "Command: scp $apkPath ${ServerUser}@${ServerIP}:${ProjectPath}/backend/downloads/" -ForegroundColor Gray
scp $apkPath "${ServerUser}@${ServerIP}:${ProjectPath}/backend/downloads/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to upload APK" -ForegroundColor Red
    exit 1
}
Write-Host "Done: APK uploaded" -ForegroundColor Green
Write-Host ""

# Step 2: Update code on server
Write-Host "[2/5] Pulling latest code on server..." -ForegroundColor Yellow
ssh "${ServerUser}@${ServerIP}" "cd ${ProjectPath} && git pull origin master"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Git pull failed or no changes" -ForegroundColor Yellow
}
Write-Host "Done: Code updated" -ForegroundColor Green
Write-Host ""

# Step 3: Update .env on server
Write-Host "[3/5] Updating .env on server..." -ForegroundColor Yellow
$updateEnvScript = @"
cd ${ProjectPath}/backend && \
sed -i 's/APP_VERSION=.*/APP_VERSION=$Version/' .env && \
sed -i 's|APP_DOWNLOAD_URL=.*|APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v$Version.apk|' .env && \
sed -i 's/APP_CHANGELOG=.*/APP_CHANGELOG=✨ 新增 API 配置功能\\n🔧 移除付费模块\\n🔒 增强安全性/' .env && \
echo 'Updated .env:' && \
grep 'APP_VERSION\|APP_DOWNLOAD_URL' .env
"@

ssh "${ServerUser}@${ServerIP}" $updateEnvScript
Write-Host "Done: .env updated" -ForegroundColor Green
Write-Host ""

# Step 4: Restart service
Write-Host "[4/5] Restarting backend service..." -ForegroundColor Yellow
$restartScript = @"
echo 'Finding uvicorn process...' && \
ps aux | grep uvicorn | grep -v grep && \
echo 'Killing old process...' && \
pkill -f 'uvicorn main:app' && \
sleep 3 && \
echo 'Starting new process...' && \
cd ${ProjectPath}/backend && \
nohup ${ProjectPath}/backend/venv/bin/python3 ${ProjectPath}/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 & \
sleep 3 && \
echo 'Checking if service is running...' && \
ps aux | grep uvicorn | grep -v grep
"@

ssh "${ServerUser}@${ServerIP}" $restartScript
Write-Host "Done: Service restarted" -ForegroundColor Green
Write-Host ""

# Step 5: Verify deployment
Write-Host "[5/5] Verifying deployment..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get -ErrorAction Stop
    Write-Host "Done: Deployment verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "Version Info:" -ForegroundColor Cyan
    Write-Host "  Version: $($response.version)" -ForegroundColor White
    Write-Host "  Min Version: $($response.min_version)" -ForegroundColor White
    Write-Host "  Download URL: $($response.download_url)" -ForegroundColor White
    
    if ($response.version -eq $Version) {
        Write-Host ""
        Write-Host "✓ Version updated successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "✗ Version mismatch! Expected $Version but got $($response.version)" -ForegroundColor Red
        Write-Host "  The service may need more time to restart, or there was an error." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Warning: Could not verify deployment" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "The service may still be restarting. Wait a moment and check manually:" -ForegroundColor Yellow
    Write-Host "  curl http://47.104.165.105:8000/api/app/version" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test the version API: .\test_version_api.ps1" -ForegroundColor White
Write-Host "2. Open the app and check for update prompt" -ForegroundColor White
Write-Host ""
