# Alpine KDE Mobile

A single-APK Android application intended to run a bundled Alpine Linux ARM64 root filesystem with KDE Plasma, without Root, Termux, or a separate X11 application.

## Target

- One APK contains the Alpine ARM64 rootfs, KDE Plasma, the no-root Linux runtime, Android-hosted Wayland compositor, and graphics bridge.
- First launch extracts the bundled rootfs locally; it does not download Alpine or KDE.
- All build and packaging work runs in GitHub Actions. No local compilation is required.
- Android API 29+ is required by the integrated WLDroid compositor stack.
- Hardware GPU acceleration is only considered verified after testing on the target phone.

## Build architecture

The GitHub Actions workflow builds the Alpine rootfs in an ARM64 Alpine 3.24.4 container using the official v3.24 main and community repositories. It installs Plasma Desktop/Workspace, KWin, Konsole, Dolphin, Mesa GLES/GBM/DRI components, XWayland, and gcompat for compatibility with the graphics shims.

The APK is assembled from a pinned WLDroid source revision. WLDroid contributes:

- An Android-hosted Wayland compositor rendered into the app's own Android surface.
- PRoot for running the ARM64 Alpine userspace without Root.
- A VirGL GLES server and graphics compatibility shims.
- Android input, display, session, and process-lifecycle integration.

The integration patch changes WLDroid's initial environment from a Debian download to importing the embedded Alpine tar.xz archive, configures the Alpine library paths, extracts the bundled XKB keyboard maps before the compositor starts, and opens directly on the KDE desktop screen. The default desktop command is `dbus-run-session -- startplasma-wayland`, which is intended to start KWin nested under the app-hosted Wayland compositor.

## Current verification boundary

CI is configured to verify that the APK contains the Alpine KDE archive, WLDroid compositor, PRoot, VirGL server, graphics shims, and the expected Android package ID. **That is build-time verification, not proof that KDE launches or that the GPU is hardware-accelerated on a phone.** PRoot/SELinux compatibility, the nested KWin session, VirGL GLES, touch/keyboard behavior, and sustained desktop stability still require on-device testing. If VirGL cannot initialize, the app may need a software-rendering fallback; software rendering will not be described as hardware acceleration.

## Build and artifact

Push to `main` or run **Android CI** manually in GitHub Actions. The workflow builds the Alpine rootfs, checks its package inventory and checksum, clones the pinned WLDroid source and submodules, applies the Alpine integration patch, builds the native Android components, and assembles one APK. The artifact is named `alpine-kde-mobile-debug`.

The APK is expected to be large because the complete Linux userspace and graphics/runtime components are embedded. The rootfs is not committed to Git; it is generated during CI and packed directly into the APK.

## Next validation steps

1. Get a clean GitHub Actions build and inspect the resulting APK contents and size.
2. Install the APK on an Android API 29+ ARM64 phone and verify offline rootfs import.
3. Run the PRoot Alpine shell and confirm the nested KDE Plasma session starts.
4. Confirm VirGL reports the GLES path and validate actual Adreno/Android GPU activity; compare against software fallback.
5. Fix any device-specific launch, touch, keyboard, audio, and power-management issues.
6. Produce a signed release APK and a complete third-party license bundle.

## Licensing

Alpine package license metadata is included with the embedded rootfs. The build also includes WLDroid's license and third-party notices. PRoot, wlroots, VirGL, Mesa, KDE, and other components retain their upstream licenses; final distribution must preserve the applicable source and license obligations.
