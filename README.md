# Minecraft × Elden Ring — Windows + Prism Launcher port

Port of the macOS/CrossOver "Elden Ring" half of
[minecraft-crossover-bridge](https://github.com/testdummy19273-beep/minecraft-crossover-bridge)
to native Windows. Both games now run natively: Elden Ring (D3D12) and Minecraft 1.21.1 (Fabric,
launched from **Prism Launcher**). They still talk through two memory-mapped files; see the
original repo's `docs/how-it-works.md` for the design.

> **Status: untested.** The two DLLs compile and link with MinGW-w64, and every changed Java line is
> small, but I could not run Windows, Elden Ring, Prism or Gradle here. Expect to debug the
> compositor (below) on first run. `%LOCALAPPDATA%\ermc\er-bridge.log` says what it's doing.

## What changed from the macOS version

| Area | macOS / CrossOver | Windows |
|---|---|---|
| Shared files | `/tmp/ermc` (`Z:\tmp\ermc` in Wine) | `%ERMC_DIR%`, else `%LOCALAPPDATA%\ermc` — both sides resolve it the same way |
| Build | cross-compile with brew mingw-w64 | MSYS2 MinGW-w64 (`make`) — `install-er-bridge.ps1` calls it |
| Game launch | `wine --dll dinput8=n,b` | `dinput8.dll` side-loads from the game folder; `launch-er.ps1` starts `eldenring.exe` with `ERBRIDGE=1` |
| Minecraft | Gradle `runClient` dev launch | the mod jar goes in a Prism instance (`install-mod-prism.ps1`) |
| Swapchain hook | scanned D3DMetal's table in dxgi.dll | dummy swapchain → shared vtable, patched with `VirtualProtect` |
| Game's queue | D3DMetal object-layout trick (`swapchain+0x28`) | MinHook on `ID3D12CommandQueue::ExecuteCommandLists` (queue used on the Present thread) |
| Scripts | zsh | PowerShell (+ Python dev tools that now work on Windows) |

Unchanged: the protocol, `game.cpp` (signature-checked addresses for `eldenring.exe` 2.7.1.0), the
Fabric mod's logic, offline-only safety (the loader does nothing unless `launch-er.ps1` set
`ERBRIDGE=1`, and refuses to run if Easy Anti-Cheat is loaded).

## Requirements

- Windows 10/11 x64, Elden Ring from Steam at **App Ver. 1.17.1** (`eldenring.exe` 2.7.1.0).
  Other versions: features whose addresses don't match switch off.
- [MSYS2](https://www.msys2.org): `winget install MSYS2.MSYS2`, then in the *MSYS2 MINGW64* shell:
  `pacman -S --needed mingw-w64-x86_64-gcc make`
- JDKs for building the mod: `winget install EclipseAdoptium.Temurin.25.JDK EclipseAdoptium.Temurin.21.JDK`
  (Gradle/Loom runs on 25, Minecraft compiles against 21). Prism brings its own Java for playing.
- A Prism instance: Minecraft **1.21.1**, **Fabric Loader**, and **Fabric API** (Edit instance →
  Mods → Download mods). The mod needs Loader ≥ 0.16 and was developed against Fabric API 0.116.17+1.21.1.
- Python 3 only for the optional dev tools.

## Setup

PowerShell, from this folder (`Set-ExecutionPolicy -Scope Process Bypass` if scripts are blocked):

```powershell
scripts\install-er-bridge.ps1                       # build + copy dinput8.dll / erbridge_core.dll into the game folder
scripts\install-mod-prism.ps1 -Instance "My MC"     # build the mod, copy the jar into that Prism instance
```

Then each session:

1. Start Steam, log in. In Elden Ring's settings use **Windowed or Borderless** (not Fullscreen).
2. `scripts\launch-er.ps1` — starts Elden Ring **offline, without Easy Anti-Cheat**. Load your save and stand in the world.
3. Launch the Prism instance. Minecraft opens the "ER Bridge" world by itself and takes over. The world starts in
   creative: `/gamemode survival` to take damage.

Controls are the same as the original (R = Elden Ring action, F6/F7/F8/F9/F10 — F8 hands keyboard and mouse to Elden Ring and back).
Remove everything with `scripts\install-er-bridge.ps1 -Remove` and delete the jar from the instance's `mods` folder.

## Things to know on Windows

- **DPI scaling:** the Minecraft overlay is placed using Elden Ring's client rectangle. At display
  scaling above 100% the two can disagree. Test at 100%, or right-click `eldenring.exe` →
  Properties → Compatibility → *Change high DPI settings* → *Override high DPI scaling behavior: Application*.
- **Compositor (the risky part).** Drawing Minecraft inside Elden Ring's frame was written for
  D3DMetal, which doesn't track resource states. On real D3D12 the depth-buffer read has to guess the state the game
  leaves it in. If you see garbage/flicker in occlusion, or the log mentions D3D12 errors, set these as
  *system* environment variables before `launch-er.ps1`:
  - `ERBRIDGE_DEPTH_STATE=read` or `srv` (default `write`) — the state assumed at Present
  - `ERBRIDGE_NO_DEPTH=1` — skip depth occlusion entirely (blocks then draw over walls, but it's the safest fallback)
  - If compositing still fails, the mod falls back to its separate overlay window (F6 toggles).
- **Queue discovery:** if the log says `no direct queue seen on the Present thread`, the game submits from another
  thread than it presents on; that's the first thing to fix in `pick_queue` (`compositor.cpp`).
- **Other overlays** (Steam, RTSS, Discord) hook the same swapchain; hooks chain, but if something crashes on start, disable them to test.
- **Disk traffic:** `frames.shm` is rewritten every frame. If you'd rather not hit the SSD, point `ERMC_DIR` (system-wide) at a RAM disk.
- Frames larger than 1920×1200 fall back to the overlay window, as on macOS.

## Debugging

- Game side: `%LOCALAPPDATA%\ermc\er-bridge.log`. Minecraft side: the Prism instance log.
- `scripts\reload-core.ps1` rebuilds and hot-swaps the core DLL without restarting the game.
- `python scripts\erctl.py ping` (and `state`, `fps`, `sig`, …) talk to the live bridge.

## Caveats

Offline only, as with every Elden Ring mod: never take a modded game online. Fan project, no game
files included, not affiliated with Mojang, Microsoft, FromSoftware, Bandai Namco, Valve or Prism Launcher.
Original code by justbustin / @tobynjacobs's idea; MIT licensed (see LICENSE of the original repo).
