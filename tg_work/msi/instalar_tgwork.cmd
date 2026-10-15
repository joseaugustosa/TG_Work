@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "MSI="
if exist "TgWork.msi" set "MSI=TgWork.msi"
if not defined MSI if exist "TgWork-1.0.0.msi" set "MSI=TgWork-1.0.0.msi"
if not defined MSI (
  echo Nao encontrei TgWork.msi nesta pasta.
  echo Gere o MSI: execute build_msi.ps1
  pause
  exit /b 1
)
echo A abrir a instalacao com pedido de administrador (UAC^)... (%MSI%)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process msiexec.exe -ArgumentList @('/i', (Join-Path (Get-Location) '%MSI%')) -Verb RunAs -Wait"
exit /b %ERRORLEVEL%
