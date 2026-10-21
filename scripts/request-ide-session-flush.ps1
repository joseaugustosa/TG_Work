# Pede ao TG Work IDE Session (Cursor / VS Code) para gravar a sessao actual.
# A extensao detecta o ficheiro em %LOCALAPPDATA%\TG Work\ide-sessions\flush-request.json
# Uso:
#   .\scripts\request-ide-session-flush.ps1
#   .\scripts\request-ide-session-flush.ps1 -Reason publish -Source TgWork

param(
  [string]$Reason = 'external',
  [string]$Source = ''
)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:LOCALAPPDATA 'TG Work\ide-sessions'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$path = Join-Path $dir 'flush-request.json'
$atMs = [int64]([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalMilliseconds
$payload = @{
  reason = $Reason
  source = $Source
  atMs   = $atMs
} | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText($path, $payload)
Write-Host "Pedido de flush IDE escrito: $path ($Reason)"
