#!/usr/bin/env python3
"""Asks the loader inside the running Elden Ring to swap in the freshly copied erbridge_core.dll."""
import os
import struct
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ermc_shm import map_shared, open_rw, shm_path

path = shm_path("bridge.shm")
if not os.path.exists(path):
    sys.exit(f"No {path}: is Elden Ring running through launch-er.ps1?")
mm = map_shared(open_rw(path), 0x1000)
req, ack, gen, status = struct.unpack_from("<IIIi", mm, 0x38)
new = (req + 1) & 0xFFFFFFFF
struct.pack_into("<I", mm, 0x38, new)
t0 = time.time()
while struct.unpack_from("<I", mm, 0x3C)[0] != new:
    if time.time() - t0 > 15:
        sys.exit("reload: no response from Elden Ring (is it running via launch-er.ps1?)")
    time.sleep(0.02)
req, ack, gen, status = struct.unpack_from("<IIIi", mm, 0x38)
print(f"reload: core generation {gen}, status {status} ({'ok' if status == 1 else 'ERROR'})")
sys.exit(0 if status == 1 else 1)
