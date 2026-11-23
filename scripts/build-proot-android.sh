#!/usr/bin/env bash
set -euo pipefail

WORK="${RUNNER_TEMP:-/tmp}/proot-static-src"
ARTIFACT_DIR="$GITHUB_WORKSPACE/app/src/main/assets/proot"
OUT_DIR="${RUNNER_TEMP:-/tmp}/proot-static-build"
SOURCE_COMMIT="6f8ebfd8e24887dfba64c3f2d7d5fe9dc059b60e"

rm -rf "$WORK" "$OUT_DIR"
mkdir -p "$ARTIFACT_DIR"
git clone --filter=blob:none https://github.com/berilevi/proot-static.git "$WORK"
git -C "$WORK" checkout --detach "$SOURCE_COMMIT"

NDK="$ANDROID_HOME/ndk/28.2.13676358" \
OUT="$OUT_DIR" \
REPO_ARTIFACT_DIR="$ARTIFACT_DIR" \
ARCH=aarch64 API=21 \
bash "$WORK/tools/build-static-aarch64.sh"

cp "$WORK/COPYING" "$GITHUB_WORKSPACE/app/src/main/assets/PROOT-COPYING.txt"
cat > "$GITHUB_WORKSPACE/app/src/main/assets/PROOT-SOURCE-NOTICE.txt" <<EOF
PRoot Android static runtime
Source: https://github.com/berilevi/proot-static
Pinned source commit: $SOURCE_COMMIT
Upstream project: https://github.com/proot-me/PRoot
License: GNU General Public License version 2 (see PROOT-COPYING.txt)
The build uses the bundled talloc 2.4.2 source from the pinned repository.
EOF

test -x "$ARTIFACT_DIR/proot"
test -s "$ARTIFACT_DIR/loader"
file "$ARTIFACT_DIR/proot"
readelf -h "$ARTIFACT_DIR/proot" | grep -E 'Class:|Machine:'
sha256sum "$ARTIFACT_DIR"/* > "$ARTIFACT_DIR/SHA256SUMS"
