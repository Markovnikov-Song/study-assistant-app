# Check Server Configuration Script
# Usage: .\check_server.ps1

$ServerIP = "47.104.165.105"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Checking Server Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Server IP: $ServerIP" -ForegroundColor Yellow
Write-Host ""

# Test if server is reachable
Write-Host "[1/3] Testing server connection..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://${ServerIP}:8000/api/health" -Method Get -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✓ Server is reachable" -ForegroundColor Green
    Write-Host "  Response: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Server is not reachable or backend is not running" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""

# Check version API
Write-Host "[2/3] Checking version API..." -ForegroundColor Yellow
try {
    $versionResponse = Invoke-RestMethod -Uri "http://${ServerIP}:8000/api/app/version" -Method Get -ErrorAction Stop
    Write-Host "✓ Version API is working" -ForegroundColor Green
    Write-Host "  Current Version: $($versionResponse.version)" -ForegroundColor Gray
    Write-Host "  Min Version: $($versionResponse.min_version)" -ForegroundColor Gray
    Write-Host "  Download URL: $($versionResponse.download_url)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Version API failed" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
}

Write-Host ""

# Provide SSH commands to find project path
Write-Host "[3/3] To find project path on server, run these commands:" -ForegroundColor Yellow
Write-Host ""
Write-Host "# SSH to server:" -ForegroundColor White
Write-Host "ssh root@$ServerIP" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Then run these commands to find the project:" -ForegroundColor White
Write-Host ""
Write-Host "# Method 1: Find by process" -ForegroundColor Gray
Write-Host "ps aux | grep uvicorn" -ForegroundColor Cyan
Write-Host "ps aux | grep python" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Method 2: Find by systemd service" -ForegroundColor Gray
Write-Host "systemctl status study-assistant" -ForegroundColor Cyan
Write-Host "systemctl cat study-assistant" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Method 3: Find by PM2" -ForegroundColor Gray
Write-Host "pm2 list" -ForegroundColor Cyan
Write-Host "pm2 info study-assistant" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Method 4: Search for main.py" -ForegroundColor Gray
Write-Host "find /root -name 'main.py' -path '*/backend/*' 2>/dev/null" -ForegroundColor Cyan
Write-Host "find /home -name 'main.py' -path '*/backend/*' 2>/dev/null" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Method 5: Check common locations" -ForegroundColor Gray
Write-Host "ls -la /root/study_assistant" -ForegroundColor Cyan
Write-Host "ls -la /root/study-assistant" -ForegroundColor Cyan
Write-Host "ls -la /home/*/study_assistant" -ForegroundColor Cyan
Write-Host "ls -la /opt/study_assistant" -ForegroundColor Cyan
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Copy and paste the SSH command above to connect to your server," -ForegroundColor Yellow
Write-Host "then run the commands to find your project path." -ForegroundColor Yellow
Write-Host ""
