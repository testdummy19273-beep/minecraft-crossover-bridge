"""Shared-memory helpers for the dev scripts (Windows, Linux, macOS)."""
import mmap
import os
import time


def shm_dir():
    d = os.environ.get("ERMC_DIR")
    if d:
        return d
    if os.name == "nt":
        return os.path.join(os.environ.get("LOCALAPPDATA", "C:\\"), "ermc")
    return "/tmp/ermc"


def shm_path(name):
    return os.path.join(shm_dir(), name)


def open_rw(path):
    return os.open(path, os.O_RDWR | getattr(os, "O_BINARY", 0))


def map_shared(fd, size):
    """A read/write view of the file that other processes see live."""
    if os.name == "nt":
        return mmap.mmap(fd, size, access=mmap.ACCESS_WRITE)
    return mmap.mmap(fd, size, mmap.MAP_SHARED, mmap.PROT_READ | mmap.PROT_WRITE)


class FileLock:
    """Cross-process mutex on a small file (fcntl on Unix, msvcrt on Windows)."""

    def __init__(self, path):
        self.path = path
        self.f = None

    def __enter__(self):
        self.f = open(self.path, "a+b")
        if os.name == "nt":
            import msvcrt
            while True:
                try:
                    self.f.seek(0)
                    msvcrt.locking(self.f.fileno(), msvcrt.LK_NBLCK, 1)
                    break
                except OSError:
                    time.sleep(0.005)
        else:
            import fcntl
            fcntl.flock(self.f, fcntl.LOCK_EX)
        return self

    def __exit__(self, *exc):
        if os.name == "nt":
            import msvcrt
            self.f.seek(0)
            try:
                msvcrt.locking(self.f.fileno(), msvcrt.LK_UNLCK, 1)
            except OSError:
                pass
        self.f.close()
