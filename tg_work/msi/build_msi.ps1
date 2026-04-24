# Gera o instalador: executar na raiz com Dot-source ou a partir de msi/:
#   Set-Location "caminho\para\tg_work\msi"; .\build_msi.ps1
# Requisitos: Flutter (Windows), WiX 7 (wix no PATH) — uma vez: wix eula accept wix7
$ErrorActionPreference = "Stop"
$tgWorkRoot = Split-Path -Parent $PSScriptRoot
Set-Location $tgWorkRoot
& flutter build windows --release
Set-Location $PSScriptRoot
$wix = Get-Command wix -ErrorAction SilentlyContinue
if (-not $wix) {
  $machine = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
  $user = [System.Environment]::GetEnvironmentVariable("Path", "User")
  $env:Path = "$machine;$user"
}
& wix build TgWork.wxs -o TgWork-1.0.0.msi -arch x64
$msi = Join-Path $PSScriptRoot "TgWork-1.0.0.msi"
Write-Host "Concluido: $msi ($([math]::Round((Get-Item $msi).Length / 1MB, 2)) MB)"
Write-Host "Instalacao: duplo clique nao basta com UAC. Use instalar_tgwork.cmd (pede admin) ou clique direito no MSI - Executar como administrador."
