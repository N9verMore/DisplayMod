#==============================================================================
# DisplayMod installer / uninstaller for BLACK SOULS II (RPG Maker VX Ace)
#
# Встраивает DisplayMod.rb в скрипты игры (Data\Scripts.rvdata2) перед
# скриптом Main. Остальные скрипты копируются байт в байт, поэтому мод
# совместим с любыми переводами и патчами — они не затрагиваются.
#
#   powershell -ExecutionPolicy Bypass -File installer.ps1             установка
#   powershell -ExecutionPolicy Bypass -File installer.ps1 -Uninstall  удаление
#==============================================================================
param([switch]$Uninstall)

$ErrorActionPreference = 'Stop'
$ScriptName = 'DisplayMod'
$ScriptId   = 99001

function Say($ru, $en) { Write-Host "$ru"; Write-Host "  ($en)" -ForegroundColor DarkGray }
function Fail($ru, $en) {
    Write-Host ''
    Write-Host "ОШИБКА: $ru" -ForegroundColor Red
    Write-Host "ERROR: $en" -ForegroundColor Red
    exit 1
}

#------------------------------------------------------------------------------
# Ruby Marshal (только то, что встречается в Scripts.rvdata2)
#------------------------------------------------------------------------------
$script:B = $null
$script:P = 0
$script:Syms = $null

function Read-Byte { $v = $script:B[$script:P]; $script:P++; return [int]$v }

function Read-RInt {
    $c = Read-Byte
    if ($c -gt 127) { $c -= 256 }
    if ($c -eq 0) { return 0 }
    if ($c -ge 5) { return $c - 5 }
    if ($c -le -5) { return $c + 5 }
    $n = [Math]::Abs($c); [long]$v = 0
    for ($i = 0; $i -lt $n; $i++) { $v = $v -bor ([long](Read-Byte) -shl (8 * $i)) }
    if ($c -lt 0) { $v = $v - ([long]1 -shl (8 * $n)) }
    return $v
}

function Read-Raw {
    $n = Read-RInt
    $r = New-Object byte[] $n
    [Array]::Copy($script:B, $script:P, $r, 0, $n)
    $script:P += $n
    return ,$r
}

function Read-Symbol {
    $t = [char](Read-Byte)
    if ($t -eq ':') {
        $name = [Text.Encoding]::UTF8.GetString((Read-Raw))
        [void]$script:Syms.Add($name)
        return $name
    }
    if ($t -eq ';') { return $script:Syms[[int](Read-RInt)] }
    throw "unexpected symbol type '$t' at $($script:P - 1)"
}

function Skip-IvarValue {
    $t = [char](Read-Byte)
    switch ($t) {
        'T' { return }
        'F' { return }
        '"' { [void](Read-Raw); return }
        default { throw "unsupported ivar value '$t' at $($script:P - 1)" }
    }
}

# Строка: '"' или 'I"' + ivars (кодировка). Возвращает байты.
function Read-RString {
    $t = [char](Read-Byte)
    if ($t -eq '"') { return ,(Read-Raw) }
    if ($t -ne 'I') { throw "string expected, got '$t' at $($script:P - 1)" }
    if ([char](Read-Byte) -ne '"') { throw "string expected at $($script:P - 1)" }
    $raw = Read-Raw
    $n = Read-RInt
    for ($i = 0; $i -lt $n; $i++) { [void](Read-Symbol); Skip-IvarValue }
    return ,$raw
}

# Разбор файла: список записей {Name; Bytes (точная копия); Code (сжатый)}
function Parse-Scripts([byte[]]$data) {
    $script:B = $data; $script:P = 0
    $script:Syms = New-Object System.Collections.ArrayList
    if ($data.Length -lt 3 -or $data[0] -ne 4 -or $data[1] -ne 8) { throw 'not a Ruby Marshal 4.8 file' }
    $script:P = 2
    if ([char](Read-Byte) -ne '[') { throw 'array expected' }
    $count = Read-RInt
    $entries = New-Object System.Collections.ArrayList
    for ($k = 0; $k -lt $count; $k++) {
        $start = $script:P
        $symsBefore = $script:Syms.Count
        if ([char](Read-Byte) -ne '[') { throw "entry $k is not an array" }
        if ((Read-RInt) -ne 3) { throw "entry $k has unexpected size" }
        if ([char](Read-Byte) -ne 'i') { throw "entry $k id is not an integer" }
        [void](Read-RInt)
        $name = [Text.Encoding]::UTF8.GetString((Read-RString))
        $code = Read-RString
        $len = $script:P - $start
        $bytes = New-Object byte[] $len
        [Array]::Copy($data, $start, $bytes, 0, $len)
        [void]$entries.Add([pscustomobject]@{
            Name = $name; Bytes = $bytes; Code = $code
            DefinesSymbols = ($script:Syms.Count -gt $symsBefore)
        })
    }
    if ($script:P -ne $data.Length) { throw 'trailing data after scripts array' }
    return ,$entries
}

function Write-RInt([System.IO.Stream]$s, [long]$v) {
    if ($v -eq 0) { $s.WriteByte(0); return }
    if ($v -gt 0 -and $v -lt 123) { $s.WriteByte([byte]($v + 5)); return }
    if ($v -lt 0 -and $v -gt -124) { $s.WriteByte([byte](256 + $v - 5)); return }
    $bytes = New-Object System.Collections.Generic.List[byte]
    $x = $v
    for ($i = 1; $i -le 4; $i++) {
        $bytes.Add([byte]($x -band 0xFF)); $x = $x -shr 8
        if (($v -ge 0 -and $x -eq 0) -or ($v -lt 0 -and $x -eq -1)) {
            if ($v -ge 0) { $s.WriteByte([byte]$i) } else { $s.WriteByte([byte](256 - $i)) }
            $arr = $bytes.ToArray(); $s.Write($arr, 0, $arr.Length); return
        }
    }
    throw "integer too large: $v"
}

#------------------------------------------------------------------------------
# zlib (Ruby Zlib::Deflate / Inflate)
#------------------------------------------------------------------------------
function Get-Adler32([byte[]]$d) {
    [long]$a = 1; [long]$b = 0
    $i = 0; $n = $d.Length
    while ($i -lt $n) {
        $end = [Math]::Min($i + 5552, $n)
        for (; $i -lt $end; $i++) { $a += $d[$i]; $b += $a }
        $a %= 65521; $b %= 65521
    }
    return ($b -shl 16) -bor $a
}

function Compress-Zlib([byte[]]$d) {
    $ms = New-Object IO.MemoryStream
    $ms.WriteByte(0x78); $ms.WriteByte(0x9C)
    $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Compress, $true)
    $ds.Write($d, 0, $d.Length); $ds.Close()
    $ad = Get-Adler32 $d
    foreach ($sh in 24, 16, 8, 0) { $ms.WriteByte([byte](($ad -shr $sh) -band 0xFF)) }
    return ,$ms.ToArray()
}

function Expand-Zlib([byte[]]$z) {
    $src = [IO.MemoryStream]::new($z, 2, $z.Length - 6)
    $ds = New-Object IO.Compression.DeflateStream($src, [IO.Compression.CompressionMode]::Decompress)
    $out = New-Object IO.MemoryStream
    $buf = New-Object byte[] 65536
    while (($r = $ds.Read($buf, 0, $buf.Length)) -gt 0) { $out.Write($buf, 0, $r) }
    $res = $out.ToArray()
    $ad = Get-Adler32 $res
    $stored = ([long]$z[$z.Length - 4] -shl 24) -bor ([long]$z[$z.Length - 3] -shl 16) -bor ([long]$z[$z.Length - 2] -shl 8) -bor [long]$z[$z.Length - 1]
    if ($ad -ne $stored) { throw 'zlib checksum mismatch' }
    return ,$res
}

#------------------------------------------------------------------------------
# Сборка файла
#------------------------------------------------------------------------------
function Build-ModEntry([byte[]]$code, [System.Collections.ArrayList]$symsSoFar) {
    $s = New-Object IO.MemoryStream
    $s.WriteByte([byte][char]'['); Write-RInt $s 3
    $s.WriteByte([byte][char]'i'); Write-RInt $s $ScriptId
    $name = [Text.Encoding]::UTF8.GetBytes($ScriptName)
    $s.WriteByte([byte][char]'I'); $s.WriteByte([byte][char]'"')
    Write-RInt $s $name.Length; $s.Write($name, 0, $name.Length)
    Write-RInt $s 1
    $e = $symsSoFar.IndexOf('E')
    if ($e -ge 0) { $s.WriteByte([byte][char]';'); Write-RInt $s $e }
    else { $s.WriteByte([byte][char]':'); Write-RInt $s 1; $s.WriteByte([byte][char]'E') }
    $s.WriteByte([byte][char]'T')
    $z = Compress-Zlib $code
    $s.WriteByte([byte][char]'"'); Write-RInt $s $z.Length; $s.Write($z, 0, $z.Length)
    return ,$s.ToArray()
}

function Build-File($entries) {
    $s = New-Object IO.MemoryStream
    $s.WriteByte(4); $s.WriteByte(8); $s.WriteByte([byte][char]'[')
    Write-RInt $s $entries.Count
    foreach ($e in $entries) { $s.Write($e.Bytes, 0, $e.Bytes.Length) }
    return ,$s.ToArray()
}

# Символы, определённые записями до позиции idx (для ссылки на :E)
function Get-SymbolsBefore($entries, [int]$idx) {
    $data = Build-File ($entries | Select-Object -First $idx)
    $script:B = $data; $script:P = 3
    $script:Syms = New-Object System.Collections.ArrayList
    $count = Read-RInt
    for ($k = 0; $k -lt $count; $k++) {
        [void](Read-Byte); [void](Read-RInt); [void](Read-Byte); [void](Read-RInt)
        [void](Read-RString); [void](Read-RString)
    }
    return ,$script:Syms
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
$modDir  = $PSScriptRoot
$gameDir = Split-Path -Parent $modDir
$gameIni = Join-Path $gameDir 'Game.ini'

Write-Host '=== DisplayMod — BLACK SOULS II ===' -ForegroundColor Cyan
Write-Host "Папка игры / Game folder: $gameDir"
Write-Host ''

if (-not (Test-Path $gameIni) -or -not (Test-Path (Join-Path $gameDir 'Game.exe'))) {
    Fail 'Папка DisplayMod должна лежать в папке игры (рядом с Game.exe).' `
         'Put the DisplayMod folder into the game folder (next to Game.exe).'
}
$ini = Get-Content $gameIni
$lib = ($ini | Where-Object { $_ -match '^\s*Library\s*=' }) -replace '^\s*Library\s*=\s*', ''
if ($lib -notmatch 'RGSS3') {
    Fail "Игра не на RPG Maker VX Ace (Library=$lib)." "Not an RPG Maker VX Ace game (Library=$lib)."
}
$scriptsRel = ($ini | Where-Object { $_ -match '^\s*Scripts\s*=' }) -replace '^\s*Scripts\s*=\s*', ''
if (-not $scriptsRel) { $scriptsRel = 'Data\Scripts.rvdata2' }
$scriptsPath = Join-Path $gameDir $scriptsRel.Trim()
if (-not (Test-Path $scriptsPath)) {
    Fail "Не найден файл скриптов: $scriptsPath" "Scripts file not found: $scriptsPath"
}

$running = Get-Process -Name Game -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and ((Split-Path -Parent $_.Path) -eq $gameDir) }
if ($running) { Fail 'Сначала закройте игру.' 'Close the game first.' }

try {
    $data = [IO.File]::ReadAllBytes($scriptsPath)
    $entries = Parse-Scripts $data
} catch {
    Fail "Не удалось прочитать $scriptsRel ($($_.Exception.Message))." "Cannot read $scriptsRel ($($_.Exception.Message))."
}

$installed = @($entries | Where-Object { $_.Name -eq $ScriptName })
$clean = New-Object System.Collections.ArrayList
foreach ($e in $entries) { if ($e.Name -ne $ScriptName) { [void]$clean.Add($e) } }
foreach ($e in $installed) {
    if ($e.DefinesSymbols) {
        Fail 'Неожиданная структура файла скриптов, автоматическое изменение небезопасно.' `
             'Unexpected scripts file layout, refusing to modify it.'
    }
}

$backup = Join-Path $modDir 'Scripts.rvdata2.backup'

if ($Uninstall) {
    if ($installed.Count -eq 0) {
        Say 'Мод не установлен — делать нечего.' 'The mod is not installed, nothing to do.'
        exit 0
    }
    $out = Build-File $clean
    [IO.File]::WriteAllBytes("$scriptsPath.tmp", $out)
    [void](Parse-Scripts ([IO.File]::ReadAllBytes("$scriptsPath.tmp")))
    Move-Item -Force "$scriptsPath.tmp" $scriptsPath
    $cfg = Join-Path $gameDir 'DisplaySettings.ini'
    if (Test-Path $cfg) { Remove-Item $cfg }
    Say 'Готово: мод удалён, остальные скрипты игры не изменены.' 'Done: the mod was removed, other game scripts are untouched.'
    exit 0
}

# --- Установка ---
$srcPath = Join-Path $modDir 'DisplayMod.rb'
if (-not (Test-Path $srcPath)) { Fail 'Не найден DisplayMod.rb.' 'DisplayMod.rb not found.' }
$code = [IO.File]::ReadAllBytes($srcPath)
if ($code.Length -ge 3 -and $code[0] -eq 0xEF -and $code[1] -eq 0xBB -and $code[2] -eq 0xBF) {
    $code = [byte[]]$code[3..($code.Length - 1)]
}

# Бэкап делаем только с «чистого» файла (без мода) — это текущие скрипты
# игрока со всеми его переводами и патчами.
if ($installed.Count -eq 0) {
    Copy-Item -Force $scriptsPath $backup
    Say "Бэкап оригинальных скриптов: DisplayMod\Scripts.rvdata2.backup" "Backup of the original scripts: DisplayMod\Scripts.rvdata2.backup"
}

$mainIdx = -1
for ($i = 0; $i -lt $clean.Count; $i++) { if ($clean[$i].Name -eq 'Main') { $mainIdx = $i } }
if ($mainIdx -lt 0) { $mainIdx = $clean.Count - 1 }

$syms = Get-SymbolsBefore $clean $mainIdx
$modBytes = Build-ModEntry $code $syms
$final = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $clean.Count; $i++) {
    if ($i -eq $mainIdx) { [void]$final.Add([pscustomobject]@{ Name = $ScriptName; Bytes = $modBytes }) }
    [void]$final.Add($clean[$i])
}
$out = Build-File $final

# Проверка: файл читается, мод на месте и распаковывается в исходный код,
# все остальные скрипты совпадают байт в байт.
try {
    $check = Parse-Scripts $out
    if ($check.Count -ne $clean.Count + 1) { throw 'entry count mismatch' }
    $j = 0
    foreach ($e in $check) {
        if ($e.Name -eq $ScriptName) {
            $back = Expand-Zlib $e.Code
            if ([Convert]::ToBase64String($back) -ne [Convert]::ToBase64String($code)) { throw 'mod code mismatch' }
            continue
        }
        if ([Convert]::ToBase64String($e.Bytes) -ne [Convert]::ToBase64String($clean[$j].Bytes)) { throw "script '$($e.Name)' changed" }
        $j++
    }
} catch {
    Fail "Самопроверка не пройдена ($($_.Exception.Message)), файл игры не изменён." "Self-check failed ($($_.Exception.Message)), game files were not modified."
}

[IO.File]::WriteAllBytes("$scriptsPath.tmp", $out)
Move-Item -Force "$scriptsPath.tmp" $scriptsPath

if ($installed.Count -gt 0) {
    Say 'Готово: мод обновлён.' 'Done: the mod was updated.'
} else {
    Say 'Готово: мод установлен.' 'Done: the mod was installed.'
}
Write-Host ''
Say 'В игре: F5 — настройки экрана, Alt+Enter — оконный/полноэкранный.' 'In game: F5 - display settings, Alt+Enter - windowed/fullscreen.'
Say 'После установки перевода или патча на игру запустите install.bat ещё раз.' 'Run install.bat again after installing a translation or patch.'
exit 0
