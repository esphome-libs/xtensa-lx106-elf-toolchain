#!/bin/bash
# Compare the device libraries and headers of two toolchains. Debug sections
# are removed first, they hold build directory paths.
# Usage: compare-device.sh <reference toolchain dir> <toolchain dir>
set -uo pipefail
export LC_ALL=C

reference=$(cd "${1:?reference dir required}" && pwd)
built=$(cd "${2:?toolchain dir required}" && pwd)
bin=$built/bin/xtensa-lx106-elf
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

hash_members() { # <archive> <dir>
  mkdir -p "$2" && cd "$2" || exit 1
  "$bin-ar" x "$1"
  for o in *; do
    "$bin-objcopy" --strip-debug "$o" "$o.stripped"
    echo "$(sha256 <"$o.stripped")  $o"
  done | sort -k2
}

for a in $(cd "$reference" && find lib xtensa-lx106-elf/lib -name '*.a' | sort); do
  case $a in
    # Host libraries for gdb, not part of our packages
    *libcc1* | *libcp1*) continue ;;
  esac
  if [ ! -f "$built/$a" ]; then
    echo "MISSING   $a"
    failed=1
    continue
  fi
  n=$(echo "$a" | tr '/' '_')
  hash_members "$reference/$a" "$work/r/$n" >"$work/r.$n.txt"
  hash_members "$built/$a" "$work/b/$n" >"$work/b.$n.txt"
  if diff -q "$work/r.$n.txt" "$work/b.$n.txt" >/dev/null; then
    echo "IDENTICAL $a ($(wc -l <"$work/r.$n.txt" | tr -d ' ') objects)"
  else
    echo "DIFFERS   $a"
    diff "$work/r.$n.txt" "$work/b.$n.txt" | head -10
    failed=1
  fi
done

for dir in xtensa-lx106-elf/include lib/gcc/xtensa-lx106-elf/10.3.0/include include/xtensa; do
  if diff -r "$reference/$dir" "$built/$dir" >"$work/headers.txt" 2>&1; then
    echo "IDENTICAL $dir"
  else
    echo "DIFFERS   $dir"
    head -10 "$work/headers.txt"
    failed=1
  fi
done

exit $failed
