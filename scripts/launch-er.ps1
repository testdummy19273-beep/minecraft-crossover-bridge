<#
.SYNOPSIS
  Starts Elden Ring OFFLINE, without Easy Anti-Cheat, with the bridge enabled for this launch only.
.DESCRIPTION
  Steam must already be running and logged in (the game checks ownership through it). Online
  features are unavailable in this mode, as with every Elden Ring mod. Never take a modded game
  online. A normal Steam launch never loads the bridge.
#>
param([string]$GameDir)
. "$PSScriptRoot\_common.ps1"

$GameDir = Find-EldenRingGameDir $GameDir
$exe = Join-Path $GameDir 'eldenring.exe'
if (-not (Test-Path (Join-Path $GameDir 'erbridge\erbridge_core.dll'))) { throw 'Bridge not installed: run scripts\install-er-bridge.ps1' }
$appIdFile = Join-Path $GameDir 'steam_appid.txt'
if (-not (Test-Path $appIdFile) -or (Get-Content $appIdFile -Raw).Trim() -ne $SteamAppId) {
    throw "steam_appid.txt ($SteamAppId) is missing next to eldenring.exe (re-run install-er-bridge.ps1); without it the game relaunches itself through Steam and EAC."
}
if (Get-Process -Name 'start_protected_game' -ErrorAction SilentlyContinue) { throw 'Elden Ring is running through Easy Anti-Cheat; quit it first.' }
if (Get-Process -Name 'eldenring' -ErrorAction SilentlyContinue) { throw 'Elden Ring is already running; quit it first.' }
if (-not (Get-Process -Name 'steam' -ErrorAction SilentlyContinue)) { Write-Warning 'Steam does not seem to be running. Start it and log in first, or the game will not start.' }

$ver = (Get-Item $exe).VersionInfo.FileVersion
if ($ver -and $ver -notlike '2.7.1.0*') {
    Write-Warning "eldenring.exe is version $ver; the bridge supports 2.7.1.0 (App Ver. 1.17.1). Unmatched features switch themselves off (see er-bridge.log)."
}

$env:ERBRIDGE = '1'
Write-Host 'Starting Elden Ring offline (no EAC) with the bridge.'
Write-Host ("Log: " + $(if ($env:ERMC_DIR) { $env:ERMC_DIR } else { Join-Path $env:LOCALAPPDATA 'ermc' }) + '\er-bridge.log')
Start-Process -FilePath $exe -WorkingDirectory $GameDir
