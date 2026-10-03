# Shared helpers for the elden-ring-windows scripts. Dot-sourced, not run directly.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $PSScriptRoot          # ...\elden-ring-windows
$script:ErDir = Join-Path $Root 'er-bridge'
$script:McDir = Join-Path $Root 'mc-bridge'
$script:SteamAppId = '1245620'

function Find-EldenRingGameDir {
    param([string]$Override)
    if ($Override) { $c = @($Override) }
    elseif ($env:ER_GAME_DIR) { $c = @($env:ER_GAME_DIR) }
    else {
        $c = @()
        $steam = $null
        foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
            try {
                $v = (Get-ItemProperty $k -ErrorAction Stop)
                if ($v.PSObject.Properties.Name -contains 'SteamPath') { $steam = $v.SteamPath; break }
                if ($v.PSObject.Properties.Name -contains 'InstallPath') { $steam = $v.InstallPath; break }
            } catch {}
        }
        if ($steam) {
            $c += (Join-Path $steam 'steamapps\common\ELDEN RING\Game')
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            if (Test-Path $vdf) {
                foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) {
                    $lib = $m.Groups[1].Value -replace '\\\\', '\'
                    $c += (Join-Path $lib 'steamapps\common\ELDEN RING\Game')
                }
            }
        }
        $c += 'C:\Program Files (x86)\Steam\steamapps\common\ELDEN RING\Game'
    }
    foreach ($d in $c) {
        $d = $d.TrimEnd('\', '/') -replace '/', '\'
        if (Test-Path (Join-Path $d 'eldenring.exe')) { return $d }
    }
    throw "Elden Ring not found (looked for eldenring.exe). Pass -GameDir 'D:\...\ELDEN RING\Game' or set ER_GAME_DIR."
}

function Test-ErBridgeFile {
    # True if the file is our dinput8.dll proxy (it contains the string 'erbridge').
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $text = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($Path))
    return $text.Contains('erbridge')
}

function Find-Msys2 {
    param([string]$Override)
    $cands = @($Override, $env:MSYS2_ROOT, 'C:\msys64', "$env:USERPROFILE\msys64") | Where-Object { $_ }
    foreach ($d in $cands) {
        if (Test-Path (Join-Path $d 'usr\bin\bash.exe')) { return $d }
    }
    return $null
}

function Find-Jdk {
    param([int]$Major)
    $roots = @(
        "$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Java", "$env:ProgramFiles\Microsoft",
        "$env:ProgramFiles\Zulu", "$env:ProgramFiles\Amazon Corretto", "$env:ProgramFiles\BellSoft",
        "$env:LOCALAPPDATA\Programs\Eclipse Adoptium"
    ) | Where-Object { Test-Path $_ }
    foreach ($r in $roots) {
        $hit = Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "(^|[-_])$Major(\.|[-_]|$)" -and (Test-Path (Join-Path $_.FullName 'bin\java.exe')) } |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}
