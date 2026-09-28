#!/bin/bash
# Fetch and patch every source the toolchain is built from.
# Every host builds from the one tree this produces.
# Usage: prepare-sources.sh [output dir]   (default: ./src)
set -euo pipefail
export LC_ALL=C

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${1:-$ROOT/src}

GCC_REPO=https://github.com/gcc-mirror/gcc.git
GCC_REF=releases/gcc-10.3.0
GCC_COMMIT=f00b5710a30f22efc3171c393e56aeb335c3cd39
BINUTILS_REPO=https://sourceware.org/git/binutils-gdb.git
BINUTILS_REF=binutils-2_32
BINUTILS_COMMIT=a9d9a104dde6a749f40ce5c4576a0042a7d52d1f
# The headers and libc of the 2.100300.220621 package match this commit,
# not the branch head
NEWLIB_REPO=https://github.com/earlephilhower/newlib-xtensa.git
NEWLIB_COMMIT=d6e3fcdbfdf4b10d0d8a05dbf90b2c4912b3f2e1
HAL_REPO=https://github.com/earlephilhower/lx106-hal.git
HAL_COMMIT=e4bcc63c9c016e4f8848e7e8f512438ca857531d

INFRASTRUCTURE=https://gcc.gnu.org/pub/gcc/infrastructure
SUPPORT_LIBS=(
  "gmp-6.1.0.tar.bz2 498449a994efeba527885c10405993427995d3f86b8768d8cdf8d9dd7c6b73e8"
  "mpfr-3.1.4.tar.bz2 d3103a80cdad2407ed581f3618c4bed04e0c92d1cf771a65ead662cc397f7775"
  "mpc-1.0.3.tar.gz 617decc6ea09889fb08ede330917a00b16809b8db88c29c31bfbb49cbf88ecc3"
  "isl-0.18.tar.bz2 6b8b0fd7f81d0a957beb3679c81bbb34ccc7568d5682844d8924424a0dadcb1b"
)

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

fetch() { # <dir> <repo> <ref> <commit>
  echo "Fetching $1"
  rm -rf "$SRC/$1"
  git init --quiet "$SRC/$1"
  git -C "$SRC/$1" remote add origin "$2"
  git -C "$SRC/$1" fetch --quiet --depth 1 origin "$3"
  git -C "$SRC/$1" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
  local got
  got=$(git -C "$SRC/$1" rev-parse HEAD)
  if [ "$got" != "$4" ]; then
    echo "$1: expected commit $4, got $got"
    exit 1
  fi
  rm -rf "$SRC/$1/.git"
}

apply_patches() { # <source dir> <patch> ...
  local dir=$1
  shift
  for p in "$@"; do
    test -r "$p" || continue
    echo "Applying ${p#"$ROOT"/}"
    (cd "$dir" && patch -s -p1 <"$p")
  done
}

mkdir -p "$SRC"
fetch gcc "$GCC_REPO" "$GCC_REF" "$GCC_COMMIT"
fetch binutils "$BINUTILS_REPO" "$BINUTILS_REF" "$BINUTILS_COMMIT"
fetch newlib "$NEWLIB_REPO" "$NEWLIB_COMMIT" "$NEWLIB_COMMIT"
fetch lx106-hal "$HAL_REPO" "$HAL_COMMIT" "$HAL_COMMIT"

for entry in "${SUPPORT_LIBS[@]}"; do
  read -r archive expected <<<"$entry"
  name=${archive%.tar.*}
  echo "Fetching $name"
  curl -fsSL --retry 5 --retry-delay 10 -o "$SRC/$archive" "$INFRASTRUCTURE/$archive"
  got=$(sha256 "$SRC/$archive")
  if [ "$got" != "$expected" ]; then
    echo "$archive: expected sha256 $expected, got $got"
    exit 1
  fi
  (cd "$SRC/gcc" && tar xf "$SRC/$archive" && ln -s "$name" "${name%-*}")
  rm "$SRC/$archive"
done

apply_patches "$SRC/gcc" "$ROOT"/patches/gcc/gcc-*.patch
apply_patches "$SRC/gcc" "$ROOT"/patches/host/gcc-*.patch

# Force the lx106 core definition into binutils and gcc
for ow in "$SRC/gcc/include/xtensa-config.h" "$SRC/binutils/include/xtensa-config.h"; do
  {
    cat "$SRC/lx106-hal/include/xtensa/config/core-isa.h"
    cat "$SRC/lx106-hal/include/xtensa/config/system.h"
    echo '#define XCHAL_HAVE_FP_DIV   0'
    echo '#define XCHAL_HAVE_FP_RECIP 0'
    echo '#define XCHAL_HAVE_FP_SQRT  0'
    echo '#define XCHAL_HAVE_FP_RSQRT 0'
  } >"$ow"
done
(cd "$SRC/lx106-hal" && autoreconf -i)

# Not built, and a large part of the download for every host. The compiler's
# self test reads gcc/testsuite/selftests, so that one stays.
find "$SRC/gcc/gcc/testsuite" -mindepth 1 -maxdepth 1 ! -name selftests -exec rm -rf {} +
rm -rf "$SRC/binutils/gdb" "$SRC/binutils/sim" "$SRC/binutils/readline"

echo "Sources ready in $SRC"
