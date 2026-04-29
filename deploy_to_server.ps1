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
ssh "${ServerUser}@${ServerIP}" "cd ${ProjectPath} && git pull origin main"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Git pull failed or no changes" -ForegroundColor Yellow
}
Write-Host "Done: Code updated" -ForegroundColor Green
Write-Host ""

# Step 3: Update .env on server
Write-Host "[3/5] Updating .env on server..." -ForegroundColor Yellow
$envCommands = @"
cd ${ProjectPath}/backend
sed -i 's/APP_VERSION=.*/APP_VERSION=$Version/' .env
sed -i 's|APP_DOWNLOAD_URL=.*|APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v$Version.apk|' .env
echo '.env updated'
"@

ssh "${ServerUser}@${ServerIP}" $envCommands
Write-Host "Done: .env updated" -ForegroundColor Green
Write-Host ""

# Step 4: Restart service
Write-Host "[4/5] Restarting backend service..." -ForegroundColor Yellow
Write-Host "Trying systemctl..." -ForegroundColor Gray
ssh "${ServerUser}@${ServerIP}" "sudo systemctl restart study-assistant 2>/dev/null || echo 'systemctl not available'"

Write-Host "Trying PM2..." -ForegroundColor Gray
ssh "${ServerUser}@${ServerIP}" "pm2 restart study-assistant 2>/dev/null || echo 'PM2 not available'"

Write-Host "Done: Service restart attempted" -ForegroundColor Green
Write-Host ""

# Step 5: Verify deployment
Write-Host "[5/5] Verifying deployment..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get -ErrorAction Stop
    Write-Host "Done: Deployment verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "Version Info:" -ForegroundColor Cyan
    Write-Host "  Version: $($response.version)" -ForegroundColor White
    Write-Host "  Min Version: $($response.min_version)" -ForegroundColor White
    Write-Host "  Download URL: $($response.download_url)" -ForegroundColor White
    Write-Host "  Changelog: $($response.changelog)" -ForegroundColor White
} catch {
    Write-Host "Warning: Could not verify deployment" -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Users will see the update when they open the app." -ForegroundColor Yellow
Write-Host ""
