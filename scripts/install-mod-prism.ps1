<#
.SYNOPSIS
  Builds the Minecraft mod (Fabric) and puts it in a Prism Launcher instance.
.DESCRIPTION
  Instead of the Gradle dev launch used on macOS, Minecraft runs from your own Prism Launcher
  instance. The instance needs Minecraft 1.21.1 + Fabric Loader + Fabric API (0.116.17+1.21.1 was
  used for development); create it in Prism (Add Instance -> Minecraft 1.21.1 -> Fabric) and
  add Fabric API with Prism's "Download mods" button.
.PARAMETER Instance   Prism instance name or folder name (see the list printed if it isn't found).
.PARAMETER PrismData  Prism's data folder (default %APPDATA%\PrismLauncher; set it for portable installs).
.PARAMETER SkipBuild  Copy the jar that is already in mc-bridge\build\libs.
.PARAMETER GradleJava JDK to run Gradle with (default: a JDK 25 found in the usual install folders).
#>
param(
    [Parameter(Mandatory = $true)][string]$Instance,
    [string]$PrismData = (Join-Path $env:APPDATA 'PrismLauncher'),
    [switch]$SkipBuild,
    [string]$GradleJava
)
. "$PSScriptRoot\_common.ps1"

$instRoot = Join-Path $PrismData 'instances'
if (-not (Test-Path $instRoot)) { throw "No Prism instances folder at $instRoot. Pass -PrismData with Prism's data folder (File -> Open data folder... in Prism)." }

# Match the folder name first, then the display name in instance.cfg.
$dirs = Get-ChildItem $instRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'instance.cfg') }
$inst = $dirs | Where-Object { $_.Name -eq $Instance } | Select-Object -First 1
if (-not $inst) {
    $inst = $dirs | Where-Object { (Select-String -Path (Join-Path $_.FullName 'instance.cfg') -Pattern "^name=$([regex]::Escape($Instance))\s*$" -Quiet) } | Select-Object -First 1
}
if (-not $inst) {
    Write-Host 'Instances found:'; $dirs | ForEach-Object { Write-Host "  $($_.Name)" }
    throw "Prism instance '$Instance' not found in $instRoot"
}
$mc = @('minecraft', '.minecraft') | ForEach-Object { Join-Path $inst.FullName $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $mc) { $mc = Join-Path $inst.FullName 'minecraft'; New-Item -ItemType Directory -Force $mc | Out-Null }
$mods = Join-Path $mc 'mods'
New-Item -ItemType Directory -Force $mods | Out-Null

# Sanity-check the instance's components (mmc-pack.json).
$pack = Join-Path $inst.FullName 'mmc-pack.json'
if (Test-Path $pack) {
    $comps = (Get-Content $pack -Raw | ConvertFrom-Json).components
    $mcv = ($comps | Where-Object uid -eq 'net.minecraft').version
    $fabric = $comps | Where-Object uid -eq 'net.fabricmc.fabric-loader'
    if ($mcv -ne '1.21.1') { Write-Warning "Instance runs Minecraft $mcv; the mod targets 1.21.1." }
    if (-not $fabric) { Write-Warning 'Instance has no Fabric Loader. In Prism: Edit instance -> Version -> Install Fabric.' }
}

if (-not $SkipBuild) {
    if (-not $GradleJava) { $GradleJava = Find-Jdk 25 }
    if (-not $GradleJava) {
        throw "Gradle (Fabric Loom 1.18) needs a JDK 25, and Minecraft 1.21.1 needs a JDK 21 toolchain. Install both:`n  winget install EclipseAdoptium.Temurin.25.JDK EclipseAdoptium.Temurin.21.JDK`nor pass -GradleJava <jdk25 folder>."
    }
    if (-not (Find-Jdk 21)) { Write-Warning 'No JDK 21 found in the usual folders; Gradle needs one for the toolchain (winget install EclipseAdoptium.Temurin.21.JDK).' }
    $env:JAVA_HOME = $GradleJava
    Push-Location $McDir
    try {
        & .\gradlew.bat --no-configuration-cache build
        if ($LASTEXITCODE -ne 0) { throw "Gradle build failed (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
}

$jar = Get-ChildItem (Join-Path $McDir 'build\libs') -Filter 'er-bridge-*.jar' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '(sources|dev)\.jar$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $jar) { throw "No er-bridge-*.jar in $McDir\build\libs" }

Get-ChildItem $mods -Filter 'er-bridge-*.jar' -ErrorAction SilentlyContinue | Remove-Item -Force
Copy-Item $jar.FullName $mods -Force
Write-Host "Installed $($jar.Name) into $mods"
if (-not (Get-ChildItem $mods -Filter 'fabric-api-*.jar' -ErrorAction SilentlyContinue)) {
    Write-Warning "Fabric API is not in the mods folder. In Prism: Edit instance -> Mods -> Download mods -> Fabric API (for 1.21.1)."
}
Write-Host 'Next: start Elden Ring with scripts\launch-er.ps1, load your save, then launch this instance from Prism.'
