# Commit automatico apos o agente Cursor terminar (hook "stop").
# Corre na raiz do projeto; nao faz push.
$ErrorActionPreference = 'SilentlyContinue'

if ([Console]::IsInputRedirected) {
    $null = [Console]::In.ReadToEnd()
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
    exit 0
}

$lock = Join-Path $repoRoot '.git\tg-work-auto-commit.lock'
if (Test-Path -LiteralPath $lock) {
    $age = (Get-Date) - (Get-Item -LiteralPath $lock).LastWriteTime
    if ($age.TotalSeconds -lt 45) {
        exit 0
    }
}
New-Item -ItemType File -Force -Path $lock | Out-Null

function Test-SkipSecretPath([string]$rel) {
    $r = $rel -replace '\\', '/'
    return (
        $r -match '(^|/)\.env(\.|$|$)' -or
        $r -match 'credentials\.json$' -or
        $r -match 'google-services\.json$' -or
        $r -match '(?i)secret' -or
        $r -match '(?i)apikey'
    )
}

try {
    $lines = @(git status --porcelain 2>&1 | Where-Object { $_ -match '\S' })
    if ($lines.Count -eq 0) {
        exit 0
    }

    $staged = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        if ($line.Length -lt 4) { continue }
        $path = $line.Substring(3).Trim().Trim('"')
        if (-not $path -or (Test-SkipSecretPath $path)) { continue }
        git add -A -- $path 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $staged.Add($path)
        }
    }

    $cached = @(git diff --cached --name-only 2>&1 | Where-Object { $_ -match '\S' })
    if ($cached.Count -eq 0) {
        exit 0
    }

    $summary = if ($cached.Count -le 3) {
        ($cached -join ', ')
    } else {
        "$($cached[0]), $($cached[1]) +$($cached.Count - 2) mais"
    }
    $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $msg = "chore(auto): $summary ($when)"

    git -c core.editor=true commit -m $msg 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "TG_Work auto-commit: $msg"
    }
} finally {
    Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
}

exit 0
