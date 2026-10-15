# Gera o instalador MSI alinhado com a versão do pubspec.yaml.
#   Set-Location "...\tg_work\msi"; .\build_msi.ps1
# Requisitos: Flutter (Windows), WiX 7 (wix no PATH)
$ErrorActionPreference = "Stop"
$tgWorkRoot = Split-Path -Parent $PSScriptRoot
Set-Location $tgWorkRoot

$yaml = Get-Content (Join-Path $tgWorkRoot "pubspec.yaml") -Raw
if ($yaml -notmatch '(?m)^version:\s*([0-9.]+)\+(\d+)') {
  throw "Não encontrei version no pubspec.yaml"
}
$version = $Matches[1]
$build = [int]$Matches[2]
# WiX ProductVersion: a.b.c.d
$wixVersion = "$version.0"
Write-Host "MSI versão $wixVersion (pubspec $version+$build)"

& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows falhou" }

Set-Location $PSScriptRoot
$wix = Get-Command wix -ErrorAction SilentlyContinue
if (-not $wix) {
  $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}

& wix build TgWork.wxs -o TgWork.msi -arch x64 "-dProductVersion=$wixVersion"
if ($LASTEXITCODE -ne 0) { throw "wix build falhou" }

# Cópia com nome antigo (atalhos/scripts) e versão
Copy-Item "TgWork.msi" "TgWork-$version.msi" -Force
if (Test-Path "TgWork-1.0.0.msi") {
  Copy-Item "TgWork.msi" "TgWork-1.0.0.msi" -Force
}

$msi = Join-Path $PSScriptRoot "TgWork.msi"
Write-Host "Concluido: $msi ($([math]::Round((Get-Item $msi).Length / 1MB, 2)) MB)"
Write-Host "Instalacao: usar instalar_tgwork.cmd (pede admin)."
