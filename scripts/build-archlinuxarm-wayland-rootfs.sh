#!/usr/bin/env bash
set -Eeuo pipefail

ROOTFS="${ROOTFS_DIR:-$PWD/.work/archlinuxarm-wayland-rootfs}"
ARCH_ROOTFS_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz"
WORK="$(dirname "$ROOTFS")"
ARCHIVE="$WORK/ArchLinuxARM-aarch64-latest.tar.gz"
GUEST_MESA_TAR="${GUEST_MESA_TAR:-$WORK/guest-mesa.tar.xz}"

mkdir -p "$WORK"
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"

echo "[1/8] Downloading and verifying official Arch Linux ARM AArch64 rootfs"
curl --fail --location --retry 5 --retry-all-errors --connect-timeout 30 "$ARCH_ROOTFS_URL" -o "$ARCHIVE"
curl --fail --location --retry 5 --retry-all-errors --connect-timeout 30 "$ARCH_ROOTFS_URL.sig" -o "$ARCHIVE.sig"
export GNUPGHOME="$WORK/gnupg-wayland"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 68B3537F39A313B3E574D06777193F152BDBE6A6
FINGERPRINT="$(gpg --batch --with-colons --fingerprint 68B3537F39A313B3E574D06777193F152BDBE6A6 | awk -F: '$1 == "fpr" { print $10; exit }')"
test "$FINGERPRINT" = "68B3537F39A313B3E574D06777193F152BDBE6A6"
gpg --batch --verify "$ARCHIVE.sig" "$ARCHIVE"
gzip -t "$ARCHIVE"

echo "[2/8] Extracting the official rootfs"
bsdtar --same-permissions --acls --xattrs -xpf "$ARCHIVE" -C "$ROOTFS"
test -x "$ROOTFS/usr/bin/pacman"

echo "[3/8] Preparing a proper chroot mount namespace"
mkdir -p "$ROOTFS/dev/pts" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run" "$ROOTFS/var/cache/pacman/pkg"
# pacman CheckSpace needs the chroot root to be a visible mount point.
mount --bind "$ROOTFS" "$ROOTFS"
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
  umount "$ROOTFS" 2>/dev/null
}
trap cleanup EXIT
rm -f "$ROOTFS/etc/resolv.conf"
cp -L /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

echo "[4/8] Initializing Arch Linux ARM package signing"
chroot "$ROOTFS" /usr/bin/pacman-key --init
chroot "$ROOTFS" /usr/bin/pacman -Sy --noconfirm archlinuxarm-keyring
chroot "$ROOTFS" /usr/bin/pacman-key --populate archlinuxarm
chroot "$ROOTFS" /usr/bin/pacman-key --lsign-key 68B3537F39A313B3E574D06777193F152BDBE6A6
printf '\nLocalFileSigLevel = Required\n' >> "$ROOTFS/etc/pacman.conf"
chroot "$ROOTFS" /usr/bin/pacman -Syy --noconfirm

echo "[5/8] Installing current KDE Plasma Wayland and compositor packages"
chroot "$ROOTFS" /usr/bin/pacman -Syu --noconfirm --needed \
  bash sudo shadow util-linux dbus polkit \
  plasma-desktop plasma-workspace kwin \
  dolphin konsole kate systemsettings \
  plasma-nm plasma-pa plasma-keyboard \
  wayland wayland-protocols wayland-utils plasma-wayland-protocols \
  labwc xorg-xwayland xkeyboard-config \
  mesa mesa-utils vulkan-icd-loader vulkan-tools \
  noto-fonts noto-fonts-cjk ttf-dejavu breeze breeze-icons \
  fcitx5 fcitx5-qt fcitx5-gtk fcitx5-chinese-addons \
  pulseaudio pavucontrol \
  xdg-utils xdg-user-dirs networkmanager \
  fastfetch git curl wget python python-pip \
  tzdata ca-certificates procps-ng which file unzip zip

echo "[6/8] Adding the optional Qualcomm Adreno Turnip + Zink GPU stack"
if [[ -s "$GUEST_MESA_TAR" ]]; then
  tar -xJpf "$GUEST_MESA_TAR" -C "$ROOTFS"
  test -x "$ROOTFS/opt/localdesktop-mesa/bin/vkprobe"
  test -s "$ROOTFS/opt/localdesktop-mesa/env.sh"
  echo "Installed guest Mesa bundle: $(sha256sum "$GUEST_MESA_TAR" | awk '{print $1}')"
else
  echo "No guest Mesa bundle supplied; system Mesa remains installed."
fi

echo "[7/8] Configuring PRoot Wayland session, fallback compositor and GPU probe"
mkdir -p "$ROOTFS/etc/profile.d" "$ROOTFS/etc/xdg" "$ROOTFS/tmp" "$ROOTFS/run" \
  "$ROOTFS/usr/local/bin" "$ROOTFS/usr/share/labwc"
chmod 1777 "$ROOTFS/tmp"
printf '%s\n' 'archlinux-kde-wayland-mobile' > "$ROOTFS/etc/hostname"
printf '%s\n' '127.0.0.1 localhost' '127.0.1.1 archlinux-kde-wayland-mobile' \
  '::1 localhost ip6-localhost' > "$ROOTFS/etc/hosts"
printf '%s\n' 'LANG=C.UTF-8' 'LC_ALL=C.UTF-8' > "$ROOTFS/etc/locale.conf"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' "$ROOTFS/etc/locale.gen" 2>/dev/null || true
sed -i 's/^#zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' "$ROOTFS/etc/locale.gen" 2>/dev/null || true
chroot "$ROOTFS" /usr/bin/locale-gen || true
printf '%s\n' 'Asia/Shanghai' > "$ROOTFS/etc/timezone"
ln -snf /usr/share/zoneinfo/Asia/Shanghai "$ROOTFS/etc/localtime"
cat > "$ROOTFS/etc/profile.d/00-mobile.sh" <<'EOF'
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LANGUAGE=zh_CN:zh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
export MALLOC_ARENA_MAX=2
export MESA_SHADER_CACHE_MAX_SIZE=256M
export QT_QUICK_CONTROLS_MATERIAL_VARIANT=Dense
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/.cache-$USER}"
EOF
cat > "$ROOTFS/usr/local/bin/start-kde-wayland" <<'EOF'
#!/usr/bin/bash
set -Eeuo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export DESKTOP_SESSION=plasma
export KDE_SESSION_VERSION=6
export KDE_FULL_SESSION=true
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
socket="$WAYLAND_DISPLAY"
[[ "$socket" = /* ]] || socket="$XDG_RUNTIME_DIR/$socket"
for _ in $(seq 1 100); do
  [[ -S "$socket" ]] && break
  sleep 0.1
done
if [[ ! -S "$socket" ]]; then
  echo "No Android-host Wayland compositor socket: $socket" >&2
  echo "Start the app's native Wayland compositor before launching Plasma." >&2
  exit 70
fi
if [[ -r /opt/localdesktop-mesa/env.sh ]]; then
  # Activates Turnip/Zink only when the Adreno GPU probe succeeds.
  source /opt/localdesktop-mesa/env.sh
fi
exec /usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland
EOF
cat > "$ROOTFS/usr/local/bin/start-wayland-rescue" <<'EOF'
#!/usr/bin/bash
set -Eeuo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=labwc
export QT_QPA_PLATFORM=wayland
socket="$WAYLAND_DISPLAY"
[[ "$socket" = /* ]] || socket="$XDG_RUNTIME_DIR/$socket"
[[ -S "$socket" ]] || { echo "No Android-host Wayland compositor socket: $socket" >&2; exit 70; }
if [[ -r /opt/localdesktop-mesa/env.sh ]]; then source /opt/localdesktop-mesa/env.sh; fi
labwc &
sleep 2
dolphin --new-window &
exec konsole
EOF
cat > "$ROOTFS/usr/local/bin/check-wayland-gpu" <<'EOF'
#!/usr/bin/bash
set -u
echo "=== Vulkan devices ==="
if command -v vulkaninfo >/dev/null; then vulkaninfo --summary 2>&1 | head -80; else echo "vulkaninfo not installed"; fi
echo "=== EGL renderer ==="
if command -v eglinfo >/dev/null; then eglinfo -B -p wayland 2>&1 | grep -E 'EGL vendor|EGL version|Device|OpenGL vendor|OpenGL renderer|OpenGL core profile renderer' | head -40; else echo "eglinfo not installed"; fi
if [[ -x /opt/localdesktop-mesa/bin/vkprobe ]]; then
  echo "=== Adreno Turnip probe ==="
  if /opt/localdesktop-mesa/bin/vkprobe; then echo "Turnip GPU available; Zink can use hardware acceleration."; else echo "Turnip GPU unavailable; guest Mesa will use the system fallback."; fi
fi
EOF
chmod 0755 "$ROOTFS/usr/local/bin/start-kde-wayland" "$ROOTFS/usr/local/bin/start-wayland-rescue" "$ROOTFS/usr/local/bin/check-wayland-gpu"
printf '%s\n' '%wheel ALL=(ALL:ALL) ALL' > "$ROOTFS/etc/sudoers.d/10-wheel"
chmod 0440 "$ROOTFS/etc/sudoers.d/10-wheel"
chroot "$ROOTFS" /usr/bin/passwd -l root || true
chroot "$ROOTFS" /usr/bin/passwd -l alarm || true
chroot "$ROOTFS" /usr/bin/pacman -Scc --noconfirm || true
rm -rf "$ROOTFS/var/cache/pacman/pkg/"* "$ROOTFS/root/.cache/"* "$ROOTFS/tmp/"* 2>/dev/null || true

echo "[8/8] Verifying KDE Wayland, KWin, labwc and GPU components"
for binary in pacman bash su sudo dbus-run-session startplasma-wayland kwin_wayland labwc dolphin konsole kate fcitx5 start-kde-wayland start-wayland-rescue check-wayland-gpu; do
  test -x "$ROOTFS/usr/bin/$binary" || test -x "$ROOTFS/usr/local/bin/$binary" || {
    echo "Missing required executable: $binary" >&2
    exit 1
  }
done
test -x "$ROOTFS/usr/lib/plasma-dbus-run-session-if-needed"
chroot "$ROOTFS" /usr/bin/bash -lc 'for binary in /usr/bin/kwin_wayland /usr/bin/plasmashell /usr/bin/labwc; do ldd "$binary" | grep -q "not found" && exit 1; done'
chroot "$ROOTFS" /usr/bin/pacman -Q plasma-desktop plasma-workspace kwin labwc wayland mesa
printf '%s\n' \
  'ROOTFS=Arch Linux ARM AArch64 official base + current KDE Plasma' \
  'DESKTOP=KDE Plasma Wayland' \
  'KDE_COMPOSITOR=KWin Wayland' \
  'RESCUE_COMPOSITOR=labwc (nested fallback; requires Android host compositor)' \
  'GPU=Android EGL/GLES compositor + optional Qualcomm KGSL Turnip/Zink guest drivers' \
  > "$ROOTFS/etc/archlinux-kde-mobile-build-info"
du -sh "$ROOTFS"
echo "Arch Linux ARM KDE Wayland rootfs build completed."
