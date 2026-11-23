#!/bin/sh
set -eu

ROOTFS="/workspace/.work/alpine-rootfs"
ASSETS="/workspace/app/src/main/assets"
ARCHIVE="$ASSETS/alpine-rootfs-aarch64.tar.gz"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS" "$ASSETS" /workspace/.work

# Build an actual ARM64 Alpine filesystem in an ARM64 container (QEMU on CI).
apk --root "$ROOTFS" \
    --initdb \
    --arch aarch64 \
    --keys-dir /etc/apk/keys \
    --repositories-file /etc/apk/repositories \
    add alpine-base bash ca-certificates tzdata fontconfig dbus

mkdir -p "$ROOTFS/etc/apk"
cp /etc/apk/repositories "$ROOTFS/etc/apk/repositories"
printf '%s\n' "Alpine KDE Mobile rootfs bootstrap" > "$ROOTFS/etc/alpine-kde-mobile"

tar -C "$ROOTFS" --numeric-owner -czf "$ARCHIVE" .
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"

echo "Built ARM64 Alpine rootfs:"
du -h "$ARCHIVE"
tar -tzf "$ARCHIVE" | grep -E '^\./(bin/busybox|sbin/apk|etc/alpine-kde-mobile)$'
