# Alpine KDE Mobile

A single-APK Android host for an embedded Alpine Linux ARM64 system with KDE Plasma as the target desktop.

## Non-negotiable target

- One installable APK containing the Alpine ARM64 filesystem and KDE Plasma payload.
- No root requirement.
- No separate Termux, Termux:X11, or other X server application.
- GitHub Actions is the only build environment; no local compilation is required.
- GPU acceleration must be reported only after it is demonstrated on target hardware.

## Current implementation

The CI pipeline builds an ARM64 Alpine filesystem inside an ARM64 Alpine container (QEMU emulation on the GitHub runner), compresses it, and places the archive under Android app assets. Gradle then packages that archive into the APK. The build verifies that the archive contains the Alpine package manager and BusyBox.

The currently embedded filesystem is a **bootstrap Alpine userspace**, not yet the full KDE Plasma desktop. The Android app currently verifies the embedded payload; it does not yet extract, chroot/PRoot, or launch a Plasma session. Display integration, input forwarding, ADB-assisted setup, and hardware GPU acceleration remain unimplemented and unverified.

## Build

Push to `main` or run **Android CI** manually in GitHub Actions. The workflow builds the ARM64 rootfs first, then assembles the APK and uploads it as an artifact. The rootfs is generated during CI and is not committed to Git.

## Architecture roadmap

1. **Embedded rootfs** — ARM64 Alpine base and checksum packaged in the APK.
2. **Local installation/runtime** — safe extraction into app-private storage, process supervision, and a PRoot-compatible execution layer where Android kernel restrictions require it.
3. **KDE payload** — install and verify Plasma desktop packages and dependencies inside the ARM64 rootfs.
4. **Display/input bridge** — integrate a compositor/rendering path hosted by the Android app, without requiring a second app.
5. **GPU path** — use Android-supported graphics APIs and validate actual hardware acceleration on the target device; software rendering is not counted.
6. **Release** — signed release APK, reproducible build metadata, license notices, and on-device verification.

## Licensing

Alpine packages and KDE components retain their respective upstream licenses. The final distribution must include the applicable license and attribution notices for every redistributed component.
