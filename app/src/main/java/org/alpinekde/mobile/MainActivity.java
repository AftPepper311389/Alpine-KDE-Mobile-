package org.alpinekde.mobile;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Typeface;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

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

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(0xFFF4F6FA);
        getWindow().setNavigationBarColor(0xFFF4F6FA);
        getWindow().getDecorView().setSystemUiVisibility(
                android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR |
                android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);

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

        TextView status = text("PROJECT INITIALIZED", 12, true);
        status.setTextColor(0xFF176B45);
        LinearLayout.LayoutParams statusParams = new LinearLayout.LayoutParams(-2, -2);
        statusParams.topMargin = dp(32);
        content.addView(status, statusParams);

        addSection(content, "Target environment",
                "Alpine Linux stable (3.24.x)\nKDE Plasma desktop\narm64-v8a Android host");
        addSection(content, "Integration status",
                "Linux root filesystem: not installed\nPRoot runtime: not integrated\nKDE session: not implemented\nGPU acceleration: not detected or validated\nADB-assisted setup: not implemented");
        addSection(content, "Important",
                "This is an early project shell, not a working Linux desktop yet. A successful APK build only verifies the Android application build. It does not prove that Alpine, Plasma, display integration, or hardware GPU acceleration works.");

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
