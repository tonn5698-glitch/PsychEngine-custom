package org.libsdl.app;

import android.Manifest;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import androidx.core.content.FileProvider;
import java.io.File;

public final class PsychAndroid {
    private static final String CHANNEL_ID = "psych_default";

    private static Context ctx() {
        return SDLActivity.getContext();
    }

    public static boolean hasNotifPermission() {
        if (Build.VERSION.SDK_INT < 33) return true;
        return ctx().checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
    }

    public static void requestNotifPermission() {
        if (Build.VERSION.SDK_INT >= 33 && !hasNotifPermission()) {
            ((Activity) ctx()).requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1001);
        }
    }

    public static boolean showNotification(String title, String message, int id) {
        Context c = ctx();
        if (!hasNotifPermission()) return false;
        NotificationManager nm = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        Notification.Builder b;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(new NotificationChannel(CHANNEL_ID, "Psych Engine", NotificationManager.IMPORTANCE_DEFAULT));
            b = new Notification.Builder(c, CHANNEL_ID);
        } else {
            b = new Notification.Builder(c);
        }
        b.setContentTitle(title)
         .setContentText(message)
         .setSmallIcon(android.R.drawable.ic_dialog_info)
         .setAutoCancel(true);
        nm.notify(id, b.build());
        return true;
    }

    public static boolean openApp(String pkg) {
        Context c = ctx();
        Intent i = c.getPackageManager().getLaunchIntentForPackage(pkg);
        if (i == null) return false;
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            c.startActivity(i);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean openFile(String path, String mime) {
        Context c = ctx();
        File f = new File(path);
        if (!f.exists()) return false;
        try {
            Uri uri = FileProvider.getUriForFile(c, c.getPackageName() + ".fileprovider", f);
            Intent i = new Intent(Intent.ACTION_VIEW);
            i.setDataAndType(uri, mime);
            i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
            c.startActivity(i);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public static boolean openUrl(String url) {
        Intent i = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            ctx().startActivity(i);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
