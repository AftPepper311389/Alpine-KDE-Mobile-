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
- CI builds a pinned ARM64 Android PRoot executable and companion loader with the Android NDK. These executables are packaged as native libraries so Android installs them in `nativeLibraryDir`, the executable location needed by modern Android SELinux/W^X policy.
- The Android app can extract the rootfs offline into app-private storage and includes a PRoot smoke-test action that attempts to run Alpine commands inside it.

## Not yet implemented or validated

The current APK is **not yet a working KDE desktop**. Rootfs packaging, local extraction, and the PRoot launch path are implemented in source, but PRoot has not yet been verified on the target phone and the app does not yet launch a Plasma session. An Android-hosted display/input compositor and a nested Plasma session remain to be integrated. Hardware GPU acceleration remains unverified. A successful APK build is not proof that PRoot, Plasma, display integration, or hardware acceleration works.

## Build

Push to `main` or run **Android CI** manually in GitHub Actions. The workflow builds the rootfs and PRoot runtime, assembles the APK, verifies its contents, and uploads the APK artifact. Generated rootfs and native binaries are not committed to Git.

## Next engineering stages

1. Verify the embedded PRoot executable and Alpine shell on the target device; fix Android kernel/SELinux compatibility issues.
2. Integrate a Wayland compositor hosted by the Android app and route touch, keyboard, and pointer input.
3. Run KDE's Wayland session nested inside that compositor and validate Plasma shell/window management.
4. Validate GPU rendering through Android-supported graphics interfaces on the target hardware; software rendering does not count.
5. Produce a signed release APK with complete third-party license texts and on-device test evidence.

## Licensing

The build emits an Alpine package/license inventory from the installed APK database. PRoot is GPL-2.0 and its corresponding source is pinned in the build script; Alpine/KDE packages and bundled dependencies retain their upstream licenses. Final distribution must include all applicable license texts and attributions.
