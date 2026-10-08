#!/bin/bash
# Check that section attributes inside templates reach the instantiation
# (patches/gcc/gcc-template-section-attribute.patch).
# Usage: check-template-sections.sh <toolchain dir>
set -euo pipefail
export LC_ALL=C

ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(cd "${1:?toolchain dir required}" && pwd)/bin/xtensa-lx106-elf
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

"$T-g++" -Os -mlongcalls -mtext-section-literals -ffunction-sections -fdata-sections -std=gnu++20 \
  -c "$ROOT/tests-sections/template_section.cpp" -o "$WORK/template_section.o"
symbols=$("$T-objdump" -t "$WORK/template_section.o")

status=0
check() { # <section> <symbol pattern>
  if ! grep -E "[[:space:]]$1[[:space:]].*$2" <<<"$symbols" >/dev/null; then
    echo "missing: $2 in $1"
    status=1
  fi
}
check '\.irom\.text\.template_data' '_ZZN5TableIiE3getEvE6values'
check '\.iram\.text\.template_func' '_Z5twiceIiET_S0_'
check '\.irom\.text\.template_member' '_ZN6MemberIiE6valuesE'
if [ $status -ne 0 ]; then
  echo "$symbols"
fi
exit $status
