#!/usr/bin/env python3
import argparse
import pathlib
import re

parser = argparse.ArgumentParser()
parser.add_argument("source")
parser.add_argument("--rootfs-sha256", required=True)
args = parser.parse_args()
root = pathlib.Path(args.source)

def read(rel):
    return (root / rel).read_text()

def write(rel, value):
    (root / rel).write_text(value)

def replace_method(source, start, end, replacement, rel):
    i = source.find(start)
    j = source.find(end, i + len(start)) if i >= 0 else -1
    if i < 0 or j < 0:
        raise SystemExit(f"{rel}: expected method anchors missing")
    return source[:i] + replacement.rstrip() + "\n\n" + source[j:]

mp = "app/src/main/java/com/doro/terminal/shell/linux/LinuxContainerManager.kt"
m = read(mp)
m = replace_method(m, "    fun initialize(", "    private fun ensureStartupMaintenance(", r'''    fun initialize(
        username: String,
        password: CharArray,
        components: Set<InstallComponent>,
        onProgress: (InitializationProgress) -> Unit = {}
    ): ContainerConfig {
        require(LinuxAccount.isValidUsername(username)) { "用户名格式无效" }
        require(password.size >= 6) { "密码至少需要六位" }
        check(Build.SUPPORTED_64_BIT_ABIS.contains("arm64-v8a")) { "当前仅支持 ARM64 设备" }
        check(!isInitialized()) { "Alpine 已完成初始化" }
        var state = loadInitializationState()?.takeIf { it.username == username }
            ?: InitializationState(username, components.filter { it.supported }.toSet())
        saveInitializationState(state)
        prepareLog()
        try {
            fun execute(step: InitializationStep, message: String, action: () -> Unit) {
                if (state.completedStep != null && state.completedStep!!.ordinal >= step.ordinal) return
                onProgress(progress(step, message))
                appendLog("START " + step.name + ": " + message)
                action()
                state = state.copy(completedStep = step, failedMessage = null)
                saveInitializationState(state)
                appendLog("DONE " + step.name)
            }
            execute(InitializationStep.EXTRACT_SYSTEM, "正在解压 Alpine KDE 系统") {
                installRuntime()
                if (!paths.rootfsReadyMarker.isFile) {
                    paths.rootfsDir.deleteRecursively()
                    verifyAsset(ROOTFS_ASSET, ROOTFS_SHA256)
                    context.assets.open(ROOTFS_ASSET).use { TarGzExtractor.extract(it, paths.rootfsDir) }
                    check(File(paths.rootfsDir, "etc/alpine-release").readText().startsWith("3.21")) {
                        "内置 RootFS 不是 Alpine 3.21"
                    }
                    check(File(paths.rootfsDir, "usr/bin/startplasma-x11").canExecute()) {
                        "Alpine KDE X11 会话组件缺失"
                    }
                    check(File(paths.rootfsDir, "usr/bin/kwin_x11").canExecute()) {
                        "KWin X11 组件缺失"
                    }
                    paths.rootfsReadyMarker.writeText("alpine-3.21-kde-x11\n")
                }
            }
            execute(InitializationStep.CREATE_CONTAINER, "正在配置 Alpine 容器") {
                writeContainerFiles()
            }
            execute(InitializationStep.CREATE_USER, "正在创建 Linux 用户") {
                runAsRoot(userCreationScript(username, password), "create-user")
            }
            execute(InitializationStep.CONFIGURE_SUDO, "正在配置 sudo 权限") {
                runAsRoot(
                    "addgroup wheel >/dev/null 2>&1 || true; " +
                        "addgroup " + shell(username) + " wheel >/dev/null 2>&1 || true; " +
                        "mkdir -p /etc/sudoers.d; " +
                        "printf '%s\\n' " + shell(username + " ALL=(ALL:ALL) ALL") +
                        " > /etc/sudoers.d/" + shell(username) + "; " +
                        "chmod 440 /etc/sudoers.d/" + shell(username),
                    "configure-sudo"
                )
            }
            execute(InitializationStep.INITIALIZE_ENVIRONMENT, "正在初始化 Alpine 环境") {
                runAsRoot(environmentScript(username), "initialize-environment")
            }
            execute(InitializationStep.SAVE_CONFIGURATION, "正在保存配置") { }
            return ContainerConfig(distribution = "alpine", version = "3.21", username = username).also {
                saveConfig(it)
                paths.initializationStateFile.delete()
                appendLog("ALPINE KDE INITIALIZATION COMPLETE")
            }
        } catch (failure: Throwable) {
            state = state.copy(failedMessage = failure.message)
            saveInitializationState(state)
            appendLog("FAILED: " + failure.stackTraceToString())
            throw IllegalStateException((failure.message ?: "初始化失败") + "\n日志：" + paths.initializationLogFile.path, failure)
        } finally {
            password.fill('\u0000')
        }
    }''', mp)

m = replace_method(m, "    private fun ensureStartupMaintenance(", "    fun loginCommand(", r'''    private fun ensureStartupMaintenance(username: String) {
        val profile = File(paths.rootfsDir, "etc/profile.d/alpine-kde.sh")
        profile.parentFile?.mkdirs()
        if (!profile.isFile) {
            profile.writeText(
                "export LANG=C.UTF-8\n" +
                    "export LC_ALL=C.UTF-8\n" +
                    "export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n"
            )
        }
        File(paths.rootfsDir, "home/" + username).mkdirs()
    }''', mp)

m = replace_method(m, "    fun loginCommand(", "    fun terminalLaunchSpec(", r'''    fun loginCommand(config: ContainerConfig = requireNotNull(loadConfig())): List<String> {
        installRuntime()
        ensureGetifaddrsBridge()
        ensureStartupMaintenance(config.username)
        return prootCommand("/bin/sh", "-c", "exec /bin/su - " + shell(config.username))
    }''', mp)

m = replace_method(m, "    fun startDesktop(", "    private fun runAsRoot(", r'''    fun startDesktop(display: String, gpuAcceleration: Boolean = true): Process {
        val config = requireNotNull(loadConfig()) { "Alpine 尚未初始化" }
        ensureNetworkConfig()
        installRuntime()
        ensureGetifaddrsBridge()
        val script = DesktopCompatibility.sessionScript(display, config.username, gpuAcceleration)
        val startSession = DesktopCompatibility.systemServicesScript() + "; " +
            "exec /bin/su - " + shell(config.username) + " -c " + shell(script)
        return ProcessBuilder(prootCommand("/bin/sh", "-c", startSession))
            .apply { environment().putAll(loginEnvironment()) }
            .redirectErrorStream(true)
            .start()
    }''', mp)

m = replace_method(m, "    private fun writeContainerFiles()", "    private fun userCreationScript(", r'''    private fun writeContainerFiles() {
        File(paths.rootfsDir, "etc/hostname").writeText("alpine-kde\n")
        File(paths.rootfsDir, "etc/hosts").writeText("127.0.0.1 localhost\n127.0.1.1 alpine-kde\n")
        File(paths.rootfsDir, "etc/resolv.conf").writeText(
            "nameserver 1.1.1.1\nnameserver 8.8.8.8\noptions timeout:2 attempts:3\n"
        )
    }''', mp)

m = replace_method(m, "    private fun userCreationScript(", "    private fun environmentScript(", r'''    private fun userCreationScript(username: String, password: CharArray): String {
        val credentials = username + ":" + password.concatToString()
        return "id -u " + shell(username) + " >/dev/null 2>&1 || " +
            "adduser -D -h /home/" + shell(username) + " -s /bin/ash " + shell(username) + "; " +
            "mkdir -p /home/" + shell(username) + "; " +
            "printf '%s\\n' " + shell(credentials) + " | chpasswd"
    }''', mp)

m = replace_method(m, "    private fun environmentScript(", "    fun loadInitializationState()", r'''    private fun environmentScript(username: String): String =
        "mkdir -p /etc/profile.d /home/" + shell(username) + " && " +
            "printf '%s\\n' 'export LANG=C.UTF-8' 'export LC_ALL=C.UTF-8' " +
            "'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' " +
            "'export XDG_DATA_DIRS=/usr/local/share:/usr/share' > /etc/profile.d/alpine-kde.sh && " +
            "ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && " +
            "printf '%s\\n' 'Asia/Shanghai' > /etc/timezone && " +
            "touch /home/" + shell(username) + "/.profile /home/" + shell(username) + "/.ashrc && " +
            "chown -R " + shell(username) + ":" + shell(username) + " /home/" + shell(username)''', mp)

m = m.replace('distribution = values.getProperty("distribution", "ubuntu")', 'distribution = values.getProperty("distribution", "alpine")')
m = m.replace('version = values.getProperty("version", "24.04")', 'version = values.getProperty("version", "3.21")')
m = m.replace('private const val ROOTFS_ASSET = "rootfs/ubuntu-base-24.04.4-base-arm64.tar"', 'private const val ROOTFS_ASSET = "rootfs/alpine-kde-aarch64.tar.gz"')
m = re.sub(r'private const val ROOTFS_SHA256 = "[^"]+"',
           'private const val ROOTFS_SHA256 = "' + args.rootfs_sha256 + '"', m)
write(mp, m)

pfile = "app/src/main/java/com/doro/terminal/shell/linux/ContainerPaths.kt"
p = read(pfile).replace('distributions/ubuntu-24.04/rootfs', 'distributions/alpine-3.21/rootfs')
write(pfile, p)

xfile = "app/src/main/java/com/doro/terminal/shell/x11/X11ServerService.kt"
x = read(xfile).replace('linux/distributions/ubuntu-24.04/rootfs/usr/share/X11/xkb',
                        'linux/distributions/alpine-3.21/rootfs/usr/share/X11/xkb')
write(xfile, x)

dfile = "app/src/main/java/com/doro/terminal/shell/linux/DesktopCompatibility.kt"
d = read(dfile)
d = replace_method(d, "    fun sessionScript(", "    fun patchDesktop(", r'''    fun sessionScript(display: String, username: String, gpuAcceleration: Boolean): String =
        "export DISPLAY=" + quote(display) + "; " +
            "export XDG_RUNTIME_DIR=/tmp/runtime-" + quote(username) + "; " +
            "mkdir -p \"\$XDG_RUNTIME_DIR\"; chmod 700 \"\$XDG_RUNTIME_DIR\"; " +
            "export XDG_SESSION_TYPE=x11 XDG_CURRENT_DESKTOP=KDE DESKTOP_SESSION=plasma; " +
            "export QT_QPA_PLATFORM=xcb QT_X11_NO_MITSHM=1 NO_AT_BRIDGE=1; " +
            "unset DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID SESSION_MANAGER; " +
            (if (gpuAcceleration) "export MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink; " +
                "export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json VK_DRIVER_FILES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json; " +
                "unset LIBGL_ALWAYS_SOFTWARE LIBGL_DRI3_DISABLE; " else
                "unset MESA_LOADER_DRIVER_OVERRIDE GALLIUM_DRIVER VK_ICD_FILENAMES VK_DRIVER_FILES; export LIBGL_ALWAYS_SOFTWARE=1; ") +
            "exec dbus-launch --exit-with-session startplasma-x11"

''', dfile)
write(dfile, d)

models_file = "app/src/main/java/com/doro/terminal/shell/linux/ContainerModels.kt"
models = read(models_file)
models = models.replace('distribution: String = "ubuntu"', 'distribution: String = "alpine"')
models = models.replace('version: String = "24.04"', 'version: String = "3.21"')
models = models.replace('UBUNTU("Ubuntu 24.04", "基础组件"', 'UBUNTU("Alpine Linux 3.21", "基础组件"')
models = models.replace('DESKTOP("XFCE 图形桌面", "桌面环境"', 'DESKTOP("KDE Plasma 图形桌面", "桌面环境"')
models = models.replace('XFCE("XFCE 桌面", "内置组件"', 'XFCE("KDE Plasma 桌面", "内置组件"')
models = models.replace('APT("APT", "基础组件"', 'APT("APK", "基础组件"')
write(models_file, models)

activity_file = "app/src/main/java/com/java/myapplication/MainActivity.kt"
activity = read(activity_file).replace("Ubuntu", "Alpine").replace("ubuntu", "alpine")
write(activity_file, activity)

strings_file = "app/src/main/res/values/strings.xml"
strings = read(strings_file)
strings = re.sub(r'(<string name="app_name">).*?(</string>)',
                 r'\1Alpine KDE Mobile\2', strings, count=1)
write(strings_file, strings)

gradle_file = "app/build.gradle.kts"
gradle = read(gradle_file)
gradle = gradle.replace('applicationId = "com.doro.terminal.shell"',
                        'applicationId = "org.alpinekde.mobile"')
gradle = gradle.replace('versionName = "1.1.9Debug"', 'versionName = "1.0.0-alpine"')
gradle = gradle.replace('noCompress += listOf("tar")', 'noCompress += listOf("tar", "gz")')
gradle = re.sub(r"(?s)\n// Force use of ARM64 binaries for AAPT2 in Proot environment.*?\n\ndependencies \{", "\n\ndependencies {", gradle, count=1)
write(gradle_file, gradle)

print("Patched doroUbuntu Android runtime for Alpine 3.21 + KDE Plasma X11.")
