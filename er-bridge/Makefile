# Builds the Elden Ring side of the bridge with MinGW-w64.
#   Windows : run `make` in an MSYS2 "MINGW64" shell (pacman -S mingw-w64-x86_64-gcc make),
#             or let elden-ring-windows/scripts/install-er-bridge.ps1 do that for you.
#   Linux/macOS cross-compile: the x86_64-w64-mingw32-* toolchain is picked automatically.
#
#   build/dinput8.dll           tiny loader, only active when elden-ring-windows/scripts/launch-er.ps1
#                               starts the game (offline, no Easy Anti-Cheat)
#   build/erbridge_core.dll     the actual bridge; hot-reloadable while the game runs
ifeq ($(OS),Windows_NT)
CXX      := g++
CC       := gcc
else
CXX      := x86_64-w64-mingw32-g++
CC       := x86_64-w64-mingw32-gcc
endif
CXXFLAGS := -O2 -std=c++17 -Wall -Wno-unknown-pragmas -Iinclude -Ithird_party/minhook/include \
            -fno-exceptions -fno-rtti -DWIN32_LEAN_AND_MEAN -DNOMINMAX -D__USE_MINGW_ANSI_STDIO=1
CFLAGS   := -O2 -Ithird_party/minhook/include
LDFLAGS  := -shared -s -static -static-libgcc -static-libstdc++
LIBS     := -luser32 -lkernel32

LOADER_SRCS := src/proxy.cpp src/log.cpp src/shm.cpp
CORE_SRCS   := src/core.cpp src/log.cpp src/shm.cpp src/memutil.cpp src/debugcmd.cpp \
               src/frame.cpp src/game.cpp src/compositor.cpp
MH_SRCS     := third_party/minhook/src/buffer.c third_party/minhook/src/hook.c \
               third_party/minhook/src/trampoline.c third_party/minhook/src/hde/hde64.c

obj = $(patsubst src/%.cpp,build/obj/%.o,$(1))
LOADER_OBJS := $(call obj,$(LOADER_SRCS))
CORE_OBJS   := $(call obj,$(CORE_SRCS)) $(MH_SRCS:third_party/minhook/src/%.c=build/obj/mh/%.o)

all: build/dinput8.dll build/erbridge_core.dll

build/obj/%.o: src/%.cpp src/common.h include/bridge_protocol.h
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) -c $< -o $@

build/obj/mh/%.o: third_party/minhook/src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

build/dinput8.dll: $(LOADER_OBJS) src/dinput8.def
	$(CXX) -o $@ $(LOADER_OBJS) $(LDFLAGS) -Wl,--kill-at src/dinput8.def $(LIBS)

build/erbridge_core.dll: $(CORE_OBJS)
	$(CXX) -o $@ $(CORE_OBJS) $(LDFLAGS) $(LIBS)

clean:
	rm -rf build
