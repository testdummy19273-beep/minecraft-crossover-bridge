#!/usr/bin/env python3
"""Dev: push a Minecraft-style hit into the er-bridge damage queue, as the mod does.

    python elden-ring-windows/scripts/erhit.py <entity handle hex> <minecraft damage> [crit]

The DLL applies it on the game thread (game.cpp service_damage/apply_hit) and logs
"combat: ..." lines to %LOCALAPPDATA%\\ermc\\er-bridge.log.
"""
import os, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ermc_shm import map_shared, open_rw, shm_path
OFF = 0x280000
RING = 256

def push(handle, amount, flags=0, pos=(0.0, 0.0, 0.0)):
    fd = open_rw(shm_path("bridge.shm"))
    mm = map_shared(fd, 8 * 1024 * 1024)
    w = struct.unpack_from("<I", mm, OFF)[0]
    struct.pack_into("<Qf3fII", mm, OFF + 0x10 + (w % RING) * 0x20, handle, amount, *pos, flags, 0)
    struct.pack_into("<I", mm, OFF, (w + 1) & 0xFFFFFFFF)

if __name__ == "__main__":
    push(int(sys.argv[1], 16), float(sys.argv[2]), 1 if len(sys.argv) > 3 and sys.argv[3] == "crit" else 0)
