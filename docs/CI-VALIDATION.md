# CI validation checklist

The workflow is split into two reproducible jobs:

1. Build the official Alpine 3.24 ARM64 rootfs on a native GitHub ARM64 runner, install KDE Plasma and Mesa, pack it as tar.xz, and verify its package inventory and SHA-256.
2. On an x86-64 runner, build WLDroid's Android compositor, PRoot, VirGL GLES server, graphics shims, and the installable APK.

The final APK verification must prove that it contains:

- The embedded Alpine ARM64 rootfs and matching SHA-256
- PRoot executable and loader
- WLDroid Android Wayland compositor
- VirGL GLES server and graphics compatibility shims
- Bundled XKB keyboard maps
- WLDroid, PRoot, wlroots, VirGL, talloc, libepoxy, Wayland, and Alpine package license notices
- Android package ID `org.alpinekde.mobile`

A green CI run proves native compilation and APK packaging only. It does not prove that PRoot, nested KWin/Plasma, touch input, or hardware GPU acceleration works on a physical phone. Those require an Android device test and runtime logs.
