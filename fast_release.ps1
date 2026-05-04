# Fast Release Script for Study Assistant App
# Usage: .\fast_release.ps1 -Version "1.2.1" -BuildNumber 3 -Changelog "Fix API type error"

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [int]$BuildNumber,
    
    [string]$Changelog = "Bug fixes and improvements"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🚀 Starting Fast Release v$Version+$BuildNumber" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Run local release script
Write-Host "`n[1/4] Building and pushing to Git..." -ForegroundColor Yellow
.\release.ps1 -Version $Version -BuildNumber $BuildNumber -Changelog $Changelog

# 2. Create GitHub Release
Write-Host "`n[2/4] Creating GitHub Release..." -ForegroundColor Yellow
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
$releaseTitle = "v$Version"
$releaseNotes = "Release v$Version`n`n$Changelog"

# Check if gh CLI exists
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh release create "v$Version" $apkPath --title $releaseTitle --notes $releaseNotes
    Write-Host "Done: GitHub Release created." -ForegroundColor Green
} else {
    Write-Host "Warning: GitHub CLI (gh) not found. Skipping auto release creation." -ForegroundColor Yellow
    Write-Host "Please upload $apkPath manually to GitHub." -ForegroundColor Gray
}

# 3. Deploy to Server
Write-Host "`n[3/4] Deploying to server..." -ForegroundColor Yellow
.\deploy_to_server.ps1 -Version $Version
Write-Host "Done: Server updated and restarted." -ForegroundColor Green

# 4. Success Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ✨ Release v$Version Successful!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. GitHub: https://github.com/Markovnikov-Song/study-assistant-app/releases" -ForegroundColor White
Write-Host "2. API: http://47.104.165.105:8000/api/app/version" -ForegroundColor White
Write-Host "3. App: Check for update prompt in your app!" -ForegroundColor White
