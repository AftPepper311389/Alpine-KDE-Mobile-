package org.alpinekde.mobile;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Typeface;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private final ExecutorService installerExecutor = Executors.newSingleThreadExecutor();
    private TextView installStatus;
    private Button installButton;
    private Button testButton;

    private int dp(float value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }

    private TextView text(String value, float size, boolean bold) {
        TextView view = new TextView(this);
        view.setText(value);
        view.setTextSize(size);
        view.setTextColor(0xFF202124);
        if (bold) view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return view;
    }

    private boolean hasEmbeddedRootfs() {
        try (InputStream input = getAssets().open("alpine-rootfs-aarch64.tar.gz")) {
            return input.read() == 0x1f && input.read() == 0x8b;
        } catch (Exception ignored) {
            return false;
        }
    }

    private String readBuildInfo() {
        try (InputStream input = getAssets().open("rootfs-build-info.txt")) {
            byte[] data = new byte[input.available()];
            int count = input.read(data);
            return new String(data, 0, Math.max(0, count), StandardCharsets.UTF_8);
        } catch (Exception ignored) {
            return "";
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(0xFFF4F6FA);
        getWindow().setNavigationBarColor(0xFFF4F6FA);
        getWindow().getDecorView().setSystemUiVisibility(
                android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR |
                android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);

        boolean rootfsPresent = hasEmbeddedRootfs();
        String buildInfo = readBuildInfo();
        boolean kdePresent = buildInfo.contains("KDE_DESKTOP=installed");
        boolean installed = RootfsInstaller.isInstalled(this);

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(24), dp(36), dp(24), dp(24));
        content.setBackgroundColor(0xFFF4F6FA);

        content.addView(text("Alpine KDE Mobile", 28, true));
        TextView subtitle = text("Android host · Alpine Linux · KDE Plasma", 14, false);
        subtitle.setTextColor(0xFF5F6368);
        LinearLayout.LayoutParams subParams = new LinearLayout.LayoutParams(-1, -2);
        subParams.topMargin = dp(8);
        content.addView(subtitle, subParams);

        TextView status = text(rootfsPresent ? (kdePresent ? "ALPINE + KDE PAYLOAD EMBEDDED" : "ALPINE ROOTFS EMBEDDED") : "ROOTFS ASSET MISSING", 12, true);
        status.setTextColor(rootfsPresent ? 0xFF176B45 : 0xFFB3261E);
        LinearLayout.LayoutParams statusParams = new LinearLayout.LayoutParams(-2, -2);
        statusParams.topMargin = dp(32);
        content.addView(status, statusParams);

        addSection(content, "Embedded Linux payload",
                "Alpine Linux 3.24.4 · ARM64 (aarch64)\nKDE Plasma desktop/workspace: " + (kdePresent ? "included in APK" : "not verified") +
                "\nKWin Wayland compositor: " + (kdePresent ? "included in APK" : "not verified") +
                "\nKonsole + Dolphin: " + (kdePresent ? "included in APK" : "not verified"));
        addSection(content, "Local installation",
                installed ? "Alpine + KDE rootfs is installed in app-private storage." :
                        "The embedded rootfs can be extracted locally without root or a network download. Keep the app open during installation.");
        installButton = new Button(this);
        installButton.setText(installed ? "Alpine + KDE installed" : "Install embedded Alpine + KDE");
        installButton.setEnabled(rootfsPresent && kdePresent && !installed);
        LinearLayout.LayoutParams buttonParams = new LinearLayout.LayoutParams(-1, -2);
        buttonParams.topMargin = dp(20);
        content.addView(installButton, buttonParams);

        installStatus = text(installed ? "Local rootfs installation verified." : "No Linux files are downloaded during installation.", 13, false);
        installStatus.setTextColor(0xFF5F6368);
        LinearLayout.LayoutParams messageParams = new LinearLayout.LayoutParams(-1, -2);
        messageParams.topMargin = dp(8);
        content.addView(installStatus, messageParams);
        installButton.setOnClickListener(view -> startInstall());

        testButton = new Button(this);
        testButton.setText("Test Alpine Linux runtime");
        testButton.setEnabled(installed && new java.io.File(getApplicationInfo().nativeLibraryDir, "libproot.so").isFile());
        LinearLayout.LayoutParams testParams = new LinearLayout.LayoutParams(-1, -2);
        testParams.topMargin = dp(8);
        content.addView(testButton, testParams);
        testButton.setOnClickListener(view -> runRuntimeTest());

        addSection(content, "Runtime and graphics status",
                "PRoot runtime: embedded in APK\nAlpine shell smoke test: available after local install\nKDE session launch: not implemented\nAndroid-hosted display/input bridge: not implemented\nGPU hardware acceleration: not detected or validated");
        addSection(content, "Important",
                "This stage embeds and locally installs Alpine + KDE and includes a PRoot shell smoke test. It does not yet launch the Plasma desktop. The remaining major work is the Android-hosted display/input compositor and the nested Plasma session. Hardware GPU acceleration will only be claimed after on-device verification.");

        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        setContentView(scroll);
    }

    private void runRuntimeTest() {
        testButton.setEnabled(false);
        installStatus.setText("Starting PRoot and checking Alpine…");
        installerExecutor.execute(() -> ProotSession.runSmokeTest(this, result -> runOnUiThread(() -> {
            installStatus.setText(result);
            testButton.setEnabled(true);
        })));
    }

    private void startInstall() {
        installButton.setEnabled(false);
        installStatus.setText("Preparing installation…");
        installerExecutor.execute(() -> {
            try {
                RootfsInstaller.install(this, message -> runOnUiThread(() -> installStatus.setText(message)));
                runOnUiThread(() -> {
                    installStatus.setText("Alpine + KDE rootfs installed successfully in app-private storage.");
                    installButton.setText("Alpine + KDE installed");
                    testButton.setEnabled(new java.io.File(getApplicationInfo().nativeLibraryDir, "libproot.so").isFile());
                });
            } catch (Exception error) {
                runOnUiThread(() -> {
                    installStatus.setText("Installation failed: " + error.getMessage());
                    installButton.setEnabled(true);
                });
            }
        });
    }

    @Override
    protected void onDestroy() {
        installerExecutor.shutdownNow();
        super.onDestroy();
    }

    private void addSection(LinearLayout parent, String heading, String body) {
        TextView title = text(heading, 18, true);
        LinearLayout.LayoutParams titleParams = new LinearLayout.LayoutParams(-1, -2);
        titleParams.topMargin = dp(28);
        parent.addView(title, titleParams);
        TextView detail = text(body, 14, false);
        detail.setTextColor(0xFF3C4043);
        detail.setLineSpacing(dp(4), 1.0f);
        LinearLayout.LayoutParams detailParams = new LinearLayout.LayoutParams(-1, -2);
        detailParams.topMargin = dp(10);
        parent.addView(detail, detailParams);
    }
}
