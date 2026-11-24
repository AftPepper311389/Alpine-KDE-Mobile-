#!/usr/bin/env bash
set -euo pipefail

SRC="${1:?usage: prepare-linuxhub-alpine.sh SOURCE_DIR ROOTFS_TAR}"
ROOTFS_TAR="${2:?missing rootfs archive}"
ASSETS="$SRC/app/src/main/assets"
mkdir -p "$ASSETS/rootfs"
install -m 0644 "$ROOTFS_TAR" "$ASSETS/rootfs/alpine-rootfs-aarch64.tar.gz"
sha256sum "$ASSETS/rootfs/alpine-rootfs-aarch64.tar.gz" | awk '{print $1}' > "$ASSETS/rootfs/alpine-rootfs-aarch64.tar.gz.sha256"

# Remove unused Ubuntu/XFCE offline payloads from Linuxhub 1.2.0.
rm -rf "$ASSETS/offline"
rm -f "$ASSETS/desktop/ubuntu-wallpaper.jpg" "$ASSETS/desktop/ubuntu-wallpaper.png" "$ASSETS/desktop/whitesur-xfce.tar"

python3 - "$SRC" "$ASSETS/rootfs/alpine-rootfs-aarch64.tar.gz.sha256" <<'PY'
from pathlib import Path
import re, sys

src = Path(sys.argv[1])
sha = Path(sys.argv[2]).read_text().strip()

def edit(rel, fn):
    p = src / rel
    s = p.read_text()
    out = fn(s)
    if out == s:
        raise SystemExit(f"Patch made no change: {rel}")
    p.write_text(out)

def once(s, old, new, label):
    if old not in s:
        raise SystemExit(f"Could not locate patch point: {label}")
    return s.replace(old, new, 1)

# RootFS location and distribution metadata.
edit("app/src/main/java/com/doro/terminal/shell/linux/ContainerPaths.kt",
     lambda s: s.replace('distributions/ubuntu-24.04/rootfs', 'distributions/alpine-3.21/rootfs'))

def patch_models(s):
    s = s.replace('distribution: String = "ubuntu"', 'distribution: String = "alpine"')
    s = s.replace('version: String = "24.04"', 'version: String = "3.21"')
    s = s.replace('ContainerConfig(\n                distribution = values.getProperty("distribution", "ubuntu"),\n                version = values.getProperty("version", "24.04"),',
                  'ContainerConfig(\n                distribution = values.getProperty("distribution", "alpine"),\n                version = values.getProperty("version", "3.21"),')
    s = s.replace('UBUNTU("Ubuntu 24.04", "基础组件", required = true, defaultSelected = true)',
                  'UBUNTU("Alpine Linux 3.21 ARM64", "基础组件", required = true, defaultSelected = true)')
    s = s.replace('APT("APT", "基础组件", required = true, defaultSelected = true)',
                  'APT("APK", "基础组件", required = true, defaultSelected = true)')
    s = s.replace('DESKTOP("XFCE 图形桌面", "桌面环境", defaultSelected = true)',
                  'DESKTOP("KDE Plasma 6 桌面", "桌面环境", defaultSelected = true)')
    s = s.replace('XFCE("XFCE 桌面", "内置组件", packages = listOf("xfce4", "xfce4-goodies"))',
                  'XFCE("KDE Plasma 6 / KWin X11", "内置组件", packages = listOf("plasma-desktop", "plasma-workspace-x11", "kwin"))')
    s = s.replace('X11("X11", "内置组件", packages = listOf("dbus-x11", "x11-xserver-utils", "xterm"))',
                  'X11("Lorie X11 显示服务", "内置组件", packages = listOf("dbus-x11"))')
    s = s.replace('FILE_MANAGER("文件管理器", "内置组件", packages = listOf("thunar", "mousepad"))',
                  'FILE_MANAGER("Dolphin 文件管理器", "内置组件", packages = listOf("dolphin", "konsole", "kate"))')
    s = s.replace('PYTHON("Python", "基础组件", defaultSelected = true, packages = listOf("python3", "python3-pip", "python3-venv"))',
                  'PYTHON("Python 3", "基础组件", defaultSelected = true, packages = listOf("python3", "py3-pip"))')
    s = s.replace('CHINESE("中文语言环境", "基础组件", defaultSelected = true, packages = listOf("locales", "language-pack-zh-hans", "fonts-noto-cjk"))',
                  'CHINESE("中文字体与输入", "基础组件", defaultSelected = true, packages = listOf("font-noto-cjk", "fcitx5", "fcitx5-chinese-addons"))')
    s = s.replace('FIREFOX("Mozilla Firefox", "内置应用")',
                  'FIREFOX("Mozilla Firefox", "内置应用", supported = false)')
    s = s.replace('PYTHON_AI("Python AI 环境", "AI 开发", packages = listOf("python3-numpy", "python3-scipy", "python3-pandas", "python3-sklearn"))',
                  'PYTHON_AI("Python AI 环境", "AI 开发", supported = false)')
    s = s.replace('JUPYTER("JupyterLab", "AI 开发", packages = listOf("jupyter-notebook"))',
                  'JUPYTER("JupyterLab", "AI 开发", supported = false)')
    s = s.replace('NODE("Node.js", "开发环境", packages = listOf("nodejs", "npm"))',
                  'NODE("Node.js", "开发环境", supported = false)')
    s = s.replace('JAVA("Java", "开发环境", packages = listOf("default-jdk"))',
                  'JAVA("Java", "开发环境", supported = false)')
    s = s.replace('GCC("GCC/G++", "开发环境", packages = listOf("build-essential"))',
                  'GCC("GCC/G++", "开发环境", supported = false)')
    s = s.replace('CMAKE("CMake", "开发环境", packages = listOf("cmake"))',
                  'CMAKE("CMake", "开发环境", supported = false)')
    s = s.replace('RUST("Rust", "开发环境", packages = listOf("rustc", "cargo"))',
                  'RUST("Rust", "开发环境", supported = false)')
    s = s.replace('GO("Go", "开发环境", packages = listOf("golang-go"))',
                  'GO("Go", "开发环境", supported = false)')
    return s
edit("app/src/main/java/com/doro/terminal/shell/linux/ContainerModels.kt", patch_models)

# Keep the proven Android/PRoot/Lorie X11 framework; replace Ubuntu deployment with the embedded Alpine archive.
def patch_manager(s):
    s = s.replace('zh_CN.UTF-8', 'C.UTF-8')
    s = s.replace('"Ubuntu 已完成初始化"', '"Alpine 已完成初始化"')
    s = s.replace('distribution = values.getProperty("distribution", "ubuntu")', 'distribution = values.getProperty("distribution", "alpine")')
    s = s.replace('version = values.getProperty("version", "24.04")', 'version = values.getProperty("version", "3.21")')
    s = s.replace('distribution = values.getProperty("distribution", "alpine")', 'distribution = "alpine"')
    s = s.replace('version = values.getProperty("version", "3.21")', 'version = "3.21"')
    s = s.replace('initialized = values.getProperty("initialized").toBoolean()',
                  'initialized = values.getProperty("initialized").toBoolean() && paths.rootfsReadyMarker.isFile && paths.rootfsReadyMarker.readText().contains("alpine-3.21-kde-x11")')
    s = once(s,
        'var state = loadInitializationState()?.takeIf { it.username == username }',
        'var state = loadInitializationState()?.takeIf { it.username == username && paths.rootfsReadyMarker.isFile && paths.rootfsReadyMarker.readText().contains("alpine-3.21-kde-x11") }',
        "discard stale Ubuntu initialization progress")
    s = once(s,
        'if (!paths.rootfsReadyMarker.isFile) {',
        'if (!paths.rootfsReadyMarker.isFile || !paths.rootfsReadyMarker.readText().contains("alpine-3.21-kde-x11")) {',
        "re-extract mismatched rootfs marker")
    s = s.replace('"Ubuntu 尚未初始化"', '"Alpine 尚未初始化"')
    s = s.replace('"Ubuntu 配置失败：', '"Alpine 配置失败：')
    s = s.replace('private const val ROOTFS_ASSET = "rootfs/ubuntu-base-24.04.4-base-arm64.tar"',
                  'private const val ROOTFS_ASSET = "rootfs/alpine-rootfs-aarch64.tar.gz"')
    s = s.replace('private const val ROOTFS_SHA256 = "0ce61ffe898bab0d0b35231c3daf1751d95c34a1963b507549c9d7dc97543e48"',
                  f'private const val ROOTFS_SHA256 = "{sha}"')
    s = s.replace('paths.rootfsReadyMarker.writeText("ubuntu-24.04\\n")',
                  'paths.rootfsReadyMarker.writeText("alpine-3.21-kde-x11\\n")')
    s = s.replace('File(paths.rootfsDir, "etc/dpkg/dpkg.cfg.d/PaxHeaders").deleteRecursively()\n                    File(paths.rootfsDir, "etc/dpkg/dpkg.cfg.d/PaxHeaders.0").deleteRecursively()\n', '')
    s = s.replace('check(!isInitialized()) { "Ubuntu 已完成初始化" }', 'check(!isInitialized()) { "Alpine 已完成初始化" }')

    # Do not install Ubuntu-only Debian packages during first boot.
    start = s.index('            execute(InitializationStep.CREATE_CONTAINER,')
    end = s.index('            execute(InitializationStep.CREATE_USER,', start)
    s = s[:start] + '''            execute(InitializationStep.CREATE_CONTAINER, "正在配置 Alpine KDE 桌面") {
                writeContainerFiles()
                runAsRoot("command -v apk sudo bash dbus-daemon pulseaudio fcitx5 startplasma-x11 kwin_x11 dolphin konsole kate >/dev/null", "alpine-base-packages")
            }
''' + s[end:]

    s = re.sub(r'execute\(InitializationStep.CONFIGURE_SUDO,.*?\n            \}', '''execute(InitializationStep.CONFIGURE_SUDO, "正在配置 sudo") {
                runAsRoot("addgroup -S wheel 2>/dev/null || true; adduser ${shell(username)} wheel; mkdir -p /etc/sudoers.d; printf '%s ALL=(ALL:ALL) ALL\\\\n' ${shell(username)} > /etc/sudoers.d/${shell(username)}; chmod 440 /etc/sudoers.d/${shell(username)}", "configure-sudo")
            }''', s, count=1, flags=re.S)

    # Alpine's package index replaces Ubuntu apt configuration.
    a = s.index('    private fun ensureNetworkConfig()')
    b = s.index('    private fun ensureTunaAptMirror()', a)
    s = s[:a] + '''    private fun ensureNetworkConfig() {
        File(paths.rootfsDir, "etc/resolv.conf").writeText(
            listOf("nameserver 1.1.1.1", "nameserver 8.8.8.8", "options timeout:2 attempts:3 rotate").joinToString(10.toChar().toString(), postfix = 10.toChar().toString())
        )
        File(paths.rootfsDir, "etc/apk/repositories").apply {
            parentFile?.mkdirs()
            writeText(listOf("https://dl-cdn.alpinelinux.org/alpine/v3.21/main", "https://dl-cdn.alpinelinux.org/alpine/v3.21/community").joinToString(10.toChar().toString(), postfix = 10.toChar().toString()))
        }
        File(paths.rootfsDir, "etc/gai.conf").apply {
            parentFile?.mkdirs()
            writeText("precedence ::ffff:0:0/96  100" + 10.toChar())
        }
    }

''' + s[b:]

    # No glibc-only preload bridge in the musl-based Alpine rootfs.
    s = s.replace('        ensureGetifaddrsBridge()\\n', '')
    a = s.index('    private fun installRuntime()')
    b = s.index('    private fun ensureGetifaddrsBridge()', a)
    s = s[:a] + '''    private fun installRuntime() {
        paths.prootTmpDir.mkdirs()
        check(paths.prootTmpDir.isDirectory && paths.prootTmpDir.canWrite()) { "PRoot临时目录不可写" }
        check(paths.proot.isFile && paths.proot.canExecute()) { "PRoot 原生运行时不可用" }
        check(paths.loader.isFile) { "PRoot Loader 不可用" }
        paths.libraryDir.mkdirs()
        copyAsset("runtime/arm64-v8a/lib/libtalloc.so.2", File(paths.libraryDir, "libtalloc.so.2"))
        copyAsset("runtime/arm64-v8a/lib/libandroid-shmem.so", File(paths.libraryDir, "libandroid-shmem.so"))
    }

''' + s[b:]

    # Rootfs already contains the desktop and utilities; don't run XFCE/Ubuntu repair paths.
    s = s.replace('        installGpuAwareDesktopWrappers()\n', '')
    s = s.replace('        ensureDesktopWallpaper(config.username)\n', '')
    s = s.replace('        ensureDesktopShortcuts(config.username)\n', '')
    s = s.replace('        ensureFirefoxCompatibility(config.username)\n', '')

    # Fastfetch is installed in the image, not as a Debian package on first launch.
    a = s.index('    private fun ensureStartupMaintenance(')
    b = s.index('    fun loginCommand(', a)
    s = s[:a] + '''    private fun ensureStartupMaintenance(username: String) {
        ensureFetchScript()
        ensureTerminalProfile(username)
    }

''' + s[b:]

    # Hostname and first-boot user creation use Alpine's shadow tools.
    a = s.index('    private fun writeContainerFiles()')
    b = s.index('    fun loadInitializationState()', a)
    s = s[:a] + r'''    private fun writeContainerFiles() {
        ensureNetworkConfig()
        File(paths.rootfsDir, "etc/hostname").writeText("alpine-kde\\n")
        val hosts = File(paths.rootfsDir, "etc/hosts")
        hosts.writeText("127.0.0.1 localhost\\n127.0.1.1 alpine-kde\\n::1 localhost ip6-localhost\\n")
    }

    private fun userCreationScript(username: String, password: CharArray): String {
        val credentials = "$username:${password.concatToString()}"
        return "id -u ${shell(username)} >/dev/null 2>&1 || adduser -D -h /home/${shell(username)} -s /bin/bash ${shell(username)}; " +
            "mkdir -p /home/${shell(username)}; printf '%s\\n' ${shell(credentials)} | chpasswd"
    }

    private fun environmentScript(username: String): String =
        "mkdir -p /etc/profile.d /home/${shell(username)} && " +
            "printf '%s\\n' 'export LANG=C.UTF-8' 'export LC_ALL=C.UTF-8' 'export LANGUAGE=zh_CN:zh' 'export MALLOC_ARENA_MAX=2' 'export MESA_SHADER_CACHE_MAX_SIZE=128M' > /etc/profile.d/mobile.sh && " +
            "ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && " +
            "printf '%s\\n' 'Asia/Shanghai' > /etc/timezone && " +
            "touch /home/${shell(username)}/.bashrc && " +
            "grep -qF 'export PS1=' /home/${shell(username)}/.bashrc || " +
            "printf '%s\\n' 'export PS1=\\\\u@\\\\h:\\\\w# ' >> /home/${shell(username)}/.bashrc; " +
            "chown -R ${shell(username)}:${shell(username)} /home/${shell(username)}"

''' + s[b:]
    return s

edit("app/src/main/java/com/doro/terminal/shell/linux/LinuxContainerManager.kt", patch_manager)

# Switch the existing Lorie X11 session launcher from XFCE to KDE Plasma X11.
def patch_desktop(s):
    a = s.index('    fun sessionScript(')
    b = s.index('    fun patchDesktop(', a)
    replacement = r'''    fun sessionScript(display: String, username: String): String =
        "export DISPLAY=${quote(display)}; " +
            "export XDG_RUNTIME_DIR=/tmp/runtime-${quote(username)}; " +
            "mkdir -p \"\$XDG_RUNTIME_DIR\"; chmod 700 \"\$XDG_RUNTIME_DIR\"; " +
            "export XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true QT_QPA_PLATFORM=xcb KWIN_COMPOSE=N QT_X11_NO_MITSHM=1; " +
            "export LANG=C.UTF-8 LC_ALL=C.UTF-8 LANGUAGE=zh_CN:zh; " +
            "export XMODIFIERS=@im=fcitx GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx; " +
            "export MALLOC_ARENA_MAX=2 MESA_SHADER_CACHE_MAX_SIZE=128M NO_AT_BRIDGE=1; " +
            "unset DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID SESSION_MANAGER; " +
            "pkill -9 -x plasmashell 2>/dev/null || true; pkill -9 -x kwin_x11 2>/dev/null || true; sleep 1; " +
            "exec dbus-run-session -- /usr/bin/startplasma-x11"

'''
    return s[:a] + replacement + s[b:]
edit("app/src/main/java/com/doro/terminal/shell/linux/DesktopCompatibility.kt", patch_desktop)

# Repair the upstream Lorie native build's missing Xfuncproto header.
xfuncproto = r"""#ifndef _XFUNCPROTO_H_
#define _XFUNCPROTO_H_
#ifndef NeedFunctionPrototypes
#define NeedFunctionPrototypes 1
#endif
#ifndef NeedVarargsPrototypes
#define NeedVarargsPrototypes 1
#endif
#ifndef NeedNestedPrototypes
#define NeedNestedPrototypes 1
#endif
#ifndef _Xconst
#define _Xconst const
#endif
#ifndef FUNCPROTO
#define FUNCPROTO 15
#endif
#ifndef NeedWidePrototypes
#if defined(__linux__) || defined(__ANDROID__)
#define NeedWidePrototypes 0
#else
#define NeedWidePrototypes 1
#endif
#endif
#ifndef _XFUNCPROTOBEGIN
#ifdef __cplusplus
#define _XFUNCPROTOBEGIN extern "C" {
#define _XFUNCPROTOEND }
#else
#define _XFUNCPROTOBEGIN
#define _XFUNCPROTOEND
#endif
#endif
#ifndef __has_attribute
#define __has_attribute(x) 0
#endif
#ifndef __has_feature
#define __has_feature(x) 0
#endif
#ifndef __has_extension
#define __has_extension(x) 0
#endif
#if __has_attribute(__sentinel__) || (defined(__GNUC__) && __GNUC__ >= 4)
#define _X_SENTINEL(x) __attribute__((__sentinel__(x)))
#else
#define _X_SENTINEL(x)
#endif
#if __has_attribute(visibility) || (defined(__GNUC__) && __GNUC__ >= 4)
#define _X_EXPORT __attribute__((visibility("default")))
#define _X_HIDDEN __attribute__((visibility("hidden")))
#define _X_INTERNAL __attribute__((visibility("internal")))
#else
#define _X_EXPORT
#define _X_HIDDEN
#define _X_INTERNAL
#endif
#if defined(__GNUC__) && ((__GNUC__ * 100 + __GNUC_MINOR__) >= 303)
#define _X_LIKELY(x) __builtin_expect(!!(x), 1)
#define _X_UNLIKELY(x) __builtin_expect(!!(x), 0)
#else
#define _X_LIKELY(x) (x)
#define _X_UNLIKELY(x) (x)
#endif
#if __has_attribute(__cold__) || (defined(__GNUC__) && ((__GNUC__ * 100 + __GNUC_MINOR__) >= 403))
#define _X_COLD __attribute__((__cold__))
#else
#define _X_COLD
#endif
#if __has_attribute(deprecated) || (defined(__GNUC__) && ((__GNUC__ * 100 + __GNUC_MINOR__) >= 301))
#define _X_DEPRECATED __attribute__((deprecated))
#else
#define _X_DEPRECATED
#endif
#if __has_attribute(noreturn) || (defined(__GNUC__) && ((__GNUC__ * 100 + __GNUC_MINOR__) >= 205))
#define _X_NORETURN __attribute__((noreturn))
#else
#define _X_NORETURN
#endif
#if __has_attribute(__format__) || (defined(__GNUC__) && ((__GNUC__ * 100 + __GNUC_MINOR__) >= 203))
#define _X_ATTRIBUTE_PRINTF(x,y) __attribute__((__format__(__printf__,x,y)))
#else
#define _X_ATTRIBUTE_PRINTF(x,y)
#endif
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L
#define _X_INLINE inline
#elif defined(__GNUC__)
#define _X_INLINE __inline__
#else
#define _X_INLINE
#endif
#ifndef _X_RESTRICT_KYWD
#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 199901L && !defined(__cplusplus)
#define _X_RESTRICT_KYWD restrict
#elif defined(__GNUC__)
#define _X_RESTRICT_KYWD __restrict__
#else
#define _X_RESTRICT_KYWD
#endif
#endif
#define _X_UNUSED __attribute__((__unused__))
#define _X_NOTSAN
#define _X_NONSTRING
#endif
"""
header = src / "termux_ubuntu_rebuild/termux_x11_source/lorie/src/main/cpp/xorgproto/include/X11/Xfuncproto.h"
header.parent.mkdir(parents=True, exist_ok=True)
if not header.exists():
    header.write_text(xfuncproto)
else:
    existing = header.read_text()
    if "_X_HIDDEN" not in existing:
        header.write_text(xfuncproto)

# Fix xkbcomp's host utility rule: CMake COMMAND does not interpret shell && or > tokens.
def patch_xkbcomp(s):
    old = """add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/ks_tables.h"
        COMMAND "/usr/bin/gcc" "-o" "${CMAKE_CURRENT_BINARY_DIR}/makekeys" "${CMAKE_CURRENT_SOURCE_DIR}/libx11/src/util/makekeys.c" "&&"
            "${CMAKE_CURRENT_BINARY_DIR}/makekeys" "keysymdef.h" "XF86keysym.h" "Sunkeysym.h" "DECkeysym.h" "HPkeysym.h" ">" "${CMAKE_CURRENT_BINARY_DIR}/ks_tables.h"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/xorgproto/include/X11"
        COMMENT "Generating source code (ks_tables.h)"
        VERBATIM)"""
    new = """find_program(HOST_C_COMPILER NAMES cc gcc REQUIRED)
execute_process(
        COMMAND "${HOST_C_COMPILER}" -o "${CMAKE_CURRENT_BINARY_DIR}/makekeys" "${CMAKE_CURRENT_SOURCE_DIR}/libx11/src/util/makekeys.c"
        RESULT_VARIABLE MAKEKEYS_COMPILE_RESULT)
if(NOT MAKEKEYS_COMPILE_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to build host makekeys utility")
endif()
execute_process(
        COMMAND "${CMAKE_CURRENT_BINARY_DIR}/makekeys" keysymdef.h XF86keysym.h Sunkeysym.h DECkeysym.h HPkeysym.h
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/xorgproto/include/X11"
        OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/ks_tables.h"
        RESULT_VARIABLE MAKEKEYS_RESULT)
if(NOT MAKEKEYS_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to generate ks_tables.h")
endif()"""
    return once(s, old, new, "xkbcomp host makekeys rule")
edit("termux_ubuntu_rebuild/termux_x11_source/lorie/src/main/cpp/recipes/xkbcomp.cmake", patch_xkbcomp)

# Expose generated X11 headers and the Xtrans symlink from the CMake build tree.
def patch_xorgproto(s):
    return once(s,
        'target_include_directories(xorgproto INTERFACE "xorgproto/include")',
        'target_include_directories(xorgproto INTERFACE "xorgproto/include" "${CMAKE_CURRENT_BINARY_DIR}")',
        "xorgproto generated include directory")
edit("termux_ubuntu_rebuild/termux_x11_source/lorie/src/main/cpp/recipes/xorgproto.cmake", patch_xorgproto)

# Correct a copied target name in the upstream Xau recipe.
def patch_xau(s):
    return once(s,
        'target_compile_options(Xdmcp PRIVATE ${common_compile_options} "-D_GNU_SOURCE=1" "-DHAVE_EXPLICIT_BZERO" "-fPIC")',
        'target_compile_options(Xau PRIVATE ${common_compile_options} "-D_GNU_SOURCE=1" "-DHAVE_EXPLICIT_BZERO" "-fPIC")',
        "Xau compile options target")
edit("termux_ubuntu_rebuild/termux_x11_source/lorie/src/main/cpp/recipes/Xau.cmake", patch_xau)

# Correct Kotlin escape depth in the generated Alpine hostname and hosts files.
def patch_manager_runtime_strings(s):
    s = once(s,
        'File(paths.rootfsDir, "etc/hostname").writeText("alpine-kde\\\\\\\\n")',
        'File(paths.rootfsDir, "etc/hostname").writeText("alpine-kde\\\\n")',
        "Alpine hostname newline")
    s = once(s,
        'hosts.writeText("127.0.0.1 localhost\\\\\\\\n127.0.1.1 alpine-kde\\\\\\\\n::1 localhost ip6-localhost\\\\\\\\n")',
        'hosts.writeText("127.0.0.1 localhost\\\\n127.0.1.1 alpine-kde\\\\n::1 localhost ip6-localhost\\\\n")',
        "Alpine hosts newlines")
    s = s.replace('PS1=\\\\\\\\\\\\\\\\u@\\\\\\\\\\\\\\\\h:\\\\\\\\\\\\\\\\w# ', 'PS1=\\\\\\\\u@\\\\\\\\h:\\\\\\\\w# ')
    return s
edit("app/src/main/java/com/doro/terminal/shell/linux/LinuxContainerManager.kt", patch_manager_runtime_strings)

# Update visible distro branding while preserving the upstream application structure.
for rel in ["app/src/main/java/com/java/myapplication/MainActivity.kt",
            "app/src/main/res/values/strings.xml"]:
    p = src / rel
    if p.exists():
        t = p.read_text().replace("Ubuntu", "Alpine").replace("ubuntu", "alpine").replace("XFCE", "KDE Plasma")
        t = t.replace('<string name="app_name">终端</string>', '<string name="app_name">Alpine KDE Mobile</string>')
        p.write_text(t)

# The embedded rootfs is gzip-compressed and must be kept uncompressed by APK packaging.
p = src / "app/build.gradle.kts"
g = p.read_text()
# Upstream forces ARM64 AAPT2 for an on-device build. APK compilation runs on
# x86_64 CI, so use the Android Gradle Plugin's native host AAPT2 instead.
start = g.find("// Force use of ARM64 binaries for AAPT2 in Proot environment")
end = g.find(chr(10) + "}" + chr(10), start) if start >= 0 else -1
if start < 0 or end < 0:
    raise SystemExit("Could not locate upstream ARM64-only AAPT2 override")
g = g[:start] + g[end + 3:]
removed = 1
if removed != 1 or "linux-aarch64" in g:
    raise SystemExit("Could not safely remove upstream ARM64-only AAPT2 override")
if 'noCompress += listOf("tar")' in g:
    g = g.replace('noCompress += listOf("tar")', 'noCompress += listOf("tar", "gz")', 1)
elif 'noCompress += listOf("tar", "gz")' not in g:
    raise SystemExit("Could not locate Android rootfs noCompress configuration")
if "versionCode = 69" in g:
    g = g.replace("versionCode = 69", "versionCode = 120", 1)
elif "versionCode = 120" not in g:
    raise SystemExit("Unexpected upstream versionCode")
if 'versionName = "1.1.9Debug"' in g:
    g = g.replace('versionName = "1.1.9Debug"', 'versionName = "1.2.0-Alpine-KDE"', 1)
elif 'versionName = "1.2.0-Alpine-KDE"' not in g:
    raise SystemExit("Unexpected upstream versionName")
p.write_text(g)
PY


# The upstream tag contains a developer-local Gradle distribution URL.
# Replace it with the official Gradle 9.1.0 distribution for CI builds.
python3 - "$SRC/gradle/wrapper/gradle-wrapper.properties" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = "distributionUrl=file:///root/gradle/gradle-9.1.0-bin.zip"
new = "distributionUrl=https\\://services.gradle.org/distributions/gradle-9.1.0-bin.zip"
if old not in s and new not in s:
    raise SystemExit("Unexpected Gradle wrapper distribution URL")
p.write_text(s.replace(old, new))
PY
grep -Fq 'distributionUrl=https\://services.gradle.org/distributions/gradle-9.1.0-bin.zip' "$SRC/gradle/wrapper/gradle-wrapper.properties"
