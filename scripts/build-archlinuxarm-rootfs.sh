#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${ROOTFS_DIR:-$PWD/.work/archlinuxarm-rootfs}"
ARCH_ROOTFS_URL="https://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
WORK="$(dirname "$ROOTFS")"
ARCHIVE="$WORK/ArchLinuxARM-aarch64-latest.tar.gz"

mkdir -p "$WORK"
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

echo "[1/7] Downloading the official Arch Linux ARM AArch64 root filesystem"
curl --fail --location --retry 5 --retry-all-errors --connect-timeout 30 \
  "$ARCH_ROOTFS_URL" -o "$ARCHIVE"
test -s "$ARCHIVE"
file "$ARCHIVE"
gzip -t "$ARCHIVE"

echo "[2/7] Extracting official rootfs with ACL/xattr/owner metadata"
bsdtar --no-same-owner --same-permissions --acls --xattrs -xpf "$ARCHIVE" -C "$ROOTFS"
test -x "$ROOTFS/usr/bin/pacman"
test -f "$ROOTFS/etc/pacman.conf"
test -d "$ROOTFS/usr/share/pacman/keyrings"

echo "[3/7] Preparing native ARM64 chroot"
mkdir -p "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run"
cp -L /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
mount --bind /dev "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
mount -t proc proc "$ROOTFS/proc"
mount --rbind /sys "$ROOTFS/sys"
mount --make-rslave "$ROOTFS/sys"
cleanup() {
  set +e
  umount -R "$ROOTFS/sys" 2>/dev/null
  umount "$ROOTFS/proc" 2>/dev/null
  umount "$ROOTFS/dev/pts" 2>/dev/null
  umount "$ROOTFS/dev" 2>/dev/null
}
trap cleanup EXIT

echo "[4/7] Initializing the official Arch Linux ARM package keyring"
chroot "$ROOTFS" /usr/bin/pacman-key --init
chroot "$ROOTFS" /usr/bin/pacman-key --populate archlinuxarm
chroot "$ROOTFS" /usr/bin/pacman -Syy --noconfirm

echo "[5/7] Installing KDE Plasma X11 and the complete desktop applications"
chroot "$ROOTFS" /usr/bin/pacman -Syu --noconfirm --needed \
  bash sudo shadow util-linux dbus polkit \
  plasma-desktop plasma-workspace kwin-x11 \
  dolphin konsole kate systemsettings \
  plasma-nm plasma-pa \
  xkeyboard-config xorg-xkbcomp xorg-xrdb xorg-xsetroot xorg-xwayland \
  mesa mesa-utils \
  noto-fonts noto-fonts-cjk ttf-dejavu breeze breeze-icons \
  fcitx5 fcitx5-qt fcitx5-gtk fcitx5-chinese-addons \
  pulseaudio pavucontrol \
  xdg-utils xdg-user-dirs networkmanager \
  fastfetch git curl wget python python-pip \
  tzdata ca-certificates procps-ng which file unzip zip

echo "[6/7] Configuring the desktop rootfs for PRoot + Lorie X11"
mkdir -p "$ROOTFS/etc/profile.d" "$ROOTFS/etc/xdg" "$ROOTFS/tmp" "$ROOTFS/run" \
  "$ROOTFS/usr/share/xsessions" "$ROOTFS/etc/sudoers.d"
chmod 1777 "$ROOTFS/tmp"
printf '%s\n' 'archlinux-kde-mobile' > "$ROOTFS/etc/hostname"
printf '%s\n' '127.0.0.1 localhost' '127.0.1.1 archlinux-kde-mobile' \
  '::1 localhost ip6-localhost' > "$ROOTFS/etc/hosts"
printf '%s\n' 'LANG=C.UTF-8' 'LC_ALL=C.UTF-8' > "$ROOTFS/etc/locale.conf"
for locale in en_US.UTF-8 UTF-8 zh_CN.UTF-8 UTF-8; do
  sed -i "s/^#\\($locale\\)/\\1/" "$ROOTFS/etc/locale.gen" 2>/dev/null || true
done
chroot "$ROOTFS" /usr/bin/locale-gen || true
printf '%s\n' 'Asia/Shanghai' > "$ROOTFS/etc/timezone"
ln -snf /usr/share/zoneinfo/Asia/Shanghai "$ROOTFS/etc/localtime"
cat > "$ROOTFS/etc/profile.d/00-mobile.sh" <<'EOF'
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LANGUAGE=zh_CN:zh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
export MALLOC_ARENA_MAX=2
export MESA_SHADER_CACHE_MAX_SIZE=128M
export QT_QUICK_CONTROLS_MATERIAL_VARIANT=Dense
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/.cache-$USER}"
EOF
printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' > "$ROOTFS/etc/sudoers.d/10-wheel"
chmod 0440 "$ROOTFS/etc/sudoers.d/10-wheel"
# Remove hardware-specific boot services and package caches; Android supplies the kernel/display.
chroot "$ROOTFS" /usr/bin/pacman -Scc --noconfirm || true
rm -rf "$ROOTFS/var/cache/pacman/pkg/"* "$ROOTFS/root/.cache/"* "$ROOTFS/tmp/"* 2>/dev/null || true

echo "[7/7] Verifying the complete KDE/X11 rootfs"
for binary in pacman bash su sudo dbus-run-session startplasma-x11 kwin_x11 dolphin konsole kate fcitx5; do
  test -x "$ROOTFS/usr/bin/$binary" || test -x "$ROOTFS/bin/$binary" || {
    echo "Missing required executable: $binary" >&2
    exit 1
  }
done
test -d "$ROOTFS/usr/share/X11/xkb"
test -f "$ROOTFS/usr/share/X11/xkb/rules/evdev"
test -f "$ROOTFS/usr/share/X11/xkb/symbols/us"
chroot "$ROOTFS" /usr/bin/pacman -Q plasma-desktop plasma-workspace kwin-x11 dolphin konsole kate
printf '%s\n' 'ROOTFS=Arch Linux ARM AArch64 official base + KDE Plasma' \
  'DESKTOP=KDE Plasma X11 / KWin X11' 'DISPLAY_BACKEND=Linuxhub Lorie X11' \
  > "$ROOTFS/etc/archlinux-kde-mobile-build-info"
du -sh "$ROOTFS"
echo "Arch Linux ARM KDE rootfs build completed."
