package org.alpinekde.mobile;

import android.content.Context;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

public final class ProotSession {
    private ProotSession() {}

    public static void runSmokeTest(Context context, Consumer<String> callback) {
        StringBuilder output = new StringBuilder();
        try {
            File rootfs = new File(context.getFilesDir(), "alpine-rootfs");
            File nativeDir = new File(context.getApplicationInfo().nativeLibraryDir);
            File proot = new File(nativeDir, "libproot.so");
            File loader = new File(nativeDir, "libproot-loader.so");
            if (!RootfsInstaller.isInstalled(context)) {
                throw new IllegalStateException("Install the Alpine + KDE filesystem first.");
            }
            if (!proot.isFile() || !loader.isFile()) {
                throw new IllegalStateException("The Android PRoot runtime is missing from the APK.");
            }

            List<String> command = new ArrayList<>();
            command.add(proot.getAbsolutePath());
            command.add("--link2symlink");
            command.add("-0");
            command.add("-r");
            command.add(rootfs.getAbsolutePath());
            addBindIfPresent(command, "/dev");
            addBindIfPresent(command, "/proc");
            addBindIfPresent(command, "/sys");
            addBindIfPresent(command, "/system");
            addBindIfPresent(command, "/apex");
            addBindIfPresent(command, "/linkerconfig");
            if (new File("/proc/self/fd").exists()) {
                command.add("-b");
                command.add("/proc/self/fd:/dev/fd");
            }
            File sharedMemory = new File(context.getCacheDir(), "dev-shm");
            if (!sharedMemory.isDirectory() && !sharedMemory.mkdirs()) {
                throw new IllegalStateException("Cannot create shared-memory fallback directory.");
            }
            command.add("-b");
            command.add(sharedMemory.getAbsolutePath() + ":/dev/shm");
            command.add("-w");
            command.add("/root");
            command.add("/bin/sh");
            command.add("-c");
            command.add("echo 'ALPINE_ROOTFS_OK'; cat /etc/alpine-release && " +
                    "test \"$(uname -m)\" = aarch64 && " +
                    "test -x /usr/bin/startplasma-wayland && echo 'KDE_PLASMA_WAYLAND_OK'");

            ProcessBuilder builder = new ProcessBuilder(command);
            builder.redirectErrorStream(true);
            builder.environment().put("PROOT_LOADER", loader.getAbsolutePath());
            File loader32 = new File(nativeDir, "libproot-loader32.so");
            if (loader32.isFile()) {
                builder.environment().put("PROOT_LOADER_32", loader32.getAbsolutePath());
            }
            File temp = new File(context.getCacheDir(), "proot-tmp");
            if (!temp.isDirectory() && !temp.mkdirs()) {
                throw new IllegalStateException("Cannot create PRoot temporary directory.");
            }
            builder.environment().put("PROOT_TMP_DIR", temp.getAbsolutePath());
            builder.environment().put("HOME", "/root");
            builder.environment().put("TMPDIR", "/tmp");

            Process process = builder.start();
            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = reader.readLine()) != null) {
                    output.append(line).append('\n');
                }
            }
            int exitCode = process.waitFor();
            if (exitCode == 0 && output.toString().contains("ALPINE_ROOTFS_OK")) {
                callback.accept("PRoot test succeeded.\n" + output);
            } else {
                callback.accept("PRoot test failed (exit " + exitCode + ").\n" + output);
            }
        } catch (Exception error) {
            callback.accept("PRoot test could not start: " + error.getMessage() +
                    (output.length() == 0 ? "" : "\n" + output));
        }
    }

    private static void addBindIfPresent(List<String> command, String path) {
        if (new File(path).exists()) {
            command.add("-b");
            command.add(path);
        }
    }
}
