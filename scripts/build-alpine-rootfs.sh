#!/bin/sh
set -eu

ROOTFS="/workspace/.work/alpine-rootfs"
ASSETS="/workspace/.work/alpine-assets"
REPOSITORIES="/workspace/.work/repositories"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS" "$ASSETS" /workspace/.work

cat > "$REPOSITORIES" <<'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.24/main
https://dl-cdn.alpinelinux.org/alpine/v3.24/community
EOF

# Install genuine ARM64 Alpine packages in an ARM64 container (QEMU on CI).
apk --root "$ROOTFS" \
    --initdb \
    --arch aarch64 \
    --keys-dir /etc/apk/keys \
    --repositories-file "$REPOSITORIES" \
    add alpine-base bash ca-certificates tzdata fontconfig font-dejavu font-droid-nonlatin font-freefont dbus sudo gcompat \
        plasma-desktop plasma-workspace kwin konsole dolphin xwayland \
        mesa-dri-gallium mesa-egl mesa-gbm mesa-gl mesa-gles libdrm \
        libxkbcommon xkeyboard-config

# Drop package download caches; keep the apk database and repository configuration.
rm -rf "$ROOTFS/var/cache/apk" "$ROOTFS/tmp/"* "$ROOTFS/var/tmp/"*
mkdir -p "$ROOTFS/etc/apk"
cp "$REPOSITORIES" "$ROOTFS/etc/apk/repositories"
printf '%s\n' "Alpine KDE Mobile ARM64 rootfs" > "$ROOTFS/etc/alpine-kde-mobile"

grep -E '^P:(alpine-base|plasma-desktop|plasma-workspace|kwin|gcompat|mesa-dri-gallium|mesa-egl|mesa-gbm|mesa-gl|mesa-gles|xwayland)$' \
    "$ROOTFS/lib/apk/db/installed" > "$ASSETS/alpine-kde-package-check.txt"

# Preserve a machine-readable package/license inventory for redistribution notices.
awk '
    /^P:/ { package=$0 }
    /^V:/ { version=$0 }
    /^L:/ { print package " " version " " $0 }
' "$ROOTFS/lib/apk/db/installed" > "$ASSETS/ALPINE-LICENSES.txt"

ALPINE_RELEASE="$(cat "$ROOTFS/etc/alpine-release")"
cat > "$ASSETS/rootfs-build-info.txt" <<EOF
ALPINE_VERSION=$ALPINE_RELEASE
ARCHITECTURE=aarch64
KDE_DESKTOP=installed
KDE_COMPONENTS=plasma-desktop,plasma-workspace,kwin
APPLICATIONS=konsole,dolphin
GPU_GUEST_STACK=mesa-dri-gallium,mesa-egl,mesa-gbm,mesa-gl,mesa-gles
GLIBC_COMPATIBILITY=gcompat
ROOTFS_SOURCE=official Alpine v3.24 main and community repositories
ROOTFS_FORMAT=tar.xz
EOF

echo "Built Alpine ARM64 + KDE Plasma rootfs directory:"
du -sh "$ROOTFS"
grep -E '^P:(plasma-desktop|plasma-workspace|kwin)$' "$ROOTFS/lib/apk/db/installed"
test -x "$ROOTFS/usr/bin/startplasma-wayland"
test -x "$ROOTFS/usr/bin/kwin_wayland"
test -x "$ROOTFS/usr/bin/dbus-run-session"
test -x "$ROOTFS/usr/bin/Xwayland"
