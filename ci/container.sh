#!/bin/bash
# Run a command inside the Linux build image, with this checkout mounted at
# the same path so install prefixes match between steps.
# Ubuntu 20.04 keeps the glibc the programs need old enough for older distros.
# Usage: container.sh <command> [args ...]
# EXTRA_PACKAGES names further packages to install, such as the Windows
# cross compiler.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)

docker run --rm \
  -v "$ROOT:$ROOT" \
  -w "$ROOT" \
  -e VERSION \
  -e BUILD_TOOLCHAIN \
  -e SOURCE_DATE_EPOCH \
  -e EXTRA_PACKAGES \
  -e DEBIAN_FRONTEND=noninteractive \
  -e OWNER="$(id -u):$(id -g)" \
  ubuntu:20.04 \
  bash -c '
    set -euo pipefail
    apt-get update -qq >/dev/null
    # shellcheck disable=SC2086
    apt-get install -y -qq --no-install-recommends \
      build-essential bison flex gawk file ca-certificates ${EXTRA_PACKAGES:-} >/dev/null
    # Leave the files owned by the user outside the container, also on failure
    trap "chown -R $OWNER ." EXIT
    "$@"
  ' container "$@"
