# Alpine KDE Mobile

A single-APK Android host for an embedded Alpine Linux ARM64 system with KDE Plasma.

## Target constraints

- One installable APK contains Alpine ARM64 and KDE Plasma; first installation does not download the Linux filesystem.
- No root and no separate Termux:X11 or other X server application.
- All compilation and packaging is performed by GitHub Actions.
- Hardware GPU acceleration is claimed only after validation on the target phone.

## Implemented in the repository

- GitHub Actions uses QEMU to run an ARM64 Alpine 3.24.4 container.
- The build installs Alpine base, KDE Plasma desktop/workspace, KWin, Konsole, and Dolphin from official Alpine v3.24 main/community repositories.
- The generated rootfs, checksum, build metadata, and package/license inventory are packaged into the APK.
- CI verifies the Plasma Wayland session launcher and required KDE packages are present.
- The Android app detects the embedded payload and can extract it offline into app-private storage. Extraction checks available storage, rejects archive path traversal, handles symlinks/hardlinks, and writes a completion marker only after successful extraction.

## Not yet implemented or validated

The current APK is **not yet a working KDE desktop**. The Linux rootfs can be embedded and locally extracted, but the app does not yet launch Linux processes or a Plasma session. A no-root execution layer, Android-hosted display/input bridge, and hardware GPU acceleration remain to be implemented and tested on-device. Do not interpret a successful APK build or filesystem extraction as proof of those features.

## Build

Push to `main` or run **Android CI** manually in GitHub Actions. The workflow builds the rootfs, assembles the APK, verifies its contents, and uploads the APK artifact. Generated rootfs binaries are not committed to Git.

## Next engineering stages

1. Integrate a no-root ARM64 Linux process runtime and supervise its lifecycle.
2. Launch and validate KDE services and the Plasma Wayland session in the runtime.
3. Integrate a display/compositor bridge hosted by the Android app, including touch, keyboard, and pointer input.
4. Validate GPU rendering through Android-supported graphics interfaces on the target hardware; software rendering does not count.
5. Produce a signed release APK with complete third-party license texts and on-device test evidence.

## Licensing

The build emits an Alpine package/license inventory from the installed APK database. Alpine and KDE components retain their upstream licenses; final distribution must include all applicable license texts and attributions.
