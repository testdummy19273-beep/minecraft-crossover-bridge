<#
.SYNOPSIS
  Builds the Elden Ring side of the bridge and copies it into the game folder.
.DESCRIPTION
  Copies dinput8.dll (a tiny loader) and erbridge\erbridge_core.dll next to eldenring.exe, and
  writes steam_appid.txt so the game can start without going through Steam's Easy Anti-Cheat
  launcher. Nothing is installed system-wide, and a normal Steam launch stays vanilla: the loader
  does nothing unless launch-er.ps1 started the game (ERBRIDGE=1) and no anti-cheat is loaded.
.PARAMETER GameDir   Folder that holds eldenring.exe (auto-detected from Steam if omitted).
.PARAMETER Remove    Uninstall: remove the bridge files from the game folder.
.PARAMETER SkipBuild Use the DLLs already in er-bridge\build.
.PARAMETER Msys2     MSYS2 root (default C:\msys64). Needs: pacman -S --needed mingw-w64-x86_64-gcc make
#>
param([string]$GameDir, [switch]$Remove, [switch]$SkipBuild, [string]$Msys2)
. "$PSScriptRoot\_common.ps1"

$GameDir = Find-EldenRingGameDir $GameDir
$loader = Join-Path $GameDir 'dinput8.dll'
$bridgeDir = Join-Path $GameDir 'erbridge'
$appId = Join-Path $GameDir 'steam_appid.txt'
$addedMarker = Join-Path $bridgeDir 'steam_appid-added'

if ($Remove) {
    if (Test-ErBridgeFile $loader) { Remove-Item $loader -Force }
    if (Test-Path $addedMarker) { Remove-Item $appId -Force -ErrorAction SilentlyContinue }
    if (Test-Path $bridgeDir) { Remove-Item $bridgeDir -Recurse -Force }
    Write-Host "Removed er-bridge from $GameDir"
    return
}

if ((Test-Path $loader) -and -not (Test-ErBridgeFile $loader)) {
    throw "A different dinput8.dll is already in $GameDir (another mod loader?). Back it up or remove it first."
}

if (-not $SkipBuild) {
    $ms = Find-Msys2 $Msys2
    if (-not $ms) {
        throw "MSYS2 not found. Install it (winget install MSYS2.MSYS2), open the 'MSYS2 MINGW64' shell and run:`n  pacman -S --needed mingw-w64-x86_64-gcc make`nThen re-run this script (or pass -Msys2 <root>)."
    }
    $env:MSYSTEM = 'MINGW64'
    $env:CHERE_INVOKING = '1'
    Push-Location $ErDir
    try {
        & (Join-Path $ms 'usr\bin\bash.exe') -lc 'make -j8'
        if ($LASTEXITCODE -ne 0) { throw "make failed (exit $LASTEXITCODE). Is mingw-w64-x86_64-gcc installed in MSYS2?" }
    } finally { Pop-Location }
}

$loaderBuilt = Join-Path $ErDir 'build\dinput8.dll'
$coreBuilt = Join-Path $ErDir 'build\erbridge_core.dll'
foreach ($f in $loaderBuilt, $coreBuilt) { if (-not (Test-Path $f)) { throw "Missing build output: $f" } }

New-Item -ItemType Directory -Force $bridgeDir | Out-Null
# Copy-then-rename: a running game keeps its mapped copy of the old file intact.
# (Windows refuses to replace a DLL that is loaded, so close the game first for the loader.)
try {
    Copy-Item $loaderBuilt "$loader.new" -Force
    Move-Item "$loader.new" $loader -Force
} catch { throw "Could not replace dinput8.dll (is Elden Ring running?): $($_.Exception.Message)" }
Copy-Item $coreBuilt (Join-Path $bridgeDir 'erbridge_core.dll.new') -Force
Move-Item (Join-Path $bridgeDir 'erbridge_core.dll.new') (Join-Path $bridgeDir 'erbridge_core.dll') -Force

# Lets launch-er.ps1 start eldenring.exe directly: without it the game restarts itself
# through Steam and Easy Anti-Cheat.
if (-not (Test-Path $appId)) {
    Set-Content -Path $appId -Value $SteamAppId -Encoding ASCII
    New-Item -ItemType File -Force $addedMarker | Out-Null   # so -Remove takes it out again
}

$shared = if ($env:ERMC_DIR) { $env:ERMC_DIR } else { Join-Path $env:LOCALAPPDATA 'ermc' }
New-Item -ItemType Directory -Force $shared | Out-Null
Write-Host "Installed er-bridge into: $GameDir"
Write-Host "Start the game with: scripts\launch-er.ps1"
