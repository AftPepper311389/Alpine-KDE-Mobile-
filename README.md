# Alpine KDE Mobile

A single-APK, rootless ARM64 Linux desktop for Android.

## Source base

The Android application is built from the upstream [Linuxhub 1.2.0](https://github.com/xishanp/Linuxhub/tree/1.2.0) source tag. This repository contains the Alpine migration overlay and CI build recipe; it does not maintain a parallel Android runtime.

## Runtime design

- Preserve Linuxhub's Android application, PRoot runtime, and embedded Lorie X11 display stack.
- Replace the Ubuntu userspace with an embedded Alpine Linux 3.21 ARM64 root filesystem.
- Use KDE Plasma 6 with the X11 session (startplasma-x11, kwin_x11), matching the upstream Lorie X11 display server.
- Include Dolphin, Konsole, Kate, audio, Fcitx5 input, and common development tools in the root filesystem.
- Create the Linux user and configure sudo during first launch.
- Keep the root filesystem inside the APK; first launch must not download a separate rootfs.
- Use bounded Mesa shader cache and allocator settings to reduce memory pressure on mobile devices.

## Build

GitHub Actions builds the ARM64 Alpine rootfs, embeds it into the Linuxhub 1.2.0 application, builds the APK, and verifies the embedded rootfs checksum and native runtime files.

The output artifact is named Linuxhub-1.2.0-Alpine-KDE-ARM64.

## Validation

A successful CI build proves APK assembly and payload integrity. It does not by itself prove that Plasma starts correctly or that hardware GPU acceleration is active on a particular phone; those require an on-device test.

## License

Linuxhub source and third-party components retain their upstream licenses. See the upstream repository's license and notices.
