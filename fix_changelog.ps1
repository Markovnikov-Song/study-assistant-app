# Fix changelog encoding on server
param(
    [string]$ServerUser = "admin",
    [string]$ServerIP = "47.104.165.105"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Changelog Encoding on Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Updating changelog with proper encoding..." -ForegroundColor Yellow

# Create a temporary file with the correct changelog
$tempFile = [System.IO.Path]::GetTempFileName()
$changelog = "✨ 新增 API 配置功能：支持自定义 API Key\n🔧 移除付费模块，改为开源模式\n🔒 增强 API Key 安全存储"

# Write the changelog update command to temp file
$updateScript = @"
cd /home/admin/study-assistant-app/backend
cp .env .env.backup
sed -i '/^APP_CHANGELOG=/d' .env
echo 'APP_CHANGELOG=$changelog' >> .env
echo "✓ Changelog updated"
grep APP_CHANGELOG .env
"@

Set-Content -Path $tempFile -Value $updateScript -Encoding UTF8

# Upload and execute the script
scp $tempFile "${ServerUser}@${ServerIP}:/tmp/update_changelog.sh"
ssh "${ServerUser}@${ServerIP}" "bash /tmp/update_changelog.sh"

Remove-Item $tempFile
Write-Host "Done: Changelog updated" -ForegroundColor Green
Write-Host ""

Write-Host "[2/3] Restarting backend service..." -ForegroundColor Yellow
$restartCmd = @"
pkill -f 'uvicorn main:app'
sleep 2
cd /home/admin/study-assistant-app/backend
nohup /home/admin/study-assistant-app/backend/venv/bin/python3 /home/admin/study-assistant-app/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &
echo "✓ Service restarted"
"@

ssh "${ServerUser}@${ServerIP}" $restartCmd
Start-Sleep -Seconds 5
Write-Host "Done: Service restarted" -ForegroundColor Green
Write-Host ""

Write-Host "[3/3] Verifying deployment..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get
    Write-Host "Done: Deployment verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "Version Info:" -ForegroundColor Cyan
    Write-Host "Version: $($response.version)" -ForegroundColor White
    Write-Host "Min Version: $($response.minVersion)" -ForegroundColor White
    Write-Host "Download URL: $($response.downloadUrl)" -ForegroundColor White
    Write-Host "Changelog: $($response.changelog)" -ForegroundColor White
} catch {
    Write-Host "Warning: Could not verify deployment" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Changelog Fix Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
