# 仅部署后端（拍照解题 / CAS 接线修复），不要求 APK
# 用法: .\deploy_backend.ps1
# 需本机已配置: ssh admin@47.104.165.105

$ErrorActionPreference = "Stop"
$ServerIP = "47.104.165.105"
$ServerUser = "admin"
$ProjectPath = "/home/admin/study-assistant-app"
$SshIdentityFile = "$env:USERPROFILE\.ssh\study_assistant_deploy_ed25519"
$sshBase = @("-i", $SshIdentityFile, "-o", "IdentitiesOnly=yes")
if (-not (Test-Path $SshIdentityFile)) { throw "SSH key not found: $SshIdentityFile" }

Write-Host ">>> Deploy backend to $ServerUser@${ServerIP}" -ForegroundColor Cyan

Write-Host "[1/3] git push (local)..." -ForegroundColor Yellow
git push origin master
if ($LASTEXITCODE -ne 0) { throw "git push failed" }

Write-Host "[2/3] git pull on server..." -ForegroundColor Yellow
$pullCmd = "cd $ProjectPath && git fetch origin master && git reset --hard origin/master && cd backend && . .venv/bin/activate && pip install -r requirements.txt -q"
ssh @sshBase "${ServerUser}@${ServerIP}" $pullCmd

Write-Host "[3/3] restart study-assistant service..." -ForegroundColor Yellow
$restartCmd = "if systemctl is-active --quiet study-assistant 2>/dev/null; then sudo systemctl restart study-assistant && sleep 3 && systemctl is-active study-assistant; else cd $ProjectPath/backend && pkill -f 'uvicorn main:app' || true; sleep 2; . .venv/bin/activate; nohup uvicorn main:app --host 0.0.0.0 --port 8000 > uvicorn.log 2>&1 & sleep 3; pgrep -af uvicorn; fi"
ssh @sshBase "${ServerUser}@${ServerIP}" $restartCmd

Write-Host "[verify] production health + photo solve (no auth -> expect 401 not 400)..." -ForegroundColor Yellow
try {
  $h = Invoke-RestMethod -Uri "https://www.study-assistant.cn/api/health" -TimeoutSec 15
  Write-Host "health: $($h | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
  Write-Host "health check failed: $_" -ForegroundColor Red
}

Write-Host "Done. Run e2e against prod after login:" -ForegroundColor Green
Write-Host '  $env:API_BASE="https://www.study-assistant.cn"; python backend/scripts/e2e_photo_solve_client.py' -ForegroundColor Gray
