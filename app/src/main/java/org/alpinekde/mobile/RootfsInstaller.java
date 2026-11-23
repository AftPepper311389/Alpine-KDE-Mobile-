package org.alpinekde.mobile;

import android.content.Context;
import android.os.StatFs;
import android.system.Os;

import org.apache.commons.compress.archivers.tar.TarArchiveEntry;
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream;
import org.apache.commons.compress.compressors.gzip.GzipCompressorInputStream;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;

public final class RootfsInstaller {
    public interface ProgressListener {
        void onProgress(String message);
    }

    private static final String ASSET_NAME = "alpine-rootfs-aarch64.tar.gz";
    private static final long SAFETY_MARGIN = 128L * 1024L * 1024L;

    private RootfsInstaller() {}

    public static boolean isInstalled(Context context) {
        return new File(context.getFilesDir(), ".alpine-kde-rootfs-installed").isFile()
                && new File(context.getFilesDir(), "alpine-rootfs/usr/bin/startplasma-wayland").isFile();
    }

    public static void install(Context context, ProgressListener listener) throws IOException {
        File files = context.getFilesDir();
        File destination = new File(files, "alpine-rootfs");
        File temporary = new File(files, "alpine-rootfs.installing");
        File marker = new File(files, ".alpine-kde-rootfs-installed");

        listener.onProgress("Checking available storage…");
        long unpackedBytes = measureUnpackedSize(context);
        StatFs stat = new StatFs(files.getAbsolutePath());
        long available = stat.getAvailableBytes();
        if (available < unpackedBytes + SAFETY_MARGIN) {
            throw new IOException("Not enough free storage. Need approximately " +
                    formatBytes(unpackedBytes + SAFETY_MARGIN) + ", available " +
                    formatBytes(available) + ".");
        }

        deleteRecursively(temporary);
        if (!temporary.mkdirs()) {
            throw new IOException("Cannot create the temporary rootfs directory.");
        }

        try {
            extract(context, temporary, unpackedBytes, listener);
            File devShm = new File(temporary, "dev/shm");
            if (!devShm.isDirectory() && !devShm.mkdirs()) {
                throw new IOException("Cannot create /dev/shm in the guest rootfs.");
            }
            File guestTmp = new File(temporary, "tmp");
            if (!guestTmp.isDirectory() && !guestTmp.mkdirs()) {
                throw new IOException("Cannot create /tmp in the guest rootfs.");
            }
            Os.chmod(devShm.getAbsolutePath(), 01777);
            Os.chmod(guestTmp.getAbsolutePath(), 01777);
            deleteRecursively(destination);
            if (!temporary.renameTo(destination)) {
                throw new IOException("Cannot finalize the installed rootfs directory.");
            }
            try (FileOutputStream output = new FileOutputStream(marker)) {
                output.write("Alpine 3.24.4 ARM64 KDE payload installed".getBytes(java.nio.charset.StandardCharsets.UTF_8));
                output.getFD().sync();
            }
        } catch (Exception error) {
            deleteRecursively(temporary);
            if (error instanceof IOException) throw (IOException) error;
            throw new IOException("Rootfs installation failed: " + error.getMessage(), error);
        }
    }

    private static long measureUnpackedSize(Context context) throws IOException {
        long total = 0;
        try (InputStream raw = context.getAssets().open(ASSET_NAME);
             BufferedInputStream buffered = new BufferedInputStream(raw);
             GzipCompressorInputStream gzip = new GzipCompressorInputStream(buffered);
             TarArchiveInputStream tar = new TarArchiveInputStream(gzip)) {
            TarArchiveEntry entry;
            while ((entry = tar.getNextTarEntry()) != null) {
                if (entry.isFile()) {
                    total = Math.addExact(total, entry.getSize());
                }
            }
        } catch (ArithmeticException error) {
            throw new IOException("Rootfs size overflow.", error);
        }
        return total;
    }

    private static void extract(Context context, File root, long totalBytes,
                                ProgressListener listener) throws IOException {
        String rootCanonical = root.getCanonicalPath() + File.separator;
        long copied = 0;
        byte[] buffer = new byte[64 * 1024];
        List<DirectoryEntry> directories = new ArrayList<>();
        List<HardLink> hardLinks = new ArrayList<>();

        try (InputStream raw = context.getAssets().open(ASSET_NAME);
             BufferedInputStream buffered = new BufferedInputStream(raw);
             GzipCompressorInputStream gzip = new GzipCompressorInputStream(buffered);
             TarArchiveInputStream tar = new TarArchiveInputStream(gzip)) {
            TarArchiveEntry entry;
            while ((entry = tar.getNextTarEntry()) != null) {
                File output = safeOutput(root, rootCanonical, entry.getName());
                if (entry.isDirectory()) {
                    if (!output.isDirectory() && !output.mkdirs()) {
                        throw new IOException("Cannot create directory: " + entry.getName());
                    }
                    directories.add(new DirectoryEntry(output, entry.getMode() & 07777));
                } else if (entry.isSymbolicLink()) {
                    File parent = output.getParentFile();
                    if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
                        throw new IOException("Cannot create parent directory for " + entry.getName());
                    }
                    if (output.exists() || Files.isSymbolicLink(output.toPath())) output.delete();
                    Os.symlink(entry.getLinkName(), output.getAbsolutePath());
                } else if (entry.isLink()) {
                    File target = safeOutput(root, rootCanonical, entry.getLinkName());
                    hardLinks.add(new HardLink(target, output));
                } else if (entry.isFile()) {
                    File parent = output.getParentFile();
                    if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
                        throw new IOException("Cannot create parent directory for " + entry.getName());
                    }
                    try (FileOutputStream file = new FileOutputStream(output)) {
                        long remaining = entry.getSize();
                        while (remaining > 0) {
                            int read = tar.read(buffer, 0, (int) Math.min(buffer.length, remaining));
                            if (read < 0) throw new IOException("Unexpected end of rootfs archive.");
                            file.write(buffer, 0, read);
                            remaining -= read;
                            copied += read;
                        }
                    }
                    Os.chmod(output.getAbsolutePath(), entry.getMode() & 0777);
                    if (totalBytes > 0) {
                        listener.onProgress("Extracting Alpine + KDE: " +
                                (copied * 100 / totalBytes) + "%");
                    }
                }
            }
        }

        for (HardLink link : hardLinks) {
            File parent = link.destination.getParentFile();
            if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
                throw new IOException("Cannot create hard-link parent.");
            }
            if (!link.target.exists()) throw new IOException("Missing hard-link target: " + link.target);
            Os.link(link.target.getAbsolutePath(), link.destination.getAbsolutePath());
        }

        for (int i = directories.size() - 1; i >= 0; i--) {
            DirectoryEntry directory = directories.get(i);
            Os.chmod(directory.file.getAbsolutePath(), directory.mode);
        }
        listener.onProgress("Finalizing local Alpine + KDE installation…");
    }

    private static File safeOutput(File root, String rootCanonical, String entryName) throws IOException {
        String normalized = entryName.startsWith("/") ? entryName.substring(1) : entryName;
        File output = new File(root, normalized);
        String canonical = output.getCanonicalPath();
        if (!canonical.equals(root.getCanonicalPath()) && !canonical.startsWith(rootCanonical)) {
            throw new IOException("Unsafe path in rootfs archive: " + entryName);
        }
        return output;
    }

    private static void deleteRecursively(File file) throws IOException {
        if (!file.exists() && !Files.isSymbolicLink(file.toPath())) return;
        if (file.isDirectory() && !Files.isSymbolicLink(file.toPath())) {
            File[] children = file.listFiles();
            if (children != null) {
                for (File child : children) deleteRecursively(child);
            }
        }
        if (!file.delete()) throw new IOException("Cannot remove " + file.getAbsolutePath());
    }

    private static String formatBytes(long bytes) {
        return String.format(java.util.Locale.US, "%.1f GiB", bytes / (1024.0 * 1024.0 * 1024.0));
    }

    private static final class DirectoryEntry {
        final File file;
        final int mode;
        DirectoryEntry(File file, int mode) {
            this.file = file;
            this.mode = mode;
        }
    }

    private static final class HardLink {
        final File target;
        final File destination;
        HardLink(File target, File destination) {
            this.target = target;
            this.destination = destination;
        }
    }
}
