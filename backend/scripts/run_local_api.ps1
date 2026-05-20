# 本地启动 API（加载 backend/.env 后跑 uvicorn）
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$envFile = Join-Path (Get-Location) ".env"
if (-not (Test-Path $envFile)) {
    Write-Error "缺少 backend/.env"
}

Get-Content $envFile -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        if (-not [string]::IsNullOrEmpty($name)) {
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

Write-Host "DATABASE_URL set:" ([bool]$env:DATABASE_URL)
python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
