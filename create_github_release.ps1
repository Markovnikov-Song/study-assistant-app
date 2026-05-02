# Create GitHub Release Script
# Usage: .\create_github_release.ps1 -Version "1.2.0"

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$apkPath = "backend\downloads\app-v$Version.apk"

# Check if APK exists
if (-not (Test-Path $apkPath)) {
    Write-Host "Error: APK not found at $apkPath" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Creating GitHub Release v$Version" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if gh CLI is installed
try {
    gh --version | Out-Null
} catch {
    Write-Host "Error: GitHub CLI (gh) is not installed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install it from: https://cli.github.com/" -ForegroundColor Yellow
    Write-Host "Or create the release manually on GitHub website" -ForegroundColor Yellow
    exit 1
}

# Release notes
$releaseNotes = @"
## ✨ 新功能
- 新增 AI 模型配置功能：支持用户自定义 API Key
- 支持共享配置模式（通过口令使用）

## 🔧 改进
- 移除付费模块，改为开源模式
- 增强 API Key 安全存储

## 📥 下载
下载下方的 APK 文件安装即可
"@

Write-Host "Creating release v$Version..." -ForegroundColor Yellow

# Create release with APK
gh release create "v$Version" `
    $apkPath `
    --title "伴学 v$Version - API 配置功能" `
    --notes $releaseNotes

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Release created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "View release at:" -ForegroundColor Yellow
    Write-Host "https://github.com/Markovnikov-Song/study-assistant-app/releases/tag/v$Version" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "✗ Failed to create release" -ForegroundColor Red
    Write-Host "Please create it manually on GitHub" -ForegroundColor Yellow
}

Write-Host ""
