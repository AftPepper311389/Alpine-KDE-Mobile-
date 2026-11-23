#!/usr/bin/env bash
set -euo pipefail

ROOT="$GITHUB_WORKSPACE"
WORK="$ROOT/.work/doro"
DORO_REPO="https://github.com/AftPepper311389/doroUbuntu.git"
DORO_COMMIT="dc90ca29ec502ff91b31d2fa4c172f885b2d3d7c"
ROOTFS="$ROOT/.work/alpine-assets/alpine-rootfs-aarch64.tar.gz"
ROOTFS_SHA_FILE="$ROOT/.work/alpine-assets/alpine-rootfs-aarch64.tar.gz.sha256"

test -s "$ROOTFS"
test -s "$ROOTFS_SHA_FILE"
ROOTFS_SHA="$(awk '{print $1}' "$ROOTFS_SHA_FILE")"
echo "$ROOTFS_SHA  $ROOTFS" | sha256sum -c -

rm -rf "$WORK"
mkdir -p "$(dirname "$WORK")"
git clone --depth 1 "$DORO_REPO" "$WORK"
git -C "$WORK" checkout --detach "$DORO_COMMIT"

ASSETS="$WORK/app/src/main/assets"
mkdir -p "$ASSETS/rootfs"
cp "$ROOTFS" "$ASSETS/rootfs/alpine-kde-aarch64.tar.gz"
cp "$ROOTFS_SHA_FILE" "$ASSETS/rootfs/alpine-kde-aarch64.tar.gz.sha256"
cp "$ROOT/.work/alpine-assets/ALPINE-LICENSES.txt" "$ASSETS/ALPINE-LICENSES.txt"
cp "$ROOT/.work/alpine-assets/rootfs-build-info.txt" "$ASSETS/ALPINE-ROOTFS-BUILD-INFO.txt"
cp "$WORK/LICENSE" "$ASSETS/DORO-LICENSE.txt"
if [[ -f "$WORK/NOTICE" ]]; then cp "$WORK/NOTICE" "$ASSETS/DORO-NOTICE.txt"; fi
cat > "$ASSETS/ALPINE-KDE-SOURCE-NOTICE.txt" <<EOF
Android runtime base: https://github.com/AftPepper311389/doroUbuntu
Pinned source commit: $DORO_COMMIT
Root filesystem: Alpine Linux 3.22 ARM64 with KDE Plasma 6 / KWin X11
Root filesystem source: official Alpine v3.22 main and community repositories
Root filesystem SHA-256: $ROOTFS_SHA
The Android app uses the doroUbuntu PRoot and built-in Lorie X11 runtime, adapted for Alpine.
See DORO-LICENSE.txt, DORO-NOTICE.txt, and ALPINE-LICENSES.txt.
EOF

python3 "$ROOT/scripts/patch-doro-alpine.py" "$WORK" --rootfs-sha256 "$ROOTFS_SHA"

# These Ubuntu/XFCE-only offline payloads are not used by the Alpine adapter.
rm -rf "$ASSETS/offline" "$ASSETS/desktop" "$ASSETS/x11"

export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/29.0.14206865"
export ANDROID_NDK="$ANDROID_NDK_HOME"
export NDK_HOME="$ANDROID_NDK_HOME"
test -d "$ANDROID_NDK_HOME"

cd "$WORK"
./gradlew --no-daemon --stacktrace :app:assembleDebug

APK="$WORK/app/build/outputs/apk/debug/app-debug.apk"
test -s "$APK"
mkdir -p "$ROOT/app/build/outputs/apk/debug"
cp "$APK" "$ROOT/app/build/outputs/apk/debug/Alpine-KDE-Mobile.apk"

"$ANDROID_HOME/build-tools/35.0.0/aapt" dump badging "$APK" > "$ROOT/.work/doro/apk-badging.txt"
grep -q "package: name='org.alpinekde.mobile'" "$ROOT/.work/doro/apk-badging.txt"
unzip -Z1 "$APK" > "$ROOT/.work/doro/apk-contents.txt"
grep -q '^assets/rootfs/alpine-kde-aarch64.tar.gz$' "$ROOT/.work/doro/apk-contents.txt"
grep -q '^assets/ALPINE-LICENSES.txt$' "$ROOT/.work/doro/apk-contents.txt"
grep -q '^lib/arm64-v8a/libproot.so$' "$ROOT/.work/doro/apk-contents.txt"
grep -q '^lib/arm64-v8a/libproot-loader.so$' "$ROOT/.work/doro/apk-contents.txt"
grep -q '^assets/runtime/arm64-v8a/libgetifaddrs_bridge.so$' "$ROOT/.work/doro/apk-contents.txt"
EXPECTED_SHA="$ROOTFS_SHA"
ACTUAL_SHA="$(unzip -p "$APK" assets/rootfs/alpine-kde-aarch64.tar.gz | sha256sum | awk '{print $1}')"
test "$EXPECTED_SHA" = "$ACTUAL_SHA"
sha256sum "$APK"
ls -lh "$APK"
