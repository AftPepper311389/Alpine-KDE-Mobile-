#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")"

OUT="${GUEST_MESA_OUTPUT:-$PWD/../../.work/guest-mesa.tar.xz}"
mkdir -p "$(dirname "$OUT")"

docker build --platform linux/arm64 -t archlinuxarm-guest-mesa .
docker run --platform linux/arm64 --rm archlinuxarm-guest-mesa cat /guest-mesa.tar.xz > "$OUT"
test -s "$OUT"
xz -t "$OUT"
sha256sum "$OUT"
