# Arch Linux KDE Mobile

A single-APK, rootless ARM64 Linux desktop for Android.

## Source base

The Android application is built from the upstream [Linuxhub 1.2.0](https://github.com/xishanp/Linuxhub/tree/1.2.0) source at commit `dc90ca29ec502ff91b31d2fa4c172f885b2d3d7c`. This repository contains the migration overlay and CI workflow; CI fetches and verifies the complete upstream source tree before applying the migration.

## Runtime design

- Preserve Linuxhub's Android application, PRoot runtime, and Lorie X11 display stack.
- Start from the official Arch Linux ARM AArch64 root filesystem: `ArchLinuxARM-aarch64-latest.tar.gz`.
- Build a full KDE Plasma X11 desktop into that rootfs on a native ARM64 runner; this is not a CLI-only rootfs.
- Include KWin X11, Dolphin, Konsole, Kate, audio, Fcitx5 Chinese input, CJK fonts, and common tools.
- Embed the complete compressed rootfs in the APK; first launch does not download a separate system image.
- Extract PAX/GNU long-path tar entries correctly, preserving long package paths and links.
- Create the Linux user and configure sudo during first launch.
- Keep Mesa shader cache and allocator defaults bounded for mobile memory use.

The official Arch Linux ARM AArch64 download is a base userspace. KDE is installed from the Arch Linux ARM AArch64 package repositories during the native ARM64 image build. The resulting embedded rootfs is the full desktop environment.

## Build

GitHub Actions verifies the official rootfs signature, builds the ARM64 KDE rootfs, embeds it into Linuxhub 1.2.0, builds the APK, and verifies the embedded rootfs checksum and ARM64 runtime libraries.

The output artifact is named `Linuxhub-1.2.0-ArchLinux-KDE-ARM64`.

## Validation

A successful CI build proves APK assembly and payload integrity. It does not by itself prove that Plasma starts correctly or that hardware GPU acceleration is active on a particular phone; those require an on-device test.

## License

Linuxhub source and third-party components retain their upstream licenses. See the upstream repository's license and notices.
