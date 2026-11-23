#!/bin/sh
set -eu

ROOTFS="/workspace/.work/alpine-rootfs"
ASSETS="/workspace/app/src/main/assets"
ARCHIVE="$ASSETS/alpine-rootfs-aarch64.tar.xz"
REPOSITORIES="/workspace/.work/repositories"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS" "$ASSETS" /workspace/.work

# GNU tar + xz are build-container tools; they are not installed into the guest.
apk add --no-cache tar xz

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
    add alpine-base bash ca-certificates tzdata fontconfig font-dejavu font-freefont dbus sudo gcompat \
        plasma-desktop plasma-workspace kwin konsole dolphin xwayland \
        mesa-dri-gallium mesa-egl mesa-gbm mesa-gl mesa-gles libdrm \
        libxkbcommon xkeyboard-config

mkdir -p "$ROOTFS/etc/apk"
cp "$REPOSITORIES" "$ROOTFS/etc/apk/repositories"
printf '%s\n' "Alpine KDE Mobile ARM64 rootfs" > "$ROOTFS/etc/alpine-kde-mobile"

grep -E '^P:(alpine-base|plasma-desktop|plasma-workspace|kwin|gcompat|mesa-dri-gallium|mesa-egl|mesa-gbm|xwayland)$' \
    "$ROOTFS/lib/apk/db/installed" > "$ASSETS/alpine-kde-package-check.txt"

# Preserve a machine-readable package/license inventory for redistribution notices.
awk '
    /^P:/ { package=$0 }
    /^V:/ { version=$0 }
    /^L:/ { print package " " version " " $0 }
' "$ROOTFS/lib/apk/db/installed" > "$ASSETS/ALPINE-LICENSES.txt"

cat > "$ASSETS/rootfs-build-info.txt" <<'EOF'
ALPINE_VERSION=3.24.4
ARCHITECTURE=aarch64
KDE_DESKTOP=installed
KDE_COMPONENTS=plasma-desktop,plasma-workspace,kwin
APPLICATIONS=konsole,dolphin
GPU_GUEST_STACK=mesa-dri-gallium,mesa-egl,mesa-gbm,mesa-gl,mesa-gles
GLIBC_COMPATIBILITY=gcompat
ROOTFS_SOURCE=official Alpine v3.24 main and community repositories
ROOTFS_FORMAT=tar.xz
EOF

tar -C "$ROOTFS" --numeric-owner -cJf "$ARCHIVE" .
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

echo "Built Alpine ARM64 + KDE Plasma rootfs:"
du -h "$ARCHIVE"
grep -E '^P:(plasma-desktop|plasma-workspace|kwin)$' "$ROOTFS/lib/apk/db/installed"
test -x "$ROOTFS/usr/bin/startplasma-wayland"
