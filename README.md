# Arch Linux KDE Mobile

A single-APK, rootless ARM64 Linux desktop for Android.

## Source base

The Android application is based on the upstream [Linuxhub 1.2.0](https://github.com/xishanp/Linuxhub/tree/1.2.0) source at commit `dc90ca29ec502ff91b31d2fa4c172f885b2d3d7c`. This repository contains the migration overlay and CI workflow.

## Target runtime design

- Use the official Arch Linux ARM AArch64 root filesystem as the base: `ArchLinuxARM-aarch64-latest.tar.gz`.
- Install KDE Plasma and desktop applications from signed Arch Linux ARM repositories.
- Use the native **Plasma Wayland** session (`startplasma-wayland`), not a Plasma X11 session.
- Keep the complete Arch Linux ARM + KDE userspace embedded in one APK; no separate rootfs download on first launch.
- Preserve rootless PRoot execution, first-launch user creation, sudo configuration, Chinese fonts/input, audio, and mobile memory limits.
- Keep Xwayland only as an optional compatibility layer for legacy X11 applications; it is not the desktop display server.

## Display architecture migration

Arch Linux recommends the Plasma Wayland session; the X11 session is a separate optional package in older Plasma releases and is no longer available starting with Plasma 6.8. See the [ArchWiki KDE guide](https://wiki.archlinux.org/title/KDE) and [Wayland guide](https://wiki.archlinux.org/title/Wayland).

A Wayland desktop needs a Wayland compositor, not an X server. The existing Linuxhub 1.2.0 Android display path is Lorie/X11, so changing only the Linux package list or replacing `startplasma-x11` with `startplasma-wayland` is not sufficient. The Android side must also provide a compositor, create a Wayland socket inside the PRoot environment, render Wayland surfaces to the Android activity, and translate touch/keyboard/mouse input.

**Migration status:** the current migration branch still contains the Lorie/X11 display service. The Wayland compositor integration and the corresponding removal of the X11 runtime are not yet complete. Until those pieces are implemented and tested together, this branch must not be treated as a working Wayland APK.

The intended Wayland implementation is an in-app compositor based on the Smithay approach used by [Local Desktop](https://github.com/localdesktop/localdesktop.github.io), subject to checking and preserving its GPL-3.0 licensing and required notices. No external Termux:X11 app is part of the target design.

## Build and validation

The intended CI pipeline will:

1. Verify the official Arch Linux ARM AArch64 rootfs signature.
2. Build the full KDE Plasma Wayland userspace on a native ARM64 runner.
3. Package the rootfs into the Linuxhub 1.2.0 Android application.
4. Build the standalone APK and verify the embedded rootfs checksum and ARM64 runtime libraries.
5. Run static checks for the Wayland socket, compositor integration, and absence of the legacy Lorie/X11 launch path.

A successful CI build proves APK assembly and payload integrity. It does not by itself prove that Plasma starts correctly or that hardware GPU acceleration works on a particular phone; those require on-device testing.

## License

Linuxhub source and third-party components retain their upstream licenses. Any reused compositor code must retain its upstream license and copyright notices. See the upstream repositories' licenses and notices.
