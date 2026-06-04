# Deploy Flutter Web build to the server.
# Usage:
#   .\deploy_web_to_server.ps1
#   .\deploy_web_to_server.ps1 -ApiBaseUrl "https://www.study-assistant.cn" -ServerUser "admin"
#   .\deploy_web_to_server.ps1 -ServerUser "admin" -SkipBuild

param(
    [string]$ServerIP = "47.104.165.105",
    [string]$ServerUser = "admin",
    [string]$ApiBaseUrl = "",
    [string]$RemoteWebRoot = "/var/www/study-assistant-web",
    [string]$SshIdentityFile = "$env:USERPROFILE\.ssh\study_assistant_deploy_ed25519",
    [switch]$SkipBuild
)

$sshBase = @("-i", $SshIdentityFile, "-o", "IdentitiesOnly=yes")
if (-not (Test-Path $SshIdentityFile)) {
    throw "SSH key not found: $SshIdentityFile"
}

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploy Flutter Web" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($ApiBaseUrl) {
    Write-Host "API_BASE_URL: $ApiBaseUrl" -ForegroundColor Gray
} else {
    Write-Host "API_BASE_URL: <same-origin>" -ForegroundColor Gray
}
Write-Host "Remote: ${ServerUser}@${ServerIP}:${RemoteWebRoot}" -ForegroundColor Gray
Write-Host ""

if ($SkipBuild) {
    Write-Host "[1/4] Skipping Flutter Web build..." -ForegroundColor Yellow
} else {
    Write-Host "[1/4] Building Flutter Web..." -ForegroundColor Yellow
    if ($ApiBaseUrl) {
        flutter build web --release --dart-define=API_BASE_URL=$ApiBaseUrl
    } else {
        flutter build web --release
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter Web build failed: flutter exited with code $LASTEXITCODE"
    }
}

if (-not (Test-Path "build\web\index.html")) {
    throw "Flutter Web build failed: build\web\index.html not found"
}

# SPA fallback for GoRouter path URLs. Static hosts such as GitHub Pages need
# unknown paths to return the Flutter entrypoint instead of a bare 404.
Copy-Item "build\web\index.html" "build\web\404.html" -Force

$archive = "build\study-assistant-web.tar.gz"
if (Test-Path $archive) {
    Remove-Item $archive -Force
}

Write-Host "[2/4] Packing build/web..." -ForegroundColor Yellow
tar -czf $archive -C build\web .

Write-Host "[3/4] Uploading archive..." -ForegroundColor Yellow
scp @sshBase $archive "${ServerUser}@${ServerIP}:/tmp/study-assistant-web.tar.gz"
if ($LASTEXITCODE -ne 0) {
    throw "Upload failed: scp exited with code $LASTEXITCODE"
}

Write-Host "[4/4] Publishing on server..." -ForegroundColor Yellow
$remoteScript = "WEB_ROOT='$RemoteWebRoot'; case `"`$WEB_ROOT`" in /var/www/*) ;; *) echo refuse; exit 1 ;; esac; sudo mkdir -p `"`$WEB_ROOT`"; sudo find `"`$WEB_ROOT`" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; sudo tar -xzf /tmp/study-assistant-web.tar.gz -C `"`$WEB_ROOT`"; sudo chown -R www-data:www-data `"`$WEB_ROOT`" 2>/dev/null || true; sudo chmod -R a+rX `"`$WEB_ROOT`"; rm -f /tmp/study-assistant-web.tar.gz; if command -v nginx >/dev/null 2>&1; then sudo nginx -t && (sudo systemctl reload nginx || sudo service nginx reload); fi"

ssh @sshBase "${ServerUser}@${ServerIP}" $remoteScript
if ($LASTEXITCODE -ne 0) {
    throw "Remote publish failed: ssh exited with code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Done. Open: https://study-assistant.cn" -ForegroundColor Green
