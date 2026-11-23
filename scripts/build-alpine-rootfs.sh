#!/bin/sh
set -eu

ROOTFS="/workspace/.work/alpine-rootfs"
ASSETS="/workspace/app/src/main/assets"
ARCHIVE="$ASSETS/alpine-rootfs-aarch64.tar.gz"
REPOSITORIES="/workspace/.work/repositories"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS" "$ASSETS" /workspace/.work

cat > "$REPOSITORIES" <<'EOF'
https://dl-cdn.alpinelinux.org/alpine/v3.24/main
https://dl-cdn.alpinelinux.org/alpine/v3.24/community
EOF

# Install genuine ARM64 packages in an ARM64 Alpine container (QEMU on CI).
apk --root "$ROOTFS" \
    --initdb \
    --arch aarch64 \
    --keys-dir /etc/apk/keys \
    --repositories-file "$REPOSITORIES" \
    add alpine-base bash ca-certificates tzdata fontconfig dbus \
        plasma-desktop konsole dolphin

mkdir -p "$ROOTFS/etc/apk"
cp "$REPOSITORIES" "$ROOTFS/etc/apk/repositories"
printf '%s\n' "Alpine KDE Mobile ARM64 rootfs" > "$ROOTFS/etc/alpine-kde-mobile"
grep -E '^P:(alpine-base|plasma-desktop|plasma-workspace|kwin)$' \
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
ROOTFS_SOURCE=official Alpine v3.24 main and community repositories
EOF

tar -C "$ROOTFS" --numeric-owner -czf "$ARCHIVE" .
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

echo "Built Alpine ARM64 + KDE Plasma rootfs:"
du -h "$ARCHIVE"
grep -E '^P:(plasma-desktop|plasma-workspace|kwin)$' "$ROOTFS/lib/apk/db/installed"
test -x "$ROOTFS/usr/bin/startplasma-wayland"
