#!/usr/bin/env python3
"""Apply the Alpine KDE integration patch to the pinned WLDroid source checkout."""
from pathlib import Path
import shutil
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: patch-wldroid.py WLDROID_DIR ROOTFS_ARCHIVE")

root = Path(sys.argv[1]).resolve()
archive = Path(sys.argv[2]).resolve()

def patch(relative, old, new, count=1):
    path = root / relative
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Expected patch context not found in {relative}: {old[:100]!r}")
    updated = text.replace(old, new, count)
    path.write_text(updated, encoding="utf-8")

assets = root / "testapp/src/main/assets"
assets.mkdir(parents=True, exist_ok=True)
shutil.copy2(archive, assets / "alpine-rootfs-aarch64.tar.xz")
for name in ("ALPINE-LICENSES.txt", "rootfs-build-info.txt", "alpine-kde-package-check.txt", "alpine-rootfs-aarch64.tar.xz.sha256"):
    source = archive.parent / name
    if source.exists():
        shutil.copy2(source, assets / name)

# Import the bundled rootfs through WLDroid's own safe tar.xz extraction path.
patch(
    "proot/src/main/java/nu/shel/wldroid/proot/EnvironmentRegistry.kt",
    'suspend fun importRootfs(tarballPath: String, name: String = "Imported"): RootfsEnvironment =',
    'suspend fun importRootfs(tarballPath: String, name: String = "Imported", distro: String = "Imported"): RootfsEnvironment =',
)
patch(
    "proot/src/main/java/nu/shel/wldroid/proot/EnvironmentRegistry.kt",
    '            stateFlow.value = EnvironmentProgress(EnvironmentState.INSTALLING)\n            rootfsManager.configureRootfs(destDir)\n\n            val env = RootfsEnvironment(\n                id = newId,\n                name = name,\n                rootfsPath = destDir.absolutePath,',
    '            stateFlow.value = EnvironmentProgress(EnvironmentState.INSTALLING)\n            check(File(destDir, "etc/os-release").isFile) { "Imported rootfs has no /etc/os-release" }\n            rootfsManager.configureRootfs(destDir)\n            File(destDir, ".l2s").mkdirs()\n\n            val env = RootfsEnvironment(\n                id = newId,\n                name = name,\n                rootfsPath = destDir.absolutePath,\n                distro = distro,',
)

desktop_path = "testapp/src/main/java/nu/shel/wldroid/testapp/screens/DesktopScreen.kt"
patch(desktop_path,
      "import androidx.compose.foundation.layout.Arrangement\n",
      "import androidx.compose.foundation.layout.Arrangement\nimport androidx.compose.foundation.layout.Box\n")
patch(desktop_path,
      "import androidx.compose.foundation.layout.height\n",
      "import androidx.compose.foundation.layout.height\nimport androidx.compose.foundation.layout.heightIn\n")
patch(desktop_path,
      "import nu.shel.wldroid.launcher.DesktopLauncherConfig\n",
      "import nu.shel.wldroid.launcher.DesktopLauncherConfig\nimport nu.shel.wldroid.launcher.GpuSetupConfig\nimport nu.shel.wldroid.launcher.XWaylandConfig\n")
patch(desktop_path,
      '        tempDir = File(context.cacheDir, "proot-tmp").absolutePath,\n    )',
      '        tempDir = File(context.cacheDir, "proot-tmp").absolutePath,\n        gpuSetupConfig = GpuSetupConfig(installMesaPackages = false),\n        xwaylandConfig = XWaylandConfig(enabled = false),\n    )')
patch(desktop_path,
      '''    fun createDefaultEnvironment() {
        userCancelled = false
        setupCollectionJob?.cancel()
        val config = EnvironmentConfig(
            name = "Default",
            distro = DistroTemplate.DEBIAN_TRIXIE,
        )
        val progressFlow = environmentRegistry.create(config)
        setupCollectionJob = viewModelScope.launch {
            progressFlow.collect { progress ->
                _setupState.value = progress.toSetupState()
            }
        }
    }''',
      '''    fun createDefaultEnvironment() {
        userCancelled = false
        setupCollectionJob?.cancel()
        setupCollectionJob = viewModelScope.launch {
            try {
                _setupState.value = SetupState.Extracting(
                    progress = -1f,
                    message = "Preparing the embedded Alpine + KDE filesystem…",
                )
                val archive = withContext(Dispatchers.IO) {
                    val file = File(context.cacheDir, "alpine-rootfs-aarch64.tar.xz")
                    if (!file.isFile || file.length() == 0L) {
                        context.assets.open("alpine-rootfs-aarch64.tar.xz").use { input ->
                            file.outputStream().buffered().use { output -> input.copyTo(output) }
                        }
                    }
                    file
                }
                _setupState.value = SetupState.Extracting(
                    progress = 0.05f,
                    message = "Installing Alpine Linux 3.24.4 + KDE Plasma offline…",
                )
                environmentRegistry.importRootfs(
                    tarballPath = archive.absolutePath,
                    name = "Alpine KDE",
                    distro = "Alpine Linux",
                )
                archive.delete()
                _setupState.value = SetupState.Running
            } catch (error: Exception) {
                _setupState.value = SetupState.Error(
                    message = error.message ?: "Failed to install the embedded Alpine rootfs",
                    canRetry = true,
                )
            }
        }
    }''')
patch(desktop_path,
      "import kotlinx.coroutines.launch\n",
      "import kotlinx.coroutines.launch\nimport kotlinx.coroutines.Dispatchers\nimport kotlinx.coroutines.withContext\n")
patch(desktop_path,
      "var isCustom by rememberSaveable { mutableStateOf(false) }",
      "var isCustom by rememberSaveable { mutableStateOf(true) }")
patch(desktop_path,
      'var customCommand by rememberSaveable { mutableStateOf("") }',
      'var customCommand by rememberSaveable { mutableStateOf("dbus-run-session -- startplasma-wayland") }')
patch(desktop_path,
      'Text("App Presets", style = MaterialTheme.typography.titleSmall)',
      'Text("Desktop session", style = MaterialTheme.typography.titleSmall)')
patch(desktop_path,
      'label = { Text("Custom command") },\n                    placeholder = { Text("e.g. weston-terminal") },',
      'label = { Text("KDE session command") },\n                    placeholder = { Text("dbus-run-session -- startplasma-wayland") },')
patch(desktop_path,
      'Text("Launch")',
      'Text("Start KDE Plasma")')

# The Android-hosted compositor owns the full display. Controls are an overlay
# before launch; once KDE is running, the surface becomes full-screen.
patch(desktop_path,
      '    Column(modifier = Modifier.fillMaxSize()) {\n        // Compositor surface',
      '    Box(modifier = Modifier.fillMaxSize()) {\n        // Compositor surface')
patch(desktop_path,
      '            modifier = Modifier\n                .fillMaxWidth()\n                .weight(0.55f),',
      '            modifier = Modifier.fillMaxSize(),')
patch(desktop_path,
      '''        // Control panel
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.45f)
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState()),
        ) {''',
      '''        // Setup controls overlay the desktop until the KDE session is launched.
        if (!launcherState.isActive) Surface(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .heightIn(max = 360.dp),
            color = MaterialTheme.colorScheme.surface.copy(alpha = 0.97f),
            tonalElevation = 4.dp,
        ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .verticalScroll(rememberScrollState()),
        ) {''')
patch(desktop_path,
      '''        }
    }
}

private fun KeyboardAutoShowBehavior.displayName()''',
      '''        }
        }
        if (launcherState.isActive) {
            Button(
                onClick = {
                    val svc = service
                    if (svc != null) viewModel.stopViaService(svc) else viewModel.stop()
                },
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.error,
                ),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp),
            ) {
                Text("Stop KDE")
            }
        }
    }
}

private fun KeyboardAutoShowBehavior.displayName()''')

# Force the GLES VirGL path; it renders through Android's EGL/GLES driver.
module_path = "testapp/src/main/java/nu/shel/wldroid/testapp/di/TestAppModule.kt"
patch(module_path,
      "            testClientEnabled = true,",
      "            xwaylandEnabled = false,\n            gpuMode = GpuMode.VIRGL_GLES.name,\n            testClientEnabled = false,")
patch(module_path,
      "            gpuMode = GpuMode.AUTO,",
      "            gpuMode = GpuMode.VIRGL_GLES,")

# Start directly on the KDE desktop screen.
nav_path = "testapp/src/main/java/nu/shel/wldroid/testapp/navigation/TestAppNavigation.kt"
patch(nav_path,
      'data object Desktop : TestAppRoute("desktop", "Desktop", "🖥️")',
      'data object Desktop : TestAppRoute("desktop", "KDE Desktop", "🖥️")')
patch(nav_path,
      "startDestination = TestAppRoute.Compositor.route,",
      "startDestination = TestAppRoute.Desktop.route,")

# Brand the generated APK as Alpine KDE Mobile.
patch("testapp/build.gradle.kts",
      'applicationId = "nu.shel.wldroid.testapp"',
      'applicationId = "org.alpinekde.mobile"')
patch("testapp/src/main/AndroidManifest.xml",
      'android:label="WLDroid Test"',
      'android:label="Alpine KDE Mobile"')
patch("testapp/src/main/AndroidManifest.xml",
      'android:allowBackup="true"',
      'android:allowBackup="false"')
patch("testapp/src/main/java/nu/shel/wldroid/testapp/TestAppActivity.kt",
      'text = "WLDroid Test App"',
      'text = "Alpine KDE Mobile"')

# Alpine uses /usr/lib rather than Debian's multiarch library directory.
for relative in (
    "launcher/src/main/assets/scripts/setup-gpu.sh",
    "launcher/src/main/assets/scripts/launch-app.sh",
):
    patch(relative,
          'LIB_DIR="/usr/lib/aarch64-linux-gnu"',
          'if [ -f /etc/alpine-release ]; then\n    LIB_DIR="/usr/lib"\nelse\n    LIB_DIR="/usr/lib/aarch64-linux-gnu"\nfi')

print("WLDroid Alpine KDE integration patches applied.")
