#!/usr/bin/env sh
set -eu

ROOTFS="${ROOTFS_DIR:-$PWD/.work/alpine-rootfs}"
APK_REPO="https://dl-cdn.alpinelinux.org/alpine/v3.21"
mkdir -p "$ROOTFS/etc/apk" "$ROOTFS/etc/profile.d" "$ROOTFS/root" "$ROOTFS/tmp"
printf '%s\n' "$APK_REPO/main" "$APK_REPO/community" > "$ROOTFS/etc/apk/repositories"

apk --root "$ROOTFS" --initdb --arch aarch64 --keys-dir /etc/apk/keys \
  --repositories-file "$ROOTFS/etc/apk/repositories" add --no-cache \
  alpine-base bash shadow sudo util-linux-login dbus dbus-x11 polkit elogind xkeyboard-config xkbcomp \
  plasma-desktop plasma-workspace plasma-workspace-x11 kwin \
  dolphin konsole kate systemsettings plasma-nm plasma-pa \
  pulseaudio xwayland xdg-utils xdg-desktop-portal xdg-desktop-portal-gtk \
  fcitx5 fcitx5-gtk fcitx5-qt fcitx5-chinese-addons \
  mesa-dri-gallium mesa-egl mesa-gl mesa-gles gcompat \
  font-noto font-noto-cjk ttf-dejavu breeze breeze-icons \
  fastfetch git curl wget python3 py3-pip \
  tzdata ca-certificates shared-mime-info procps coreutils util-linux

# Use Alpine's real util-linux su binary, not a fabricated file or a BusyBox symlink.
# util-linux-login supplies /bin/su and its PAM/runtime dependencies.
test -x "$ROOTFS/bin/su"
test ! -L "$ROOTFS/bin/su"
apk --root "$ROOTFS" info -W /bin/su | grep -q "util-linux-login"
mkdir -p "$ROOTFS/usr/bin"
ln -sfn /bin/su "$ROOTFS/usr/bin/su"
test -x "$ROOTFS/usr/bin/su"
chroot "$ROOTFS" /bin/su --version

rm -rf "$ROOTFS/var/cache/apk/"* "$ROOTFS/root/.cache/"* "$ROOTFS/tmp/"* 2>/dev/null || true
mkdir -p "$ROOTFS/etc/profile.d" "$ROOTFS/etc/xdg" "$ROOTFS/tmp" "$ROOTFS/run"
printf '%s\n' 'nameserver 1.1.1.1' 'nameserver 8.8.8.8' > "$ROOTFS/etc/resolv.conf"
printf '%s\n' 'alpine-kde' > "$ROOTFS/etc/hostname"
printf '%s\n' 'export LANG=C.UTF-8' 'export LC_ALL=C.UTF-8' \
  'export LANGUAGE=zh_CN:zh' 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
  > "$ROOTFS/etc/profile.d/00-locale.sh"
cat > "$ROOTFS/etc/profile.d/99-mobile-memory.sh" <<'EOF'
export MALLOC_ARENA_MAX=2
export MESA_SHADER_CACHE_MAX_SIZE=128M
export QT_QUICK_CONTROLS_MATERIAL_VARIANT=Dense
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/.cache-$USER}"
EOF
printf '%s\n' 'Asia/Shanghai' > "$ROOTFS/etc/timezone"
ln -snf /usr/share/zoneinfo/Asia/Shanghai "$ROOTFS/etc/localtime"
mkdir -p "$ROOTFS/usr/share/xsessions"
test -x "$ROOTFS/usr/bin/startplasma-x11"
test -x "$ROOTFS/usr/bin/kwin_x11"
test -x "$ROOTFS/usr/bin/dbus-run-session"
test -x "$ROOTFS/usr/bin/dolphin"
test -x "$ROOTFS/usr/bin/konsole"
test -d "$ROOTFS/usr/share/X11/xkb"
test -f "$ROOTFS/usr/share/X11/xkb/rules/evdev"
test -f "$ROOTFS/usr/share/X11/xkb/symbols/us"
test -x "$ROOTFS/usr/bin/xkbcomp"
printf '%s\n' 'ROOTFS=Alpine 3.21 aarch64' 'DESKTOP=KDE Plasma 6 X11' 'DISPLAY_BACKEND=Lorie X11' \
  > "$ROOTFS/etc/alpine-kde-mobile-build-info"
