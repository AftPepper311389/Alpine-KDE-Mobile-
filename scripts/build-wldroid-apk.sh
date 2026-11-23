#!/usr/bin/env bash
set -euo pipefail

ROOT="$GITHUB_WORKSPACE"
WORK="$ROOT/.work/wldroid"
WLDROID_COMMIT="9560e767bb3e31f3d9b72d280e051c47cda35cf1"
ROOTFS_ARCHIVE="$ROOT/.work/alpine-assets/alpine-rootfs-aarch64.tar.xz"
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
License: MIT; see WLDROID-LICENSE.txt and THIRD-PARTY-NOTICES.txt
The APK includes WLDroid's Android compositor, PRoot runtime, VirGL server, and Linux compatibility shims.
PRoot is GPL-2.0; its corresponding COPYING file is included under assets/licenses.
EOF
cat > "$WORK/testapp/src/main/assets/THIRD-PARTY-LICENSE-INDEX.txt" <<'EOF'
Alpine packages and their license identifiers are listed in ALPINE-LICENSES.txt.
WLDroid license: WLDROID-LICENSE.txt.
Third-party source license texts are in assets/licenses/.
The embedded rootfs also retains any upstream license files installed under /usr/share/licenses.
EOF

export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
export ANDROID_NDK="$ANDROID_NDK_HOME"
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export NDK_HOME="$ANDROID_NDK_HOME"
test -d "$ANDROID_NDK_HOME"

cd "$WORK"
./gradlew --no-daemon --stacktrace -PoverrideVersion=1.0.0 :testapp:assembleDebug

LICENSE_DIR="$WORK/testapp/src/main/assets/licenses"
mkdir -p "$LICENSE_DIR"
copy_licenses() {
  local source_dir="$1"
  local prefix="$2"
  local files=()
  mapfile -d '' files < <(find "$source_dir" -maxdepth 2 -type f \( -iname 'COPYING*' -o -iname 'LICENSE*' \) -print0)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No license text found under $source_dir" >&2
    exit 1
  fi
  for file in "${files[@]}"; do
    cp "$file" "$LICENSE_DIR/${prefix}-$(basename "$file")"
  done
}
copy_licenses "$WORK/external/proot" "PRoot"
copy_licenses "$WORK/external/wlroots" "wlroots"
copy_licenses "$WORK/external/virglrenderer" "virglrenderer"
copy_licenses "$WORK/external/talloc" "talloc"
copy_licenses "$WORK/virgl/native/build/libepoxy-src" "libepoxy"
copy_licenses "$WORK/compositor/native/subprojects/wayland-1.24.0" "wayland"

./gradlew --no-daemon --stacktrace -PoverrideVersion=1.0.0 :testapp:assembleDebug

APK="$(find "$WORK/testapp/build/outputs/apk/debug" -maxdepth 1 -type f -name '*.apk' -print -quit)"
test -n "$APK"
mkdir -p "$ROOT/app/build/outputs/apk/debug"
cp "$APK" "$ROOT/app/build/outputs/apk/debug/app-debug.apk"

echo "Built Alpine KDE Mobile APK:"
ls -lh "$ROOT/app/build/outputs/apk/debug/app-debug.apk"
