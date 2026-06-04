param(
  [string]$Configuration = "Release",
  [switch]$SkipInstaller
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$PubspecPath = Join-Path $Root "pubspec.yaml"
$BuildDir = Join-Path $Root "build\windows\x64\runner\$Configuration"
$ExePath = Join-Path $BuildDir "study_assistant_app.exe"
$InstallerScript = Join-Path $Root "installer\windows\study_assistant_app.iss"
$DistDir = Join-Path $Root "dist\windows"

function Get-AppVersion {
  $versionLine = Select-String -Path $PubspecPath -Pattern '^version:\s*(.+)$' | Select-Object -First 1
  if (-not $versionLine) {
    return "0.0.0"
  }
  return ($versionLine.Matches[0].Groups[1].Value -split '\+')[0].Trim()
}

function Find-InnoCompiler {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles(x86)\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate)) {
      return $candidate
    }
  }

  $fromPath = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
  if ($fromPath) {
    return $fromPath.Source
  }

  return $null
}

Push-Location $Root
try {
  $version = Get-AppVersion
  New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

  Write-Host "==> Building Windows $Configuration bundle..."
  flutter build windows --release

  if (-not (Test-Path $ExePath)) {
    throw "Windows executable not found: $ExePath"
  }

  Write-Host "==> Windows executable:"
  Write-Host "    $ExePath"

  if ($SkipInstaller) {
    Write-Host "==> Installer skipped."
    exit 0
  }

  $iscc = Find-InnoCompiler
  if (-not $iscc) {
    Write-Host "==> Inno Setup compiler was not found."
    Write-Host "    Install Inno Setup 6, then run this script again to create a setup exe."
    Write-Host "    Download: https://jrsoftware.org/isdl.php"
    exit 0
  }

  Write-Host "==> Building setup installer with Inno Setup..."
  & $iscc `
    "/DAppVersion=$version" `
    "/DSourceDir=$BuildDir" `
    "/DOutputDir=$DistDir" `
    $InstallerScript

  if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE"
  }

  Write-Host "==> Installer output:"
  Write-Host "    $DistDir"
}
finally {
  Pop-Location
}
