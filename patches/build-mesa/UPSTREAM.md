# Guest GPU driver bundle attribution

The files in this directory are adapted from the Local Desktop project:

- Upstream: https://github.com/localdesktop/localdesktop.github.io
- Upstream revision: `ac6295674cc0a2c437f80d71aab9995521274d28`
- License: GNU General Public License, version 3 (see `third_party/LOCALDESKTOP-GPL-3.0.txt`)

The build produces a private Mesa installation containing Freedreno/Turnip (Vulkan) and Zink (OpenGL over Vulkan), configured for the Qualcomm KGSL kernel interface. It is intended for supported Qualcomm Adreno GPUs. The session wrapper activates it only when the Vulkan probe detects a Turnip device; otherwise Arch Linux ARM's system Mesa remains active.

The Android-side compositor must still create its EGL/GLES context against the Android window. This guest driver bundle does not replace or implement that Android compositor.
