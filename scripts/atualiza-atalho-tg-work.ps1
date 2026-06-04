# Atualiza atalhos TG Work no ambiente de trabalho:
#   - Cursor - TG_Work.lnk  → só TG_Work.code-workspace (este repositório)
#   - TgWork.lnk            → app Windows (se instalada em Program Files)
# Uso (na raiz do repo): powershell -ExecutionPolicy Bypass -File scripts/atualiza-atalho-tg-work.ps1

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$workspaceFile = Join-Path $repoRoot "TG_Work.code-workspace"
if (-not (Test-Path -LiteralPath $workspaceFile)) {
    Write-Host "Erro: nao encontrei $workspaceFile" -ForegroundColor Red
    exit 1
}

$cursorExe = Join-Path $env:LOCALAPPDATA "Programs\cursor\Cursor.exe"
if (-not (Test-Path -LiteralPath $cursorExe)) {
    $cursorExe = "C:\Users\Utilizador\AppData\Local\Programs\cursor\Cursor.exe"
}
if (-not (Test-Path -LiteralPath $cursorExe)) {
    Write-Host "Erro: Cursor.exe nao encontrado." -ForegroundColor Red
    exit 1
}

$shell = New-Object -ComObject WScript.Shell
$desktops = @(
    [Environment]::GetFolderPath("Desktop"),
    (Join-Path $env:PUBLIC "Desktop")
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$okAny = $false
foreach ($desk in $desktops) {
    $path = Join-Path $desk "Cursor - TG_Work.lnk"
    try {
        $sc = $shell.CreateShortcut($path)
        $sc.TargetPath = $cursorExe
        $sc.Arguments = "`"$workspaceFile`""
        $sc.WorkingDirectory = $repoRoot
        $sc.Description = "Abrir apenas o projeto TG_Work (workspace multi-root)"
        $sc.Save()
        Write-Host "Atualizado: $path"
        Write-Host "  -> $workspaceFile"
        $okAny = $true
    } catch {
        Write-Host "(Ignorado: $desk) $_" -ForegroundColor DarkYellow
    }
}

# Atalho da app Flutter (opcional, se MSI instalou)
$tgExe = Join-Path ${env:ProgramFiles} "TgWork\tg_work.exe"
if (Test-Path -LiteralPath $tgExe) {
    $workDir = Split-Path $tgExe -Parent
    foreach ($desk in $desktops) {
        $path = Join-Path $desk "TgWork.lnk"
        try {
            $sc = $shell.CreateShortcut($path)
            $sc.TargetPath = $tgExe
            $sc.WorkingDirectory = $workDir
            $sc.Description = "TG Work (app Windows)"
            $sc.Save()
            Write-Host "Atualizado: $path"
            $okAny = $true
        } catch {
            Write-Host "(Ignorado TgWork.lnk: $desk)" -ForegroundColor DarkYellow
        }
    }
} else {
    Write-Host "Nota: TgWork.exe nao esta em Program Files - atalho da app nao alterado." -ForegroundColor DarkYellow
}

if (-not $okAny) {
    Write-Host "Erro: nao foi possivel gravar nenhum atalho." -ForegroundColor Red
    exit 1
}

exit 0
