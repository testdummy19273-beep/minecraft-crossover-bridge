#include "common.h"
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

namespace mb {

static CRITICAL_SECTION g_logLock;
static FILE* g_logFile = nullptr;
static bool g_logInit = false;

static char g_dir[MAX_PATH];
static volatile LONG g_dirReady = 0;

const char* shared_dir() {
    if (!g_dirReady) {
        char tmp[MAX_PATH] = {0};
        DWORD n = GetEnvironmentVariableA("ERMC_DIR", tmp, sizeof(tmp));
        if (n > 0 && n < sizeof(tmp)) {
            snprintf(g_dir, sizeof(g_dir), "%s", tmp);
        } else {
            n = GetEnvironmentVariableA("LOCALAPPDATA", tmp, sizeof(tmp) - 16);
            if (n > 0 && n < sizeof(tmp) - 16) snprintf(g_dir, sizeof(g_dir), "%s\\ermc", tmp);
            else snprintf(g_dir, sizeof(g_dir), "C:\\ermc");
        }
        CreateDirectoryA(g_dir, nullptr);
        InterlockedExchange(&g_dirReady, 1);
    }
    return g_dir;
}

void shared_path(const char* name, char* out, size_t n) { snprintf(out, n, "%s\\%s", shared_dir(), name); }

uint64_t now_ms() {
    FILETIME ft;
    GetSystemTimeAsFileTime(&ft);
    uint64_t t = ((uint64_t)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    return (t - 116444736000000000ULL) / 10000ULL;  // 100ns since 1601 -> ms since 1970
}

void log(const char* fmt, ...) {
    if (!g_logInit) {
        InitializeCriticalSection(&g_logLock);
        char path[MAX_PATH];
        shared_path("er-bridge.log", path, sizeof(path));
        g_logFile = fopen(path, "a");
        g_logInit = true;
    }
    if (!g_logFile) return;
    EnterCriticalSection(&g_logLock);
    SYSTEMTIME st;
    GetLocalTime(&st);
    fprintf(g_logFile, "[%02d:%02d:%02d.%03d] ", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds);
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_logFile, fmt, ap);
    va_end(ap);
    fputc('\n', g_logFile);
    fflush(g_logFile);
    LeaveCriticalSection(&g_logLock);
}

void log_close() {
    if (!g_logInit) return;
    EnterCriticalSection(&g_logLock);
    if (g_logFile) fclose(g_logFile);
    g_logFile = nullptr;
    LeaveCriticalSection(&g_logLock);
}

}  // namespace mb
