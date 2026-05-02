# Quick fix script - restart the server
param(
    [string]$ServerUser = "admin",
    [string]$ServerIP = "47.104.165.105"
)

Write-Host "Fixing server..." -ForegroundColor Yellow

# Single command to restart service
$cmd = "cd /home/admin/study-assistant-app/backend && nohup /home/admin/study-assistant-app/backend/venv/bin/python3 /home/admin/study-assistant-app/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 > /tmp/uvicorn.log 2>&1 &"

ssh "${ServerUser}@${ServerIP}" $cmd

Write-Host "Waiting for service to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "Testing..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get
    Write-Host "✓ Service is running!" -ForegroundColor Green
    Write-Host "  Version: $($response.version)" -ForegroundColor White
} catch {
    Write-Host "✗ Service not responding yet" -ForegroundColor Red
    Write-Host "  Wait a bit longer and try: .\test_version_api.ps1" -ForegroundColor Yellow
}
