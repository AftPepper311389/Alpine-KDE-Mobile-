package org.alpinekde.mobile;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Typeface;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.io.InputStream;

public final class MainActivity extends Activity {
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

    private boolean hasEmbeddedAlpineRootfs() {
        try (InputStream input = getAssets().open("alpine-rootfs-aarch64.tar.gz")) {
            return input.read() == 0x1f && input.read() == 0x8b;
        } catch (Exception ignored) {
            return false;
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

        boolean rootfsPresent = hasEmbeddedAlpineRootfs();

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

        TextView status = text(rootfsPresent ? "ALPINE ROOTFS EMBEDDED" : "ROOTFS ASSET MISSING", 12, true);
        status.setTextColor(rootfsPresent ? 0xFF176B45 : 0xFFB3261E);
        LinearLayout.LayoutParams statusParams = new LinearLayout.LayoutParams(-2, -2);
        statusParams.topMargin = dp(32);
        content.addView(status, statusParams);

        addSection(content, "Embedded Linux payload",
                "Alpine Linux 3.24.4 · ARM64 (aarch64)\nBootstrap userspace: " +
                (rootfsPresent ? "present in this APK" : "not found in this APK") +
                "\nPackage manager: apk · Base utilities: BusyBox");
        addSection(content, "Desktop integration status",
                "KDE Plasma desktop packages: not yet embedded\nRootfs extraction: not implemented\nPRoot/process runtime: not integrated\nAndroid-hosted display and input bridge: not implemented\nGPU hardware acceleration: not detected or validated");
        addSection(content, "Important",
                "This build now carries a real Alpine ARM64 bootstrap filesystem inside the APK. It is not yet a complete KDE desktop and cannot launch a Plasma session. The next stages add local extraction, the Linux process runtime, KDE packages, and an in-app display bridge. Hardware GPU acceleration will only be claimed after on-device verification.");

        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        setContentView(scroll);
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
