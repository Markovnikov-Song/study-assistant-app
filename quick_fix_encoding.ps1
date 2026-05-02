# Quick fix for changelog encoding issue
param(
    [string]$ServerUser = "admin",
    [string]$ServerIP = "47.104.165.105"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Quick Fix: Changelog Encoding" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Uploading fix script to server..." -ForegroundColor Yellow
scp fix_server_encoding.sh "${ServerUser}@${ServerIP}:/tmp/"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Done: Script uploaded" -ForegroundColor Green
} else {
    Write-Host "Error: Failed to upload script" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "[2/3] Executing fix script on server..." -ForegroundColor Yellow
ssh "${ServerUser}@${ServerIP}" "bash /tmp/fix_server_encoding.sh"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Done: Fix script executed" -ForegroundColor Green
} else {
    Write-Host "Warning: Script execution may have issues" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[3/3] Verifying from local machine..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get
    Write-Host "Done: Verification successful" -ForegroundColor Green
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
    
    if ($response.changelog -match "[\u4e00-\u9fa5]") {
        Write-Host "✓ Chinese characters detected - encoding looks good!" -ForegroundColor Green
    } else {
        Write-Host "⚠ No Chinese characters detected - may still have encoding issues" -ForegroundColor Yellow
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
Write-Host "Fix Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
