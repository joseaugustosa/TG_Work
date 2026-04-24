@echo off
chcp 65001 >nul
cd /d "%~dp0"
if not exist "TgWork-1.0.0.msi" (
  echo Nao encontrei TgWork-1.0.0.msi nesta pasta.
  echo Gere o MSI: execute build_msi.ps1
  pause
  exit /b 1
)
echo A abrir a instalacao com pedido de administrador (UAC^)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process msiexec.exe -ArgumentList @('/i', (Join-Path (Get-Location) 'TgWork-1.0.0.msi')) -Verb RunAs -Wait"
exit /b %ERRORLEVEL%
