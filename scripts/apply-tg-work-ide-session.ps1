# TG Work — aplicar definições IDE (VS Code + Cursor) para sessões aparecerem na Agenda.
# Uso (na raiz TG_Work): powershell -ExecutionPolicy Bypass -File scripts/apply-tg-work-ide-session.ps1

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent

$pkg = Join-Path $repoRoot "integrations\vscode-tg-work\package.json"
if (-not (Test-Path $pkg)) {
  Write-Error "Não encontrei integrations/vscode-tg-work (esperado em: $repoRoot)"
  exit 1
}

$ver = (Get-Content $pkg -Raw | ConvertFrom-Json).version
$vsix = Join-Path $repoRoot "integrations\vscode-tg-work\tg-work-ide-session-$ver.vsix"

if (-not (Test-Path $vsix)) {
  Push-Location (Join-Path $repoRoot "integrations\vscode-tg-work")
  try {
    npm run compile
    npx --yes @vscode/vsce package --no-dependencies --allow-missing-repository
  } finally {
    Pop-Location
  }
}

$apiKey = "AIzaSyCGFqhIWMzXuz_lkkzv8jL586UseBEB8Xw"

function Merge-TgWorkIdeUserSettings([string]$Path) {
  $parent = Split-Path $Path -Parent
  if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  if (Test-Path -LiteralPath $Path) {
    $o = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
  } else {
    $o = [pscustomobject]@{}
  }
  $pairs = [ordered]@{
    'tgWorkIde.syncToFirestore'               = $true
    'tgWorkIde.autoResolveFirestoreProject'  = $true
    'tgWorkIde.firebaseApiKey'               = $apiKey
    'tgWorkIde.firebaseProjectId'            = 'tg-work-2026'
    'tgWorkIde.minSessionSeconds'            = 30
    # Contagem automatica ao abrir pasta ou .code-workspace (nao so atalho)
    'tgWorkIde.onlyShortcutWorkspace'        = $false
    # Ao fazer git commit no workspace, gravar tempo IDE automaticamente
    'tgWorkIde.autoFlushOnGitCommit'         = $true
  }
  foreach ($name in $pairs.Keys) {
    $null = Add-Member -InputObject $o -NotePropertyName $name -NotePropertyValue $pairs[$name] -Force
  }
  $utf8bom = New-Object System.Text.UTF8Encoding $false
  $json = ($o | ConvertTo-Json -Depth 40)
  [System.IO.File]::WriteAllText($Path, $json, $utf8bom)
}

$codeUser = Join-Path $env:APPDATA "Code\User\settings.json"
$codeInsidersUser = Join-Path $env:APPDATA "Code - Insiders\User\settings.json"
$cursorUser = Join-Path $env:APPDATA "Cursor\User\settings.json"

Write-Host "Actualizar VS Code settings: $codeUser"
Merge-TgWorkIdeUserSettings $codeUser

Write-Host "Actualizar VS Code Insiders settings: $codeInsidersUser"
Merge-TgWorkIdeUserSettings $codeInsidersUser

Write-Host "Actualizar Cursor settings: $cursorUser"
Merge-TgWorkIdeUserSettings $cursorUser

function Resolve-VsCodeCli {
  foreach ($p in @(
      "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
      "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
      "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
    )) {
    if (Test-Path -LiteralPath $p) {
      return $p
    }
  }
  $cmd = Get-Command code -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }
  return $null
}

function Resolve-VsCodeInsidersCli {
  foreach ($p in @(
      "$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd",
      "$env:ProgramFiles\Microsoft VS Code Insiders\bin\code-insiders.cmd"
    )) {
    if (Test-Path -LiteralPath $p) {
      return $p
    }
  }
  $cmd = Get-Command code-insiders -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }
  return $null
}

function Resolve-CursorCli {
  foreach ($p in @(
      "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd",
      "$env:LOCALAPPDATA\Programs\Cursor\resources\app\bin\cursor.cmd"
    )) {
    if (Test-Path -LiteralPath $p) {
      return $p
    }
  }
  $cmd = Get-Command cursor -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source) {
    return $cmd.Source
  }
  return $null
}

function Install-VsixOrWarn([string]$Label, [string]$CliResolved, [string]$VsixPath) {
  Write-Host "Instalar extensão $ver em ${Label}…"
  if (-not $CliResolved) {
    Write-Warning "  ${Label}: CLI não encontrado. Abre o IDE → Extensions (Ctrl+Shift+X) → … → Install from VSIX → $VsixPath"
    return
  }
  Write-Host "  usando: $CliResolved"
  & $CliResolved --install-extension $VsixPath --force
}

Install-VsixOrWarn "VS Code (Stable)" (Resolve-VsCodeCli) $vsix
Install-VsixOrWarn "VS Code Insiders" (Resolve-VsCodeInsidersCli) $vsix
Install-VsixOrWarn "Cursor" (Resolve-CursorCli) $vsix

$reloadUris = @(
  'vscode://vscode/execute?command=workbench.action.reloadWindow'
  'vscode://vscode/window/reloadWindow'
  'cursor://vscode/execute?command=workbench.action.reloadWindow'
)
foreach ($u in $reloadUris) {
  try {
    Start-Process $u | Out-Null
  } catch {}
}

Write-Host ""
Write-Host "Configuração aplicada."
Write-Host "Passo que não consigo fazer por ti (credenciais): no VS Code e no Cursor, Ctrl+Shift+P →"
Write-Host "  TG Work IDE: iniciar sessão Firebase…"
Write-Host "Usa a mesma conta que na app TG Work."
Write-Host ""
