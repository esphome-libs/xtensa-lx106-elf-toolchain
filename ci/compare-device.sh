#!/bin/bash
# Compare the device libraries and headers of two toolchains. Debug sections
# are removed first, they hold build directory paths. Members and headers listed
# in ci/device-changes.txt are changed on purpose, and must differ.
# Usage: compare-device.sh <reference toolchain dir> <toolchain dir>
set -uo pipefail
export LC_ALL=C

reference=$(cd "${1:?reference dir required}" && pwd)
built=$(cd "${2:?toolchain dir required}" && pwd)
bin=$built/bin/xtensa-lx106-elf
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0
expected=$(grep -v '^#' "$(dirname "$0")/device-changes.txt" | sed '/^$/d')
seen=$work/seen.txt
: >"$seen"

is_expected() { # <archive or header dir> <member or file>
  echo "$expected" | grep -qxF "$1 $2" && echo "$1 $2" >>"$seen"
}

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
  unexpected=0
  for m in $(diff "$work/r.$n.txt" "$work/b.$n.txt" | sed -n 's/^[<>] [0-9a-f]*  //p' | sort -u); do
    if is_expected "$a" "$m"; then
      echo "CHANGED   $a $m (expected)"
    else
      echo "DIFFERS   $a $m"
      unexpected=1
    fi
  done
  if [ $unexpected = 0 ]; then
    echo "IDENTICAL $a ($(wc -l <"$work/r.$n.txt" | tr -d ' ') objects, apart from expected changes)"
  else
    failed=1
  fi
done

for dir in xtensa-lx106-elf/include lib/gcc/xtensa-lx106-elf/10.3.0/include include/xtensa; do
  unexpected=0
  for f in $( (cd "$reference/$dir" && find . -type f; cd "$built/$dir" && find . -type f) | sort -u); do
    f=${f#./}
    cmp -s "$reference/$dir/$f" "$built/$dir/$f" && continue
    if is_expected "$dir" "$f"; then
      echo "CHANGED   $dir/$f (expected)"
    else
      echo "DIFFERS   $dir/$f"
      unexpected=1
    fi
  done
  if [ $unexpected = 0 ]; then
    echo "IDENTICAL $dir (apart from expected changes)"
  else
    failed=1
  fi
done

# An entry that no longer differs is stale
while read -r entry; do
  [ -z "$entry" ] && continue
  if ! grep -qxF "$entry" "$seen"; then
    echo "UNCHANGED $entry is listed in device-changes.txt but matches the reference"
    failed=1
  fi
done <<<"$expected"

exit $failed
