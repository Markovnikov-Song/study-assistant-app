# Release Script for Study Assistant App
# Usage: .\release.ps1 -Version "1.2.0" -BuildNumber 3

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [int]$BuildNumber,
    
    [string]$Changelog = "Bug fixes and improvements"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Release Version: v$Version+$BuildNumber" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Update pubspec.yaml
Write-Host "[1/8] Updating pubspec.yaml..." -ForegroundColor Yellow
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw -Encoding UTF8
$pubspecContent = $pubspecContent -replace 'version: [\d\.]+\+\d+', "version: $Version+$BuildNumber"
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllText($pubspecPath, $pubspecContent, $Utf8NoBomEncoding)
Write-Host "Done: Version updated to $Version+$BuildNumber" -ForegroundColor Green

# 2. Clean old builds
Write-Host "`n[2/8] Cleaning old builds..." -ForegroundColor Yellow
flutter clean
Write-Host "Done: Clean completed" -ForegroundColor Green

# 3. Get dependencies
Write-Host "`n[3/8] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
Write-Host "Done: Dependencies fetched" -ForegroundColor Green

# 4. Build APK
Write-Host "`n[4/8] Building Release APK..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "Done: APK built successfully" -ForegroundColor Green

# 5. Copy APK
Write-Host "`n[5/8] Copying APK to downloads directory..." -ForegroundColor Yellow
$apkSource = "build\app\outputs\flutter-apk\app-release.apk"
$apkDest = "backend\downloads\app-v$Version.apk"
New-Item -ItemType Directory -Force -Path "backend\downloads" | Out-Null
Copy-Item $apkSource $apkDest -Force
Write-Host "Done: APK copied to $apkDest" -ForegroundColor Green

# 6. Update .env file
Write-Host "`n[6/8] Updating backend/.env..." -ForegroundColor Yellow
$envPath = "backend\.env"

# Check if file exists
if (-not (Test-Path $envPath)) {
    Write-Host "Warning: backend\.env not found, skipping update" -ForegroundColor Yellow
    Write-Host "You will need to update it manually on the server" -ForegroundColor Yellow
} else {
    $envContent = Get-Content $envPath -Raw -Encoding UTF8

    # Update version
    $envContent = $envContent -replace 'APP_VERSION=[\d\.]+', "APP_VERSION=$Version"
    # Update download URL
    $envContent = $envContent -replace 'APP_DOWNLOAD_URL=.*app-v[\d\.]+\.apk', "APP_DOWNLOAD_URL=http://47.104.165.105:8000/downloads/app-v$Version.apk"
    # Update changelog
    $changelogEscaped = $Changelog -replace '"', '\"'
    $envContent = $envContent -replace 'APP_CHANGELOG=.*', "APP_CHANGELOG=$changelogEscaped"

    [System.IO.File]::WriteAllText($envPath, $envContent, $Utf8NoBomEncoding)
    Write-Host "Done: .env file updated" -ForegroundColor Green
}

# 7. Git commit
Write-Host "`n[7/8] Committing to Git..." -ForegroundColor Yellow
git add .
$commitMessage = "release: v$Version - $Changelog"
git commit -m $commitMessage
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Git commit failed or no changes" -ForegroundColor Yellow
}

# Create tag
$tagMessage = "Version $Version"
git tag -a "v$Version" -m $tagMessage
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Git tag creation failed (may already exist)" -ForegroundColor Yellow
}

Write-Host "Done: Git commit completed" -ForegroundColor Green

# 8. Push to GitHub
Write-Host "`n[8/8] Pushing to GitHub..." -ForegroundColor Yellow
$pushChoice = Read-Host "Push to GitHub? (y/n)"
if ($pushChoice -eq 'y') {
    git push origin main
    git push origin "v$Version"
    Write-Host "Done: Pushed to GitHub" -ForegroundColor Green
} else {
    Write-Host "Skipped: Push to GitHub" -ForegroundColor Yellow
}

# Complete
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Release Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Upload APK to server:" -ForegroundColor White
Write-Host "   scp backend\downloads\app-v$Version.apk user@server:/path/to/backend/downloads/" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Update server .env file (or copy local .env)" -ForegroundColor White
Write-Host ""
Write-Host "3. Restart backend service:" -ForegroundColor White
Write-Host "   sudo systemctl restart study-assistant" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Verify version API:" -ForegroundColor White
Write-Host "   curl http://47.104.165.105:8000/api/app/version" -ForegroundColor Gray
Write-Host ""
