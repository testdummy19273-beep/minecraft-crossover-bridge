<#
.SYNOPSIS
  Dev: rebuild erbridge_core.dll and hot-swap it into the running Elden Ring (no game restart).
  Also installs it for the next launch. Needs Python 3 (py or python on PATH).
#>
param([string]$GameDir, [string]$Msys2)
. "$PSScriptRoot\_common.ps1"

$GameDir = Find-EldenRingGameDir $GameDir
$ms = Find-Msys2 $Msys2
if (-not $ms) { throw 'MSYS2 not found (see install-er-bridge.ps1).' }
$env:MSYSTEM = 'MINGW64'; $env:CHERE_INVOKING = '1'
Push-Location $ErDir
try {
    & (Join-Path $ms 'usr\bin\bash.exe') -lc 'make -j8 build/erbridge_core.dll'
    if ($LASTEXITCODE -ne 0) { throw 'make failed' }
} finally { Pop-Location }

$bridgeDir = Join-Path $GameDir 'erbridge'
New-Item -ItemType Directory -Force $bridgeDir | Out-Null
Copy-Item (Join-Path $ErDir 'build\erbridge_core.dll') (Join-Path $bridgeDir 'erbridge_core.dll.new') -Force
Move-Item (Join-Path $bridgeDir 'erbridge_core.dll.new') (Join-Path $bridgeDir 'erbridge_core.dll') -Force

$py = Get-Command py -ErrorAction SilentlyContinue
if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
if (-not $py) { throw 'Python 3 not found on PATH.' }
& $py.Source (Join-Path $PSScriptRoot 'reload_core.py')
$shared = if ($env:ERMC_DIR) { $env:ERMC_DIR } else { Join-Path $env:LOCALAPPDATA 'ermc' }
Get-Content (Join-Path $shared 'er-bridge.log') -Tail 8
