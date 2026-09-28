#!/bin/bash
# Assemble the archive for one host system.
#
# Usage: package.sh device
#          Collect the device libraries and headers from the linux_x86_64
#          build into device.tar.gz. Every package uses this one copy, so the
#          code that ends up in firmware is the same on all hosts.
#        package.sh <system>
#          Combine that host's programs with device.tar.gz.
#
# VERSION names the archive, default "dev".
set -euo pipefail
export LC_ALL=C

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${VERSION:-dev}
GCC_VERSION=10.3.0
DEVICE_ARCHIVE=$ROOT/device.tar.gz

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

if [ "${1:?device or system required}" = device ]; then
  cd "$ROOT/install/linux_x86_64"
  # newlib installs two header directories with nothing in them
  find xtensa-lx106-elf/include -type d -empty -delete
  # plugin and install-tools describe the build host, nothing on the chip
  tar -czf "$DEVICE_ARCHIVE" --sort=name --mtime="@${SOURCE_DATE_EPOCH:-0}" \
    --owner=0 --group=0 --numeric-owner \
    --exclude="lib/gcc/xtensa-lx106-elf/$GCC_VERSION/plugin" \
    --exclude="lib/gcc/xtensa-lx106-elf/$GCC_VERSION/install-tools" \
    include \
    lib/libhal.a \
    "lib/gcc/xtensa-lx106-elf/$GCC_VERSION" \
    xtensa-lx106-elf/include \
    xtensa-lx106-elf/lib
  echo "Wrote $DEVICE_ARCHIVE"
  exit 0
fi

SYSTEM=$1
INSTALL=$ROOT/install/$SYSTEM
PKG=$ROOT/pkg/$SYSTEM
EXE=""
STRIP=strip
# Expanded as ${TAR_FLAGS[@]+...}: bash 3.2 on macOS rejects an empty array
TAR_FLAGS=()
case $SYSTEM in
  windows_amd64)
    EXE=.exe
    STRIP=x86_64-w64-mingw32-strip
    # Links do not survive extraction on every Windows setup
    TAR_FLAGS=(--hard-dereference --dereference)
    ;;
  darwin_* | linux_*) ;;
  *)
    echo "Unknown system $SYSTEM"
    exit 1
    ;;
esac

rm -rf "$PKG"
mkdir -p "$PKG/libexec/gcc/xtensa-lx106-elf" "$PKG/xtensa-lx106-elf"
tar -xzf "$DEVICE_ARCHIVE" -C "$PKG"
cp -a "$INSTALL/bin" "$PKG/bin"
cp -a "$INSTALL/xtensa-lx106-elf/bin" "$PKG/xtensa-lx106-elf/bin"
cp -a "$INSTALL/libexec/gcc/xtensa-lx106-elf/$GCC_VERSION" "$PKG/libexec/gcc/xtensa-lx106-elf/"
rm -rf "$PKG/libexec/gcc/xtensa-lx106-elf/$GCC_VERSION/install-tools" \
  "$PKG/libexec/gcc/xtensa-lx106-elf/$GCC_VERSION/plugin"
if [ -n "$EXE" ]; then
  cp "$PKG/bin/xtensa-lx106-elf-gcc$EXE" "$PKG/bin/xtensa-lx106-elf-cc$EXE"
else
  ln -sf xtensa-lx106-elf-gcc "$PKG/bin/xtensa-lx106-elf-cc"
fi

find "$PKG/bin" "$PKG/libexec" "$PKG/xtensa-lx106-elf/bin" -type f | while read -r f; do
  kind=$(file -b "$f")
  case $kind in
    *Mach-O*executable*)
      strip "$f"
      # strip breaks the signature the linker made; arm64 refuses unsigned code
      codesign --force --sign - "$f"
      ;;
    *Mach-O*)
      strip -x "$f"
      codesign --force --sign - "$f"
      ;;
    *ELF*executable* | *PE32*executable*) "$STRIP" "$f" ;;
    *ELF*shared* | *PE32*DLL*) "$STRIP" --strip-unneeded "$f" ;;
  esac
done

cat >"$PKG/package.json" <<JSON
{
  "name": "toolchain-xtensa-lx106-elf",
  "version": "$VERSION",
  "description": "GCC $GCC_VERSION for xtensa-lx106-elf (ESP8266)",
  "license": "GPL-3.0-or-later",
  "repository": {
    "type": "git",
    "url": "https://github.com/esphome-libs/xtensa-lx106-elf-toolchain"
  },
  "system": ["$SYSTEM"]
}
JSON

archive=$ROOT/toolchain-xtensa-lx106-elf-$VERSION-$SYSTEM.tar.gz
# Contents at the top level, no enclosing directory
if tar --version | grep -q "GNU tar"; then
  # Fixed order, times and owner, so the same files give the same archive
  tar -cf - ${TAR_FLAGS[@]+"${TAR_FLAGS[@]}"} --sort=name --mtime="@${SOURCE_DATE_EPOCH:-0}" \
    --owner=0 --group=0 --numeric-owner -C "$PKG" . | gzip -n >"$archive"
else
  tar -czf "$archive" ${TAR_FLAGS[@]+"${TAR_FLAGS[@]}"} -C "$PKG" .
fi
echo "$(sha256 "$archive")  $(basename "$archive")" >"$archive.sha256"
cat "$archive.sha256"
