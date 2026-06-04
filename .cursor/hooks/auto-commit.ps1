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

try {
    $porcelain = git status --porcelain 2>&1
    if (-not $porcelain -or ($porcelain | Measure-Object -Line).Lines -eq 0) {
        exit 0
    }

    # Nunca incluir ficheiros de credenciais comuns
    $secretPatterns = @(
        '.env',
        '.env.*',
        '**/credentials.json',
        '**/google-services.json',
        '**/*secret*',
        '**/*apikey*'
    )
    git add -A 2>&1 | Out-Null
    foreach ($pat in $secretPatterns) {
        git reset -q HEAD -- $pat 2>&1 | Out-Null
    }

    $still = git diff --cached --name-only 2>&1
    if (-not $still) {
        exit 0
    }

    $names = @($still | Select-Object -First 8)
    $summary = if ($names.Count -le 3) {
        ($names -join ', ')
    } else {
        "$($names[0]), $($names[1]) +$($names.Count - 2) mais"
    }
    $when = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $msg = "chore(auto): $summary ($when)"

    git commit -m $msg 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "TG_Work auto-commit: $msg"
    }
} finally {
    Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue
}

exit 0
