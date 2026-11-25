# Arch Linux KDE Mobile

A rootless ARM64 Linux desktop for Android, based on Linuxhub 1.2.0.

## Base system

- Android application source: upstream [Linuxhub 1.2.0](https://github.com/xishanp/Linuxhub/tree/1.2.0), pinned to commit `dc90ca29ec502ff91b31d2fa4c172f885b2d3d7c`.
- Linux userspace: the official [Arch Linux ARM AArch64 root filesystem](https://archlinuxarm.org/platforms/armv8/generic).
- Desktop: current Arch Linux ARM KDE Plasma packages, updated with `pacman -Syu`.
- Runtime: Android + PRoot, no device root required.
- Target package: one APK with the desktop rootfs embedded; no separate rootfs download on first launch.

## Wayland desktop design

The target desktop session is **KDE Plasma Wayland**:

- `startplasma-wayland` starts the Plasma session.
- `kwin` / `kwin_wayland` is KDE's actual Wayland window manager and compositor.
- `labwc` is installed as a small secondary/rescue Wayland compositor for troubleshooting.
- `xorg-xwayland` is retained only for legacy X11 applications.
- The launch wrapper checks for the Android-host Wayland socket before starting Plasma. It exits with a clear diagnostic instead of producing a silent black screen when the socket is absent.

Important distinction: KWin and labwc are guest-side compositors. PRoot cannot take over Android's display device or DRM nodes. The app also needs an Android-side compositor that owns the Android window, creates the Wayland socket (normally `/tmp/wayland-0`), renders client surfaces with Android EGL/GLES, and forwards touch/keyboard/mouse input. The existing Linuxhub 1.2.0 display implementation is Lorie/X11; that Android-side Smithay compositor has **not yet been integrated into the Linuxhub Activity**. Therefore the separate Wayland rootfs build is a validated payload target, not yet a claim that the current APK can launch the Wayland desktop.

The compositor integration is based on the architecture demonstrated by [Local Desktop](https://github.com/localdesktop/localdesktop.github.io): Smithay inside the Android app, with the Linux desktop running as a Wayland client inside PRoot. Its source is GPL-3.0; the GPU build files adapted from it retain the upstream attribution and license in this repository.

## GPU acceleration

The GPU path has two distinct parts:

1. **Android display/compositor rendering:** the planned Smithay compositor uses Android's native EGL + OpenGL ES context on the app's window. This is hardware-backed when the Android EGL driver exposes the device GPU.
2. **Linux guest applications:** `patches/build-mesa` builds a private Mesa installation with Freedreno/Turnip (Vulkan via Qualcomm KGSL) and Zink (OpenGL over Vulkan). The session activates it only when `vkprobe` detects a compatible Adreno GPU; otherwise the distribution's Mesa fallback remains active.

The OPPO PHS110 uses a Qualcomm Snapdragon 695 with Adreno 619, so it is in the intended Turnip target family. Actual acceleration must still be verified on-device with:

```bash
check-wayland-gpu
eglinfo -B -p wayland | grep -E 'renderer|vendor'
```

A successful Turnip probe should report a Turnip Adreno renderer; the exact result depends on the Android kernel's KGSL access and driver compatibility. The CI build verifies the driver payload, not runtime GPU operation on the phone.

## Build outputs and validation

The CI workflow now has two distinct tracks:

- **Existing APK track:** still packages the current Linuxhub/Lorie X11 integration while the Android-side Wayland compositor is being ported.
- **Wayland rootfs track:** builds the latest Arch Linux ARM KDE Plasma Wayland environment, KWin, labwc rescue compositor, and the optional Adreno Turnip/Zink driver bundle. It uploads `archlinuxarm-wayland-kde-rootfs-aarch64` for the Android compositor integration step.

The Wayland rootfs builder is `scripts/build-archlinuxarm-wayland-rootfs.sh`. The existing APK builder is `scripts/build-archlinuxarm-rootfs.sh`.

A successful rootfs job proves package resolution, archive creation, and payload checks. It does not prove that Plasma starts on Android until the native compositor, Android surface lifecycle, input forwarding, and on-device GPU path are integrated and tested together.

## References

- [Arch Linux ARM AArch64 installation](https://archlinuxarm.org/platforms/armv8/generic)
- [Arch Linux ARM KDE Plasma packages](https://archlinuxarm.org/packages/aarch64/plasma-workspace)
- [ArchWiki: KDE / starting Plasma Wayland](https://wiki.archlinux.org/title/KDE)
- [Local Desktop compositor architecture](https://localdesktop.github.io/docs/developer/understanding-the-architecture/)
- [Local Desktop GPU acceleration](https://localdesktop.github.io/docs/user/gpu-acceleration/)

## Licensing

Linuxhub and all third-party components retain their upstream licenses. The adapted Local Desktop GPU build files are GPL-3.0; see `third_party/LOCALDESKTOP-GPL-3.0.txt` and `patches/build-mesa/UPSTREAM.md`.
