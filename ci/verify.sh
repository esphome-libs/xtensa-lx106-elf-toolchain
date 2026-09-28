#!/bin/bash
# Compile and link the test sources with a toolchain and write the sha256 of
# every output. Two toolchains that generate the same code give the same file.
# Usage: verify.sh <toolchain dir> <output file>
set -euo pipefail
export LC_ALL=C

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TOOLCHAIN=$(cd "${1:?toolchain dir required}" && pwd)
OUTPUT=${2:?output file required}
case $OUTPUT in
  /*) ;;
  *) OUTPUT=$PWD/$OUTPUT ;;
esac
T=$TOOLCHAIN/bin/xtensa-lx106-elf
WORK=$ROOT/verify-work

# The flags ESPHome compiles ESP8266 code with
COMMON=(-Os -mlongcalls -mtext-section-literals -falign-functions=4
  -ffunction-sections -fdata-sections -Wall -free -fipa-pta -U__STRICT_ANSI__)
CXXFLAGS=(-std=gnu++20 -fno-rtti -fno-exceptions)

sha256() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

"$T-gcc" --version | head -1
rm -rf "$WORK"
mkdir -p "$WORK"
# Relative paths only, so no output contains a directory of this machine
cd "$ROOT/tests"

objects=()
for src in *.c; do
  "$T-gcc" "${COMMON[@]}" -std=gnu17 -c "$src" -o "$WORK/$src.o"
  objects+=("$src.o")
done
for src in *.cpp; do
  [ "$src" = pch_user.cpp ] && continue
  "$T-g++" "${COMMON[@]}" "${CXXFLAGS[@]}" -c "$src" -o "$WORK/$src.o"
  objects+=("$src.o")
done
"$T-gcc" "${COMMON[@]}" -c startup.S -o "$WORK/startup.S.o"
objects+=(startup.S.o)

# A precompiled header must load, and give the same object as the plain
# header. GCC looks for it next to the header, so both live in the work dir.
cp pch.h "$WORK/pch.h"
"$T-g++" "${COMMON[@]}" "${CXXFLAGS[@]}" -x c++-header "$WORK/pch.h" -o "$WORK/pch.h.gch"
"$T-g++" "${COMMON[@]}" "${CXXFLAGS[@]}" -Winvalid-pch -Werror=invalid-pch -H \
  -include "$WORK/pch.h" -c pch_user.cpp -o "$WORK/pch_user.cpp.o" 2>"$WORK/pch.log"
if ! grep -q '^! ' "$WORK/pch.log"; then
  echo "The precompiled header was not loaded:"
  cat "$WORK/pch.log"
  exit 1
fi
"$T-g++" "${COMMON[@]}" "${CXXFLAGS[@]}" -c pch_user.cpp -o "$WORK/pch_user.plain.o"
cmp "$WORK/pch_user.cpp.o" "$WORK/pch_user.plain.o"
objects+=(pch_user.cpp.o)

cd "$WORK"
"$T-ar" rcsD libverify.a "${objects[@]}"
# Default linker script and the toolchain's own libraries. -nostdlib leaves
# out the simulator libraries the default link line asks for. On the chip,
# memcpy, malloc and the division helpers come from ROM and the Arduino core,
# so they stay unresolved here.
"$T-g++" "${COMMON[@]}" -nostdlib -Wl,--gc-sections -Wl,-e,_start \
  -Wl,--unresolved-symbols=ignore-all "${objects[@]}" \
  -Wl,--start-group -lstdc++ -lm -lc -lgcc -Wl,--end-group -o verify.elf
"$T-objcopy" -O binary verify.elf verify.bin
"$T-objcopy" --strip-debug verify.elf verify.stripped.elf
# Windows programs end text lines with CR LF
"$T-objdump" -d verify.stripped.elf | tr -d '\r' | tail -n +3 >verify.disasm
"$T-size" -A verify.stripped.elf | tr -d '\r' | tail -n +2 >verify.size
"$T-readelf" -S -W verify.stripped.elf | tr -d '\r' >verify.sections

for f in "${objects[@]}" libverify.a verify.bin verify.stripped.elf verify.disasm verify.size verify.sections; do
  echo "$(sha256 "$f")  $f"
done >"$OUTPUT"
cat "$OUTPUT"
