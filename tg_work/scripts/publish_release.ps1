# Cria um GitHub Release a parte com APK + MSI (nao usa Firebase Hosting).
# No fim, actualiza a extensao TG Work IDE Session no Cursor e VS Code
# (contagem de tempo automatica + sync Firestore), alem do APK/MSI.
#
# Uso (na pasta tg_work):
#   .\scripts\publish_release.ps1
#   .\scripts\publish_release.ps1 -Notes "Notas da release"
#   .\scripts\publish_release.ps1 -SkipBuild
#   .\scripts\publish_release.ps1 -SkipIdeExtension
#
# Tag = v{version}+{build} do pubspec.yaml (ex.: v1.2.0+3)
# Assets: tg_work.apk, TgWork.msi, tg-work-ide-session-*.vsix

param(
  [string]$Notes = "",
  [switch]$SkipBuild,
  [switch]$SkipIdeExtension
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Read-PubspecVersion {
  $yaml = Get-Content (Join-Path $root "pubspec.yaml") -Raw
  if ($yaml -notmatch '(?m)^version:\s*([0-9.]+)\+(\d+)') {
    throw "Nao encontrei version: x.y.z+build no pubspec.yaml"
  }
  return @{
    Version = $Matches[1]
    Build   = [int]$Matches[2]
  }
}

$ver = Read-PubspecVersion
$version = $ver.Version
$build = $ver.Build
$tag = "v$version+$build"
Write-Host "GitHub Release $tag"

if (-not $SkipBuild) {
  Write-Host "A gerar APK..."
  & flutter build apk --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build apk falhou" }

  Write-Host "A gerar Windows + MSI..."
  & powershell -ExecutionPolicy Bypass -File (Join-Path $root "msi\build_msi.ps1")
  if ($LASTEXITCODE -ne 0) { throw "build_msi.ps1 falhou" }
}

$apkSrc = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
$msiSrcCandidates = @(
  (Join-Path $root "msi\TgWork.msi"),
  (Join-Path $root "msi\TgWork-$version.msi"),
  (Join-Path $root "msi\TgWork-1.0.0.msi")
)
$msiSrc = $msiSrcCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not (Test-Path $apkSrc)) { throw "APK em falta: $apkSrc" }
if (-not $msiSrc) { throw "MSI em falta em msi\" }

$stage = Join-Path $root "build\release_stage"
New-Item -ItemType Directory -Force -Path $stage | Out-Null
$apkOut = Join-Path $stage "tg_work.apk"
$msiOut = Join-Path $stage "TgWork.msi"
Copy-Item $apkSrc $apkOut -Force
Copy-Item $msiSrc $msiOut -Force

$repoRoot = $root
if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
  $repoRoot = Split-Path -Parent $root
}

# Empacotar extensão IDE (Cursor / VS Code) para anexar à release
$ideExtDir = Join-Path $repoRoot "integrations\vscode-tg-work"
$idePkg = Join-Path $ideExtDir "package.json"
$vsixOut = $null
if ((Test-Path -LiteralPath $idePkg) -and -not $SkipIdeExtension) {
  $ideVer = (Get-Content -LiteralPath $idePkg -Raw | ConvertFrom-Json).version
  $vsixName = "tg-work-ide-session-$ideVer.vsix"
  $vsixOut = Join-Path $ideExtDir $vsixName
  Write-Host "A gerar VSIX da extensao IDE ($ideVer)..."
  Push-Location $ideExtDir
  try {
    & npm run compile
    if ($LASTEXITCODE -ne 0) { throw "npm run compile (extensao IDE) falhou" }
    & npx --yes @vscode/vsce package --no-dependencies --allow-missing-repository
    if ($LASTEXITCODE -ne 0) { throw "vsce package falhou" }
  } finally {
    Pop-Location
  }
  if (-not (Test-Path -LiteralPath $vsixOut)) {
    throw "VSIX em falta: $vsixOut"
  }
  Copy-Item $vsixOut (Join-Path $stage $vsixName) -Force
  $vsixOut = Join-Path $stage $vsixName
}

if ([string]::IsNullOrWhiteSpace($Notes)) {
  $Notes = @"
TgWork $version ($build)

- APK Android
- MSI Windows
- Extensao TG Work IDE Session (Cursor + VS Code) — contagem de tempo automatica
"@
}

Push-Location $repoRoot
try {
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & gh release view $tag 2>$null | Out-Null
  $exists = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $prevEap

  $assets = @($apkOut, $msiOut)
  if ($vsixOut -and (Test-Path -LiteralPath $vsixOut)) {
    $assets += $vsixOut
  }

  if ($exists) {
    Write-Host "Release $tag ja existe - a atualizar assets..."
    & gh release upload $tag @assets --clobber
    if ($LASTEXITCODE -ne 0) { throw "gh release upload falhou" }
  } else {
    Write-Host "A criar release $tag..."
    & gh release create $tag @assets --title "TgWork $version ($build)" --notes $Notes
    if ($LASTEXITCODE -ne 0) { throw "gh release create falhou" }
  }
} finally {
  Pop-Location
}

# Instalar / actualizar extensão no Cursor e VS Code deste PC (tempo IDE automatico)
if (-not $SkipIdeExtension) {
  $applyIde = Join-Path $repoRoot "scripts\apply-tg-work-ide-session.ps1"
  if (Test-Path -LiteralPath $applyIde) {
    Write-Host ""
    Write-Host "A actualizar TG Work IDE Session no Cursor e VS Code..."
    & powershell -NoProfile -ExecutionPolicy Bypass -File $applyIde
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "apply-tg-work-ide-session.ps1 terminou com codigo $LASTEXITCODE (release ja esta online)."
    }
  } else {
    Write-Warning "Script da extensao IDE em falta: $applyIde"
  }
}

$tagUrl = "https://github.com/joseaugustosa/TG_Work/releases/tag/" + [uri]::EscapeDataString($tag)
Write-Host ""
Write-Host "Release online:"
Write-Host "  $tagUrl"
Write-Host "  https://github.com/joseaugustosa/TG_Work/releases"
Write-Host ""
Write-Host "Contagem IDE: extensao instalada no Cursor/VS Code com syncToFirestore=true."
Write-Host "Se ainda nao houver login Firebase no IDE: Ctrl+Shift+P → TG Work IDE: iniciar sessão Firebase…"
