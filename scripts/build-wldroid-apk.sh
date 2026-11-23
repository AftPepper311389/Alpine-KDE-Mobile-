#!/usr/bin/env bash
set -euo pipefail

ROOT="$GITHUB_WORKSPACE"
WORK="$ROOT/.work/wldroid"
WLDROID_COMMIT="9560e767bb3e31f3d9b72d280e051c47cda35cf1"
ROOTFS_ARCHIVE="$ROOT/app/src/main/assets/alpine-rootfs-aarch64.tar.xz"
NDK_VERSION="28.0.13004108"

test -s "$ROOTFS_ARCHIVE"
rm -rf "$WORK"
mkdir -p "$(dirname "$WORK")"

git clone https://github.com/Shelnutt2/wldroid.git "$WORK"
git -C "$WORK" checkout --detach "$WLDROID_COMMIT"
git -C "$WORK" submodule update --init --recursive

python3 "$ROOT/scripts/patch-wldroid.py" "$WORK" "$ROOTFS_ARCHIVE"

mkdir -p "$WORK/testapp/src/main/assets"
cp "$WORK/LICENSE" "$WORK/testapp/src/main/assets/WLDROID-LICENSE.txt"
if [[ -f "$WORK/THIRD_PARTY_NOTICES.md" ]]; then
  cp "$WORK/THIRD_PARTY_NOTICES.md" "$WORK/testapp/src/main/assets/THIRD_PARTY-NOTICES.txt"
fi
cat > "$WORK/testapp/src/main/assets/WLDROID-SOURCE-NOTICE.txt" <<EOF
WLDroid Android Wayland/PRoot/VirGL integration
Repository: https://github.com/Shelnutt2/wldroid
Pinned commit: $WLDROID_COMMIT
License: see WLDROID-LICENSE.txt and THIRD-PARTY-NOTICES.txt
The APK includes WLDroid's Android compositor, PRoot runtime, VirGL server, and Linux compatibility shims.
EOF

export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
export ANDROID_NDK="$ANDROID_NDK_HOME"
test -d "$ANDROID_NDK_HOME"

cd "$WORK"
./gradlew --no-daemon --stacktrace -PoverrideVersion=1.0.0 :testapp:assembleDebug

APK="$(find "$WORK/testapp/build/outputs/apk/debug" -maxdepth 1 -type f -name '*.apk' -print -quit)"
test -n "$APK"
mkdir -p "$ROOT/app/build/outputs/apk/debug"
cp "$APK" "$ROOT/app/build/outputs/apk/debug/app-debug.apk"

echo "Built Alpine KDE Mobile APK:"
ls -lh "$ROOT/app/build/outputs/apk/debug/app-debug.apk"
