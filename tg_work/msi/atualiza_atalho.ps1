# Atualiza ou cria atalhos TgWork no ambiente de trabalho do utilizador e no Public Desktop.
$ErrorActionPreference = "Stop"
$exe = Join-Path $env:ProgramFiles "TgWork\tg_work.exe"
if (-not (Test-Path -LiteralPath $exe)) {
    Write-Host "Erro: nao encontrei $exe Instala primeiro (MSI ou instalar_tgwork.cmd)." -ForegroundColor Red
    exit 1
}

$workDir = Split-Path $exe -Parent
$shell = New-Object -ComObject WScript.Shell
$desktops = @(
    [Environment]::GetFolderPath("Desktop"),
    (Join-Path $env:PUBLIC "Desktop")
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$okAny = $false
foreach ($desk in $desktops) {
    $path = Join-Path $desk "TgWork.lnk"
    try {
        $sc = $shell.CreateShortcut($path)
        $sc.TargetPath = $exe
        $sc.WorkingDirectory = $workDir
        $sc.Description = "TgWork"
        $sc.Save()
        Write-Host "Atualizado: $path"
        $okAny = $true
    } catch {
        Write-Host "(Ignorado, sem permissao ou pasta indisponivel: $desk)" -ForegroundColor DarkYellow
    }
}

if (-not $okAny) {
    Write-Host "Erro: nao foi possivel gravar nenhum atalho." -ForegroundColor Red
    exit 1
}

exit 0
