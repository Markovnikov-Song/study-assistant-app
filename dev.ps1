# dev.ps1 — 一键启动开发环境（后端 + 前端）
# 放在项目根目录，在此目录下运行：.\dev.ps1
#
# 自动判断两种热点场景：
#   场景 A：电脑开热点给手机  → 手机访问电脑 IP（192.168.137.1 或类似）
#   场景 B：手机开热点给电脑  → 手机和电脑在同一热点网络，电脑用分配到的 IP
#   场景 C：USB 调试          → adb reverse 端口转发，用 localhost

param(
    [string]$Device = "",     # 指定 Flutter 设备 ID（留空自动选）
    [int]$BackendPort = 8000,
    [switch]$NoFlutter        # 只启动后端
)

function Write-Step($msg) { Write-Host "`n▶  $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   ✓ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "   ⚠ $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "   ✗ $msg" -ForegroundColor Red; exit 1 }

# ── 场景检测 ──────────────────────────────────────────────────────────────────
Write-Step "检测网络场景"

$apiBaseUrl = $null
$scenario   = "unknown"

# 1. 优先检查 USB 调试（ADB）
$adb = Get-Command adb -ErrorAction SilentlyContinue
if ($adb) {
    $adbDevices = adb devices 2>$null | Select-String "device$"
    if ($adbDevices) {
        Write-Ok "检测到 USB 调试设备，执行 adb reverse tcp:$BackendPort tcp:$BackendPort"
        adb reverse tcp:$BackendPort tcp:$BackendPort 2>$null | Out-Null
        $apiBaseUrl = "http://localhost:$BackendPort"
        $scenario   = "USB"
        Write-Ok "场景：USB 调试 → API = $apiBaseUrl"
    }
}

# 2. 检测电脑开热点（Windows Mobile Hotspot）
if (-not $apiBaseUrl) {
    # Windows 热点虚拟适配器的接口描述通常含 "Virtual" 或 "Hosted"
    # 热点 IP 默认是 192.168.137.1，也可能是其他网段
    $hotspotAdapter = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and (
            $_.InterfaceDescription -match "Virtual" -or
            $_.InterfaceDescription -match "Hosted" -or
            $_.Name -match "Local Area Connection\*"
        )
    } | Select-Object -First 1

    if ($hotspotAdapter) {
        $hotspotIP = (Get-NetIPAddress -InterfaceIndex $hotspotAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        if ($hotspotIP) {
            $apiBaseUrl = "http://${hotspotIP}:${BackendPort}"
            $scenario   = "PC_HOTSPOT"
            Write-Ok "场景：电脑开热点给手机 → 手机访问 $apiBaseUrl"
            Write-Ok "适配器：$($hotspotAdapter.InterfaceDescription)"
        }
    }
}

# 3. 检测手机开热点（电脑连接手机热点）
if (-not $apiBaseUrl) {
    # 手机热点：电脑通过 WiFi 连接，IP 由手机 DHCP 分配
    # Android 热点默认 192.168.43.x，iOS 热点默认 172.20.10.x
    $wifiAdapters = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "Native 802.11"
    }

    foreach ($adapter in $wifiAdapters) {
        $ip = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        if ($ip -and ($ip -match "^192\.168\." -or $ip -match "^172\.20\.10\.")) {
            $apiBaseUrl = "http://${ip}:${BackendPort}"
            $scenario   = "PHONE_HOTSPOT"
            Write-Ok "场景：手机开热点给电脑 → 电脑 IP = $ip"
            Write-Ok "WiFi 适配器：$($adapter.Name)"
            break
        }
    }
}

# 4. 兜底：取任意非回环 IPv4
if (-not $apiBaseUrl) {
    $fallbackIP = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\." } |
        Select-Object -First 1).IPAddress
    if ($fallbackIP) {
        $apiBaseUrl = "http://${fallbackIP}:${BackendPort}"
        $scenario   = "FALLBACK"
        Write-Warn "未识别热点场景，使用兜底 IP：$apiBaseUrl"
    } else {
        $apiBaseUrl = "http://localhost:$BackendPort"
        $scenario   = "LOCALHOST"
        Write-Warn "未检测到网络，使用 localhost（仅模拟器可用）"
    }
}

# ── 显示场景摘要 ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │  场景：$scenario" -ForegroundColor Cyan
Write-Host "  │  API：$apiBaseUrl" -ForegroundColor Cyan
if ($scenario -eq "PHONE_HOTSPOT") {
    Write-Host "  │  提示：手机和电脑已在同一热点网络 ✓" -ForegroundColor Green
} elseif ($scenario -eq "PC_HOTSPOT") {
    Write-Host "  │  提示：手机连接电脑热点后即可访问 ✓" -ForegroundColor Green
} elseif ($scenario -eq "USB") {
    Write-Host "  │  提示：USB 调试，端口转发已配置 ✓" -ForegroundColor Green
}
Write-Host "  └─────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

# ── 启动后端 ──────────────────────────────────────────────────────────────────
Write-Step "启动后端 (0.0.0.0:$BackendPort)"

$backendDir = Join-Path $PSScriptRoot "backend"
if (-not (Test-Path $backendDir)) { Write-Err "找不到 backend/ 目录" }

$backendCmd = "Set-Location '$backendDir'; python -m uvicorn main:app --host 0.0.0.0 --port $BackendPort --reload"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd -WindowStyle Normal

Write-Ok "后端已在新窗口启动，等待 3 秒..."
Start-Sleep -Seconds 3

# 健康检查
try {
    $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Ok "后端健康检查通过 (HTTP $($r.StatusCode))"
} catch {
    Write-Warn "后端健康检查失败（可能还在启动中，继续...）"
}

# ── 启动 Flutter ──────────────────────────────────────────────────────────────
if ($NoFlutter) {
    Write-Step "跳过 Flutter（-NoFlutter 模式）"
    Write-Ok "手动运行：flutter run --dart-define=API_BASE_URL=$apiBaseUrl"
    Read-Host "`n按 Enter 退出"
    exit 0
}

Write-Step "启动 Flutter"

$deviceArg = if ($Device) { "-d $Device" } else { "" }
$flutterCmd = "flutter run $deviceArg --dart-define=API_BASE_URL=$apiBaseUrl"

Write-Ok "执行：$flutterCmd"
Write-Host ""

Invoke-Expression $flutterCmd
