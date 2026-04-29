# 测试版本 API 脚本
# 用法: .\test_version_api.ps1

param(
    [string]$ServerUrl = "http://47.104.165.105:8000"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  测试版本 API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 测试版本接口
Write-Host "请求 URL: $ServerUrl/api/app/version" -ForegroundColor Yellow
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "$ServerUrl/api/app/version" -Method Get
    
    Write-Host "✓ 接口响应成功" -ForegroundColor Green
    Write-Host ""
    Write-Host "版本信息：" -ForegroundColor Cyan
    Write-Host "  当前版本: $($response.version)" -ForegroundColor White
    Write-Host "  最低版本: $($response.min_version)" -ForegroundColor White
    Write-Host "  下载地址: $($response.download_url)" -ForegroundColor White
    Write-Host "  更新日志:" -ForegroundColor White
    $changelog = $response.changelog -replace '\\n', "`n    "
    Write-Host "    $changelog" -ForegroundColor Gray
    Write-Host ""
    
    # 测试 APK 下载链接
    if ($response.download_url) {
        Write-Host "测试 APK 下载链接..." -ForegroundColor Yellow
        try {
            $headResponse = Invoke-WebRequest -Uri $response.download_url -Method Head -ErrorAction Stop
            $contentLength = $headResponse.Headers.'Content-Length'
            $sizeMB = [math]::Round($contentLength / 1MB, 2)
            Write-Host "✓ APK 可访问，大小: $sizeMB MB" -ForegroundColor Green
        } catch {
            Write-Host "✗ APK 无法访问: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
} catch {
    Write-Host "✗ 接口请求失败" -ForegroundColor Red
    Write-Host "错误信息: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
