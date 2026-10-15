# Cria um GitHub Release a parte com APK + MSI (nao usa Firebase Hosting).
#
# Uso (na pasta tg_work):
#   .\scripts\publish_release.ps1
#   .\scripts\publish_release.ps1 -Notes "Notas da release"
#   .\scripts\publish_release.ps1 -SkipBuild
#
# Tag = v{version}+{build} do pubspec.yaml (ex.: v1.2.0+3)
# Assets: tg_work.apk, TgWork.msi

param(
  [string]$Notes = "",
  [switch]$SkipBuild
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

if ([string]::IsNullOrWhiteSpace($Notes)) {
  $Notes = @"
TgWork $version ($build)

- APK Android
- MSI Windows
"@
}

$repoRoot = $root
if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
  $repoRoot = Split-Path -Parent $root
}

Push-Location $repoRoot
try {
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  & gh release view $tag 2>$null | Out-Null
  $exists = ($LASTEXITCODE -eq 0)
  $ErrorActionPreference = $prevEap

  if ($exists) {
    Write-Host "Release $tag ja existe - a atualizar assets..."
    & gh release upload $tag $apkOut $msiOut --clobber
    if ($LASTEXITCODE -ne 0) { throw "gh release upload falhou" }
  } else {
    Write-Host "A criar release $tag..."
    & gh release create $tag $apkOut $msiOut --title "TgWork $version ($build)" --notes $Notes
    if ($LASTEXITCODE -ne 0) { throw "gh release create falhou" }
  }
} finally {
  Pop-Location
}

$tagUrl = "https://github.com/joseaugustosa/TG_Work/releases/tag/" + [uri]::EscapeDataString($tag)
Write-Host ""
Write-Host "Release online:"
Write-Host "  $tagUrl"
Write-Host "  https://github.com/joseaugustosa/TG_Work/releases"
