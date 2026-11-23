# Alpine KDE Mobile

A single-APK Android host for an embedded Alpine Linux ARM64 system with KDE Plasma.

## Non-negotiable target

- One installable APK containing the Alpine ARM64 filesystem and KDE Plasma payload.
- No root requirement.
- No separate Termux, Termux:X11, or other X server application.
- GitHub Actions is the only build environment; no local compilation is required.
- GPU acceleration is reported only after demonstrated on target hardware.

## Current implementation

GitHub Actions uses QEMU to run an ARM64 Alpine 3.24.4 container. The build installs the Alpine base system, KDE Plasma desktop/workspace/window manager, Konsole, and Dolphin from the official v3.24 main/community repositories. The resulting root filesystem is compressed and packaged into Android app assets. CI verifies the APK contains the rootfs, the Plasma Wayland session launcher, and an Alpine package/license inventory.

The app checks whether the embedded ARM64 rootfs archive is present. **The APK now targets an embedded KDE userspace, but this does not yet mean the desktop can be launched from Android.** Local extraction, process supervision/PRoot integration, an Android-hosted display/input bridge, and hardware GPU validation are still separate implementation tasks.

## Build

Push to `main` or run **Android CI** manually in GitHub Actions. The workflow builds the rootfs first, assembles the APK, verifies the embedded archive and license inventory, and uploads the APK artifact. The generated rootfs is not committed to Git.

## Architecture roadmap

1. **Embedded Alpine + KDE** — ARM64 rootfs, Plasma, KWin, Konsole, Dolphin, package inventory, and checksum in one APK.
2. **Local installation/runtime** — safe extraction into app-private storage, process supervision, and a no-root execution strategy.
3. **Display/input bridge** — integrate a compositor/rendering path hosted by the Android app, without requiring a second app.
4. **GPU path** — integrate Android-supported graphics APIs and validate actual hardware acceleration on the target device; software rendering is not counted.
5. **Release** — signed release APK, reproducible build metadata, complete third-party license notices, and on-device verification.

## Licensing

The build emits an Alpine package/license inventory from the installed APK database. Alpine packages and KDE components retain their upstream licenses; final distribution must include applicable license texts and attribution notices for every redistributed component.
