# Установка учебного режима PurpleSchool для OpenCode (Windows, PowerShell 5.1+).
#
#   .\install.ps1               агент student и 4 скилла глобально (копии)
#   .\install.ps1 -Default      плюс "default_agent": "student" в opencode.json
#   .\install.ps1 -Uninstall    удалить то, что поставил скрипт, и вернуть бэкапы
#
# Симлинки в Windows требуют прав администратора, поэтому файлы копируются:
# после git pull запустите скрипт ещё раз. Флаг -Copy оставлен для совместимости с install.sh.
#
# Если PowerShell не даёт запустить скрипт:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1

[CmdletBinding()]
param(
    [switch]$Default,
    [switch]$Copy,
    [switch]$Uninstall,
    [Alias('y')][switch]$Yes,
    [switch]$V1,
    [switch]$V2,
    [string]$ConfigDir
)

$ErrorActionPreference = 'Stop'

$Kit = 'purpleschool-learning-kit'
$Skills = @('hint-ladder', 'code-review', 'debug-coach', 'explain-code')
$Repo = $PSScriptRoot

if (-not $ConfigDir) {
    if ($env:OPENCODE_CONFIG_HOME) { $ConfigDir = $env:OPENCODE_CONFIG_HOME }
    elseif ($env:XDG_CONFIG_HOME) { $ConfigDir = Join-Path $env:XDG_CONFIG_HOME 'opencode' }
    else { $ConfigDir = Join-Path (Join-Path $HOME '.config') 'opencode' }
}

$StateDir = Join-Path $ConfigDir ".$Kit"
$Manifest = Join-Path $StateDir 'manifest.tsv'
$ConfigState = Join-Path $StateDir 'opencode-json.state'
$CreatedDirs = Join-Path $StateDir 'created-dirs'
$Utf8 = New-Object System.Text.UTF8Encoding($false)

function Ok($msg) { Write-Host "✓ $msg" }
function Info($msg) { Write-Host "  $msg" }
function Warn($msg) { Write-Warning $msg }
function Fail($msg) { Write-Host "✗ $msg" -ForegroundColor Red; exit 1 }

# Запись без BOM: PowerShell 5.1 с -Encoding UTF8 добавляет BOM, а JSON с BOM читается не везде.
function Write-Text($path, $text) { [System.IO.File]::WriteAllText($path, $text, $Utf8) }
function Read-Text($path) { [System.IO.File]::ReadAllText($path, $Utf8) }
function Get-Sum($path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash }

function Confirm-Replace($question) {
    if ($Yes) { return $true }
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        Warn 'Нет терминала для подтверждения — пропускаю. Запустите с -Yes, чтобы заменить.'
        return $false
    }
    $answer = Read-Host "$question [y/N]"
    return $answer -match '^[yYдД]'
}

function Read-Manifest {
    $items = @()
    if (Test-Path -LiteralPath $Manifest) {
        foreach ($line in (Read-Text $Manifest) -split "`n") {
            if (-not $line.Trim()) { continue }
            $f = $line.TrimEnd("`r") -split "`t"
            $items += [pscustomobject]@{ Kind = $f[0]; Dest = $f[1]; Mode = $f[2]; Backup = $f[3] }
        }
    }
    return , $items
}

function Read-State($path) {
    $state = @{}
    foreach ($line in (Read-Text $path) -split "`n") {
        $i = $line.IndexOf('=')
        if ($i -gt 0) { $state[$line.Substring(0, $i)] = $line.Substring($i + 1).TrimEnd("`r") }
    }
    return $state
}

# ---------------------------------------------------------------------------
# Удаление
# ---------------------------------------------------------------------------

function Restore-Config {
    if (-not (Test-Path -LiteralPath $ConfigState)) { return }
    $state = Read-State $ConfigState
    $file = $state['file']; $prev = $state['prev']

    if (-not (Test-Path -LiteralPath $file)) {
        Warn "$file не найден — нечего возвращать"
    }
    elseif ((Get-Sum $file) -eq $state['sum']) {
        # Файл не меняли после установки — возвращаем бэкап как есть.
        if ($prev -eq '__nofile__') {
            Remove-Item -LiteralPath $file -Force
            Ok "Удалён $file (его не было до установки)"
        }
        else {
            Move-Item -LiteralPath "$file.bak" -Destination $file -Force
            Ok "Восстановлен $file из $file.bak"
        }
    }
    else {
        # Файл меняли после установки — трогаем только строку default_agent.
        $text = Read-Text $file
        if ($prev -eq '__none__') {
            $text = [regex]::Replace($text, '(?m)^[ \t]*"default_agent"[ \t]*:[ \t]*"student"[ \t]*,?[ \t]*\r?\n', '')
        }
        else {
            $text = [regex]::Replace($text, '"default_agent"\s*:\s*"student"', ('"default_agent": "' + $prev.Replace('$', '$$') + '"'))
        }
        Write-Text $file $text
        Ok "Из $file убрана только настройка default_agent: файл менялся после установки, бэкап оставлен в $file.bak"
    }
    Remove-Item -LiteralPath $ConfigState -Force
}

function Invoke-Uninstall {
    if (-not (Test-Path -LiteralPath $Manifest) -and -not (Test-Path -LiteralPath $ConfigState)) {
        Fail "Установка $Kit в $ConfigDir не найдена"
    }

    foreach ($item in (Read-Manifest)) {
        if (Test-Path -LiteralPath $item.Dest) {
            Remove-Item -LiteralPath $item.Dest -Recurse -Force
            Ok "Удалён $($item.Kind): $($item.Dest)"
        }
        if ($item.Backup -ne '-' -and (Test-Path -LiteralPath $item.Backup)) {
            Move-Item -LiteralPath $item.Backup -Destination $item.Dest
            Ok "Возвращён прежний $($item.Kind): $($item.Dest)"
        }
    }
    if (Test-Path -LiteralPath $Manifest) { Remove-Item -LiteralPath $Manifest -Force }

    Restore-Config

    $backupRoot = Join-Path $StateDir 'backup'
    if (Test-Path -LiteralPath $backupRoot) { Remove-Item -LiteralPath $backupRoot -Recurse -Force }
    $created = @()
    if (Test-Path -LiteralPath $CreatedDirs) {
        $created = @((Read-Text $CreatedDirs) -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })
        Remove-Item -LiteralPath $CreatedDirs -Force
    }
    Remove-EmptyDir $StateDir
    # Папки, которые создал установщик, удаляем, только если они пустые (с конца: сначала вложенные).
    [array]::Reverse($created)
    foreach ($dir in $created) { Remove-EmptyDir $dir }

    Write-Host ''
    Ok "$Kit удалён"
}

function Remove-EmptyDir($dir) {
    if ((Test-Path -LiteralPath $dir) -and -not (Get-ChildItem -LiteralPath $dir -Force)) {
        Remove-Item -LiteralPath $dir -Force
    }
}

# ---------------------------------------------------------------------------
# Установка
# ---------------------------------------------------------------------------

function Get-OpenCodeVersion {
    if ($V1) { Info 'Версия OpenCode задана флагом: V1'; return 1 }
    if ($V2) { Info 'Версия OpenCode задана флагом: V2'; return 2 }
    if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
        Fail 'OpenCode не найден. Установите его: https://opencode.ai — или укажите версию флагом -V1 / -V2'
    }
    $raw = (& opencode --version 2>$null | Select-Object -First 1)
    if ("$raw" -notmatch '(\d+)\.') {
        Fail "Не удалось определить версию OpenCode из «$raw». Укажите её флагом -V1 или -V2"
    }
    $version = 1
    if ([int]$Matches[1] -ge 2) { $version = 2 }
    Ok "OpenCode $raw → формат V$version"
    return $version
}

$script:NewManifest = @()
$script:OldManifest = @()
$script:BackupDir = ''

function Install-Item($kind, $src, $dest) {
    $backup = '-'
    $existing = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
    if ($existing) {
        $ours = $script:OldManifest | Where-Object { $_.Dest -eq $dest } | Select-Object -First 1
        if ($ours) {
            $backup = $ours.Backup
            Remove-Item -LiteralPath $dest -Recurse -Force
        }
        elseif (Confirm-Replace "$kind «$(Split-Path $dest -Leaf)» уже есть в $(Split-Path $dest -Parent). Заменить (старый уйдёт в бэкап)?") {
            $parentName = Split-Path (Split-Path $dest -Parent) -Leaf
            $backupParent = Join-Path $script:BackupDir $parentName
            New-Item -ItemType Directory -Force -Path $backupParent | Out-Null
            $backup = Join-Path $backupParent (Split-Path $dest -Leaf)
            Move-Item -LiteralPath $dest -Destination $backup
            Info "бэкап: $backup"
        }
        else {
            Warn "Пропущен ${kind}: $dest"
            return
        }
    }

    Copy-Item -LiteralPath $src -Destination $dest -Recurse
    $script:NewManifest += [pscustomobject]@{ Kind = $kind; Dest = $dest; Mode = 'copy'; Backup = $backup }
    Ok "${kind}: $dest"
}

function Set-DefaultAgent {
    $file = Join-Path $ConfigDir 'opencode.json'
    $jsonc = Join-Path $ConfigDir 'opencode.jsonc'
    if (-not (Test-Path -LiteralPath $file) -and (Test-Path -LiteralPath $jsonc)) { $file = $jsonc }

    if (Test-Path -LiteralPath $ConfigState) {
        # Уже ставили default_agent раньше — бэкап не перезаписываем, иначе потеряем исходный файл.
        $prev = (Read-State $ConfigState)['prev']
    }
    elseif (-not (Test-Path -LiteralPath $file)) {
        $prev = '__nofile__'
    }
    else {
        $m = [regex]::Match((Read-Text $file), '"default_agent"\s*:\s*"([^"]*)"')
        if ($m.Success) { $prev = $m.Groups[1].Value } else { $prev = '__none__' }
        Copy-Item -LiteralPath $file -Destination "$file.bak" -Force
        Info "бэкап: $file.bak"
    }

    $text = ''
    if (Test-Path -LiteralPath $file) { $text = Read-Text $file }
    if (($text -replace '\s', '') -in @('', '{}')) {
        $text = "{`n  `"`$schema`": `"https://opencode.ai/config.json`",`n  `"default_agent`": `"student`"`n}`n"
    }
    elseif ($text -match '"default_agent"') {
        $text = [regex]::Replace($text, '"default_agent"\s*:\s*"[^"]*"', '"default_agent": "student"')
    }
    else {
        # Вставляем отдельной строкой сразу после первой «{» — остальной файл не трогаем.
        $newline = "`n"
        if ($text -match "`r`n") { $newline = "`r`n" }
        $text = ([regex]'\{').Replace($text, '{' + $newline + '  "default_agent": "student",', 1)
    }
    Write-Text $file $text

    Write-Text $ConfigState "file=$file`nprev=$prev`nsum=$(Get-Sum $file)`n"
    Ok "default_agent: student → $file"
}

function Invoke-Install {
    Write-Host "Установка $Kit в $ConfigDir"
    $version = Get-OpenCodeVersion

    $created = @()
    foreach ($dir in @($ConfigDir, (Join-Path $ConfigDir 'agents'), (Join-Path $ConfigDir 'skills'))) {
        if (-not (Test-Path -LiteralPath $dir)) { $created += $dir }
    }
    foreach ($dir in @((Join-Path $ConfigDir 'agents'), (Join-Path $ConfigDir 'skills'), $StateDir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    if ($created.Count) {
        $old = ''
        if (Test-Path -LiteralPath $CreatedDirs) { $old = Read-Text $CreatedDirs }
        Write-Text $CreatedDirs ($old + (($created -join "`n") + "`n"))
    }

    $script:OldManifest = Read-Manifest
    $script:BackupDir = Join-Path (Join-Path $StateDir 'backup') (Get-Date -Format 'yyyyMMdd-HHmmss')

    foreach ($id in $Skills) {
        Install-Item 'скилл' (Join-Path (Join-Path $Repo 'skills') $id) (Join-Path (Join-Path $ConfigDir 'skills') $id)
    }
    $agentSrc = Join-Path (Join-Path $Repo 'agents') 'student.md'
    if ($version -eq 1) { $agentSrc = Join-Path (Join-Path (Join-Path $Repo 'agents') 'v1') 'student.md' }
    Install-Item 'агент' $agentSrc (Join-Path (Join-Path $ConfigDir 'agents') 'student.md')

    # Записи старого манифеста, которые не переустанавливали, сохраняем.
    foreach ($item in $script:OldManifest) {
        if (-not ($script:NewManifest | Where-Object { $_.Dest -eq $item.Dest })) { $script:NewManifest += $item }
    }
    $lines = $script:NewManifest | ForEach-Object { "$($_.Kind)`t$($_.Dest)`t$($_.Mode)`t$($_.Backup)" }
    Write-Text $Manifest (($lines -join "`n") + "`n")

    if ($Default) { Set-DefaultAgent }

    Write-Host ''
    Write-Host 'Готово. Как проверить:'
    Write-Host '  1. Откройте OpenCode в папке своего проекта: opencode'
    if ($Default) { Write-Host '  2. Агент student включится сам (он по умолчанию); Shift+Tab переключает агентов (в V1 — Tab).' }
    else { Write-Host '  2. Нажмите Shift+Tab (в V1 — Tab) — в списке агентов появится student.' }
    Write-Host '  3. Наберите / — в списке команд будут hint-ladder, code-review, debug-coach, explain-code.'
    if ($version -eq 2) {
        # OpenCode V2 держит фоновый сервис, который не замечает новые скиллы и агентов до перезапуска.
        Write-Host ''
        Write-Host 'Если OpenCode уже был запущен, перезапустите его фоновый сервис, иначе агент и скиллы не появятся:'
        Write-Host '  opencode service restart'
    }
    Write-Host "Обновление: git pull в $Repo и снова .\install.ps1"
}

if ($Uninstall) { Invoke-Uninstall } else { Invoke-Install }
