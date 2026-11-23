# CI validation checklist

The Actions workflow must prove that the distributable APK contains:

- Alpine ARM64 rootfs as a bundled tar.xz asset and a matching SHA-256 checksum
- PRoot executable and loader
- WLDroid Android Wayland compositor
- VirGL GLES server and graphics compatibility shims
- WLDroid and upstream third-party license texts
- Android package ID `org.alpinekde.mobile`

A green CI run validates packaging and native compilation only. It does not prove that PRoot, nested KWin/Plasma, touch input, or hardware GPU acceleration works on a physical phone. Those require an Android device test and runtime logs.
