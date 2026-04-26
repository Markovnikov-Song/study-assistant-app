param(
    [string]$Device = "",
    [int]$BackendPort = 8000,
    [switch]$NoFlutter
)

function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "   OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "   WARN: $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "   ERR: $msg" -ForegroundColor Red; exit 1 }

Write-Step "Detecting network scenario..."

$apiBaseUrl = $null
$scenario   = "unknown"

# 1. USB ADB
$adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (Test-Path $adbPath) {
    $adbDevices = & $adbPath devices 2>$null | Select-String "device$"
    if ($adbDevices) {
        Write-Ok "USB device found, running adb reverse..."
        & $adbPath reverse tcp:$BackendPort tcp:$BackendPort 2>$null | Out-Null
        $apiBaseUrl = "http://localhost:$BackendPort"
        $scenario   = "USB"
        Write-Ok "Scenario: USB -> API = $apiBaseUrl"
    }
}

# 2. PC hotspot (PC shares hotspot to phone)
if (-not $apiBaseUrl) {
    $hotspotAdapter = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and (
            $_.InterfaceDescription -match "Virtual" -or
            $_.InterfaceDescription -match "Hosted" -or
            $_.InterfaceDescription -match "Wi-Fi Direct" -or
            $_.Name -match "Local Area Connection\*" -or
            $_.Name -match "本地连接\*"
        )
    } | Where-Object {
        # 过滤掉 VMware 虚拟网卡
        $_.InterfaceDescription -notmatch "VMware"
    } | Select-Object -First 1

    if ($hotspotAdapter) {
        $hotspotIP = (Get-NetIPAddress -InterfaceIndex $hotspotAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        if ($hotspotIP) {
            $apiBaseUrl = "http://${hotspotIP}:${BackendPort}"
            $scenario   = "PC_HOTSPOT"
            Write-Ok "Scenario: PC hotspot -> phone accesses $apiBaseUrl"
            Write-Ok "Adapter: $($hotspotAdapter.InterfaceDescription)"
        }
    }
}

# 3. Phone hotspot (phone shares hotspot to PC)
if (-not $apiBaseUrl) {
    $wifiAdapters = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "Native 802.11"
    }
    foreach ($adapter in $wifiAdapters) {
        $ip = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        if ($ip -and ($ip -match "^192\.168\." -or $ip -match "^172\.20\.10\.")) {
            $apiBaseUrl = "http://${ip}:${BackendPort}"
            $scenario   = "PHONE_HOTSPOT"
            Write-Ok "Scenario: phone hotspot -> PC IP = $ip"
            break
        }
    }
}

# 4. Fallback
if (-not $apiBaseUrl) {
    $fallbackIP = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\." } |
        Select-Object -First 1).IPAddress
    if ($fallbackIP) {
        $apiBaseUrl = "http://${fallbackIP}:${BackendPort}"
        $scenario   = "FALLBACK"
        Write-Warn "Unknown scenario, using fallback IP: $apiBaseUrl"
    } else {
        $apiBaseUrl = "http://localhost:$BackendPort"
        $scenario   = "LOCALHOST"
        Write-Warn "No network detected, using localhost (emulator only)"
    }
}

Write-Host ""
Write-Host "  Scenario : $scenario" -ForegroundColor Cyan
Write-Host "  API URL  : $apiBaseUrl" -ForegroundColor Cyan
Write-Host ""

# Start backend
Write-Step "Starting backend on 0.0.0.0:$BackendPort"

$backendDir = Join-Path $PSScriptRoot "backend"
if (-not (Test-Path $backendDir)) { Write-Err "backend/ directory not found" }

$backendCmd = "Set-Location '$backendDir'; python -m uvicorn main:app --host 0.0.0.0 --port $BackendPort --reload"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd -WindowStyle Normal

Write-Ok "Backend started in new window, waiting 3s..."
Start-Sleep -Seconds 3

try {
    $r = Invoke-WebRequest -Uri "http://localhost:$BackendPort/api/health" -TimeoutSec 5 -ErrorAction Stop
    Write-Ok "Backend health check passed (HTTP $($r.StatusCode))"
} catch {
    Write-Warn "Backend health check failed (may still be starting...)"
}

# Start Flutter
if ($NoFlutter) {
    Write-Step "Skipping Flutter (-NoFlutter mode)"
    Write-Ok "Run manually: flutter run --dart-define=API_BASE_URL=$apiBaseUrl"
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Step "Starting Flutter"

$deviceArg = if ($Device) { "-d $Device" } else { "" }
$flutterCmd = "flutter run $deviceArg --dart-define=API_BASE_URL=$apiBaseUrl"

Write-Ok "Running: $flutterCmd"
Write-Host ""

Invoke-Expression $flutterCmd
