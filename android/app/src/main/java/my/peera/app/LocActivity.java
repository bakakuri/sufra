package my.peera.app;

import android.Manifest;
import android.app.Activity;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/* No screen of its own: the site sends the phone here when the person chose to share their place with the app closed
   (peera://loc/start?t=<secret>&a=friends|public&m=15|60|480|0&x=0|1), or to stop it (peera://loc/stop).
   It asks for the location (and, on Android 13+, for notifications: the running share is always shown in one),
   starts or stops the service, and goes back to the site. */
public class LocActivity extends Activity {
    private static final int REQ = 7;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Uri u = getIntent() != null ? getIntent().getData() : null;
        String path = u != null ? u.getPath() : null;
        if ("/stop".equals(path)) {
            LocService.stop(this, false);
            finish();
            return;
        }
        if (!"/start".equals(path)) {
            finish();
            return;
        }
        String t = u.getQueryParameter("t");
        if (t == null || t.length() < 24) {
            finish();
            return;
        }
        String a = "public".equals(u.getQueryParameter("a")) ? "public" : "friends";
        int m = 60;
        try { m = Integer.parseInt(u.getQueryParameter("m")); } catch (Exception ignored) { }
        if (m != 0 && m != 15 && m != 60 && m != 480) m = 60;
        boolean x = "1".equals(u.getQueryParameter("x"));
        Peera.prefs(this).edit().putString("token", t).putString("aud", a).putInt("min", m).putBoolean("approx", x)
                .putBoolean("pending", true).apply();

        List<String> need = new ArrayList<>();
        if (!granted(Manifest.permission.ACCESS_FINE_LOCATION) && !granted(Manifest.permission.ACCESS_COARSE_LOCATION)) {
            need.add(Manifest.permission.ACCESS_FINE_LOCATION);
            need.add(Manifest.permission.ACCESS_COARSE_LOCATION);
        }
        if (Build.VERSION.SDK_INT >= 33 && !granted(Manifest.permission.POST_NOTIFICATIONS)) {
            need.add(Manifest.permission.POST_NOTIFICATIONS);
        }
        if (need.isEmpty() || Build.VERSION.SDK_INT < 23) go();
        else requestPermissions(need.toArray(new String[0]), REQ);
    }

    private boolean granted(String p) {
        return Build.VERSION.SDK_INT < 23 || checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED;
    }

    @Override
    public void onRequestPermissionsResult(int code, String[] perms, int[] res) {
        if (granted(Manifest.permission.ACCESS_FINE_LOCATION) || granted(Manifest.permission.ACCESS_COARSE_LOCATION)) {
            go();
        } else {
            Peera.prefs(this).edit().remove("pending").apply();
            Toast.makeText(this, "ლოკაციაზე წვდომა არ მოგვეცა. ჩართე ტელეფონის პარამეტრებში", Toast.LENGTH_LONG).show();
            finish();
        }
    }

    private void go() {
        LocService.start(this);
        Toast.makeText(this, "ლაივ ლოკაცია ირთვება", Toast.LENGTH_SHORT).show();
        finish();
    }
}
