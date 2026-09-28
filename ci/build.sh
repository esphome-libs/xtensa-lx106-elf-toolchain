#!/bin/bash
# Build the xtensa-lx106-elf toolchain (GCC 10.3) for one host system.
#
# Usage: build.sh <system> [stage ...]
#   system: darwin_arm64 darwin_x86_64 linux_x86_64 linux_aarch64
#           linux_armv7l linux_i686 windows_amd64 windows_x86
#   stages: host    binutils, gcc and the lto plugin, the programs that run on the host
#           device  newlib, libgcc, libstdc++ and hal, the code that runs on the chip
#   Default is "host". The device stages need a toolchain that runs on the
#   build machine, so they are only built where host and build machine match.
#
# Sources come from ci/prepare-sources.sh in ./src, or the directory in SRC.
set -euo pipefail
export LC_ALL=C

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${SRC:-$ROOT/src}
SYSTEM=${1:?system required}
shift
BUILD_DIR=$ROOT/build/$SYSTEM
INSTALL=$ROOT/install/$SYSTEM
LOGS=$ROOT/logs/$SYSTEM

case $(uname -s) in
  Darwin) JOBS=$(sysctl -n hw.ncpu) ;;
  *) JOBS=$(nproc) ;;
esac

case $(uname -s)-$(uname -m) in
  Darwin-arm64) BUILD=aarch64-apple-darwin ;;
  Darwin-x86_64) BUILD=x86_64-apple-darwin ;;
  Linux-x86_64) BUILD=x86_64-linux-gnu ;;
  Linux-aarch64) BUILD=aarch64-linux-gnu ;;
  *)
    echo "Unsupported build machine $(uname -s) $(uname -m)"
    exit 1
    ;;
esac

EXTRA=()
HOST_LDFLAGS=""
case $SYSTEM in
  darwin_arm64)
    HOST=aarch64-apple-darwin
    export MACOSX_DEPLOYMENT_TARGET=11.0
    # The bundled zlib is old C that current clang rejects
    EXTRA+=(--with-system-zlib)
    ;;
  darwin_x86_64)
    HOST=x86_64-apple-darwin
    export MACOSX_DEPLOYMENT_TARGET=10.13
    EXTRA+=(--with-system-zlib)
    ;;
  linux_x86_64) HOST=x86_64-linux-gnu ;;
  linux_aarch64) HOST=aarch64-linux-gnu ;;
  linux_armv7l) HOST=arm-linux-gnueabihf ;;
  linux_i686) HOST=i686-linux-gnu ;;
  windows_amd64)
    HOST=x86_64-w64-mingw32
    # No dependency on the mingw runtime libraries
    HOST_LDFLAGS="-static"
    ;;
  windows_x86)
    HOST=i686-w64-mingw32
    HOST_LDFLAGS="-static"
    ;;
  *)
    echo "Unknown system $SYSTEM"
    exit 1
    ;;
esac

export CFLAGS="-O2 -pipe"
export CXXFLAGS="-O2 -pipe"
export LDFLAGS="$HOST_LDFLAGS"
# Flags the device libraries of the 2.100300.220621 package were built with
# The prefix maps only change the paths written into debug info
DEVICE_PATHS="-fdebug-prefix-map=$ROOT=/toolchain -fdebug-prefix-map=$SRC=/toolchain/src"
export CFLAGS_FOR_TARGET="-mlongcalls -Os -g -free -fipa-pta $DEVICE_PATHS"
export CXXFLAGS_FOR_TARGET="$CFLAGS_FOR_TARGET"
# When host and build machine differ, gcc's configure probes the assembler
# through a toolchain for the build machine, given in BUILD_TOOLCHAIN
export PATH="$INSTALL/bin:${BUILD_TOOLCHAIN:+$BUILD_TOOLCHAIN/bin:}$PATH"

CONFIGURE=(
  --prefix="$INSTALL"
  --build="$BUILD"
  --host="$HOST"
  --target=xtensa-lx106-elf
  --disable-shared
  --with-newlib
  --enable-threads=no
  --disable-__cxa_atexit
  --disable-libgomp
  --disable-libmudflap
  --disable-nls
  --disable-multilib
  --disable-bootstrap
  --enable-languages=c,c++
  --enable-lto
  --enable-static=yes
  --disable-libstdcxx-verbose
  --disable-werror
  ${EXTRA[@]+"${EXTRA[@]}"}
  MAKEINFO=true
)

CONFIGURE_NEWLIB=(
  --prefix="$INSTALL"
  --build="$BUILD"
  --with-newlib
  --enable-multilib
  --disable-newlib-io-c99-formats
  --disable-newlib-supplied-syscalls
  --enable-newlib-nano-formatted-io
  --enable-newlib-reent-small
  --enable-target-optspace
  --disable-option-checking
  --target=xtensa-lx106-elf
  --disable-shared
  MAKEINFO=true
)

stage_binutils() {
  rm -rf "$BUILD_DIR/binutils"
  mkdir -p "$BUILD_DIR/binutils"
  cd "$BUILD_DIR/binutils"
  "$SRC/binutils/configure" "${CONFIGURE[@]}"
  make -j"$JOBS" MAKEINFO=true
  make install MAKEINFO=true
}

stage_gcc() {
  rm -rf "$BUILD_DIR/gcc"
  mkdir -p "$BUILD_DIR/gcc"
  cd "$BUILD_DIR/gcc"
  "$SRC/gcc/configure" "${CONFIGURE[@]}"
  make -j"$JOBS" all-gcc all-lto-plugin MAKEINFO=true
  make install-gcc install-lto-plugin MAKEINFO=true
}

stage_newlib() {
  rm -rf "$BUILD_DIR/newlib"
  mkdir -p "$BUILD_DIR/newlib"
  cd "$BUILD_DIR/newlib"
  "$SRC/newlib/configure" "${CONFIGURE_NEWLIB[@]}"
  make -j"$JOBS" MAKEINFO=true
  make install MAKEINFO=true
}

stage_libstdcpp() {
  cd "$BUILD_DIR/gcc"
  make -j"$JOBS" MAKEINFO=true
  make install MAKEINFO=true
}

# Second libstdc++ without exception support, the one linked by default
stage_libstdcpp_nox() {
  local libdir=$BUILD_DIR/gcc/xtensa-lx106-elf
  rm -rf "$libdir/libstdc++-v3-nox"
  cp -a "$libdir/libstdc++-v3" "$libdir/libstdc++-v3-nox"
  cd "$libdir/libstdc++-v3-nox"
  make clean
  find . -name Makefile -exec sed -i.bak 's/mlongcalls/mlongcalls -fno-exceptions/' {} \;
  find . -name Makefile.bak -delete
  make -j"$JOBS" MAKEINFO=true
  cp "$INSTALL/xtensa-lx106-elf/lib/libstdc++.a" "$INSTALL/xtensa-lx106-elf/lib/libstdc++-exc.a"
  cp src/.libs/libstdc++.a "$INSTALL/xtensa-lx106-elf/lib/libstdc++.a"
}

stage_hal() {
  rm -rf "$BUILD_DIR/hal"
  mkdir -p "$BUILD_DIR/hal"
  cd "$BUILD_DIR/hal"
  local args=()
  for a in "${CONFIGURE[@]}"; do
    case $a in --host=*) ;; *) args+=("$a") ;; esac
  done
  # Device code: compiled without an optimisation flag to match 2.100300.220621.
  # hal splits some sources into one object per function with a pattern only
  # GNU awk understands. 2.100300.220621 was built with mawk, which skips
  # the split and leaves 13 objects; GNU awk would produce 126.
  CFLAGS="-pipe" LDFLAGS="" AWK=mawk \
    "$SRC/lx106-hal/configure" --host=xtensa-lx106-elf "${args[@]}"
  make -j"$JOBS"
  make install
}

# Remove the soft float routines the chip has in ROM
stage_post() {
  local libgcc
  libgcc=$(echo "$INSTALL"/lib/gcc/xtensa-lx106-elf/*/libgcc.a)
  for o in _addsubdf3.o _addsubsf3.o _divdf3.o _divdi3.o _divsi3.o _extendsfdf2.o \
    _fixdfsi.o _fixunsdfsi.o _fixunssfsi.o _floatsidf.o _floatsisf.o _muldf3.o \
    _muldi3.o _mulsf3.o _truncdfsf2.o _udivdi3.o _udivsi3.o _umoddi3.o _umodsi3.o \
    _umulsidi3.o; do
    "$INSTALL/bin/xtensa-lx106-elf-gcc-ar" d "$libgcc" "$o"
  done
}

run() {
  mkdir -p "$LOGS"
  local start=$SECONDS
  echo "STAGE: $1"
  # Not inside an "if": that would switch off errexit within the stage
  set +e
  (set -e && "stage_$1") >"$LOGS/$1.log" 2>&1
  local rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    echo "FAILED: $1, last lines of $LOGS/$1.log:"
    tail -60 "$LOGS/$1.log"
    exit 1
  fi
  echo "  done in $((SECONDS - start))s"
}

if [ $# -eq 0 ]; then
  set -- host
fi
for group in "$@"; do
  case $group in
    host)
      run binutils
      run gcc
      ;;
    device)
      if [ "$HOST" != "$BUILD" ]; then
        echo "The device libraries can only be built where host and build machine match"
        exit 1
      fi
      run newlib
      run libstdcpp
      run libstdcpp_nox
      run hal
      run post
      ;;
    *)
      echo "Unknown stage group $group"
      exit 1
      ;;
  esac
done
