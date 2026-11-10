package my.peera.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.widget.Toast;

import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/* The shared place while the app is closed: a foreground service (always with its notification and a stop button)
   that sends the place to the server when it moved (every 8 seconds at most) or, standing still, every minute.
   The first fix starts the share (who sees it, for how long, how exactly: as chosen on the site). It stops when the
   person stops it (here or on the site), when the share runs out, or when the server no longer knows the secret. */
public class LocService extends Service implements LocationListener {
    private static final String CH = "loc";
    private static final int NID = 42;
    private static final long MOVE_MS = 8000, STILL_MS = 60000;

    private final Handler main = new Handler(Looper.getMainLooper());
    private final ExecutorService net = Executors.newSingleThreadExecutor();
    private LocationManager lm;
    private Location last, sent;
    private long sentAt;
    private volatile boolean busy, on;
    private long expiresAt;

    static void start(Context c) {
        Intent i = new Intent(c, LocService.class).setAction("start");
        if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i); else c.startService(i);
    }

    /* tell: also end the share on the server (from the notification's button) */
    static void stop(Context c, boolean tell) {
        Intent i = new Intent(c, LocService.class).setAction(tell ? "stop_tell" : "stop");
        try { c.startService(i); } catch (Exception e) { Peera.prefs(c).edit().clear().apply(); }
    }

    @Override
    public IBinder onBind(Intent i) { return null; }

    @Override
    public int onStartCommand(Intent intent, int flags, int id) {
        String a = intent != null ? intent.getAction() : "start";
        if ("stop".equals(a) || "stop_tell".equals(a)) {
            finish("stop_tell".equals(a), null);
            return START_NOT_STICKY;
        }
        if (Peera.prefs(this).getString("token", null) == null) {
            stopSelf();
            return START_NOT_STICKY;
        }
        try {
            Notification n = notice();
            if (Build.VERSION.SDK_INT >= 29) startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION);
            else startForeground(NID, n);
        } catch (Exception e) {
            /* Android does not let a location service start from the background: it waits for the next tap on the site */
            stopSelf();
            return START_NOT_STICKY;
        }
        if (!on) {
            on = true;
            listen();
            main.postDelayed(beat, 20000);
        } else {
            /* started again from the site (other choices, a new secret): the new share starts with the next place */
            sentAt = 0;
            maybeSend();
        }
        return START_STICKY;
    }

    private void listen() {
        lm = (LocationManager) getSystemService(LOCATION_SERVICE);
        if (lm == null) return;
        try {
            boolean any = false;
            if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 5000, 10, this, Looper.getMainLooper());
                any = true;
            }
            if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 10000, 20, this, Looper.getMainLooper());
                any = true;
            }
            Location k = null;
            for (String p : lm.getProviders(true)) {
                Location l = lm.getLastKnownLocation(p);
                if (l != null && (k == null || l.getTime() > k.getTime())) k = l;
            }
            if (k != null && System.currentTimeMillis() - k.getTime() < 120000) onLocationChanged(k);
            if (!any) toast("ტელეფონში ლოკაცია (GPS) გამორთულია");
        } catch (SecurityException e) {
            finish(false, "ლოკაციაზე წვდომა არ არის");
        }
    }

    private final Runnable beat = new Runnable() {
        @Override
        public void run() {
            if (!on) return;
            if (expiresAt > 0 && System.currentTimeMillis() > expiresAt) {
                finish(false, "ლაივ ლოკაციის გაზიარება დასრულდა");
                return;
            }
            maybeSend();
            main.postDelayed(this, 20000);
        }
    };

    @Override
    public void onLocationChanged(Location l) {
        if (l == null) return;
        if (last != null && l.getAccuracy() > 150 && last.getAccuracy() < l.getAccuracy()
                && l.getTime() - last.getTime() < 30000) return; /* a rough network fix right after a good GPS one */
        last = l;
        maybeSend();
    }

    @Override public void onStatusChanged(String p, int s, Bundle b) { }
    @Override public void onProviderEnabled(String p) { }
    @Override public void onProviderDisabled(String p) { }

    private void maybeSend() {
        final Location l = last;
        if (l == null || busy || !on) return;
        long now = System.currentTimeMillis();
        float moved = sent == null ? 1e9f : sent.distanceTo(l);
        if (now - sentAt < (moved >= 15 ? MOVE_MS : STILL_MS)) return;
        busy = true;
        final SharedPreferences p = Peera.prefs(this);
        net.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    String t = p.getString("token", null);
                    if (t == null) { post(new Runnable() { public void run() { finish(false, null); } }); return; }
                    JSONObject b = new JSONObject().put("p_token", t).put("p_lat", l.getLatitude()).put("p_lng", l.getLongitude())
                            .put("p_acc", Math.round(l.getAccuracy()));
                    final boolean start = p.getBoolean("pending", false);
                    JSONObject r;
                    if (start) {
                        b.put("p_audience", p.getString("aud", "friends")).put("p_minutes", p.getInt("min", 60))
                                .put("p_approx", p.getBoolean("approx", false));
                        r = Peera.rpc("loc_share_dev", b);
                        p.edit().remove("pending").apply();
                    } else {
                        b.put("p_heading", l.hasBearing() ? (int) l.getBearing() : JSONObject.NULL)
                                .put("p_speed", l.hasSpeed() ? (double) l.getSpeed() : JSONObject.NULL);
                        r = Peera.rpc("loc_update_dev", b);
                    }
                    if (!r.optBoolean("on", false)) {
                        post(new Runnable() { public void run() { finish(false, start ? null : "ლაივ ლოკაციის გაზიარება დასრულდა"); } });
                        return;
                    }
                    if (!r.optBoolean("skip", false)) {
                        sent = l;
                        sentAt = System.currentTimeMillis();
                    }
                    String ex = r.optString("expires_at", "");
                    final long exp = ex.isEmpty() || "null".equals(ex) ? 0 : parse(ex);
                    post(new Runnable() { public void run() { if (exp != expiresAt) { expiresAt = exp; refresh(); } } });
                } catch (Peera.RpcError e) {
                    final String m = e.getMessage() == null ? "" : e.getMessage();
                    if (m.contains("minor_public") || m.contains("not_allowed") || m.contains("bad_token")) {
                        post(new Runnable() { public void run() {
                            finish(false, m.contains("minor_public") ? "18 წლამდე ლოკაციას მხოლოდ მეგობრებს უზიარებ" : "ლოკაციის გაზიარება ვერ ჩაირთო");
                        } });
                    }
                } catch (Exception e) {
                    /* no connection: the next fix tries again */
                } finally {
                    busy = false;
                }
            }
        });
    }

    private void post(Runnable r) { main.post(r); }

    private static long parse(String iso) {
        try {
            String s = iso.replace("Z", "+00:00");
            int dot = s.indexOf('.');
            int tz = Math.max(s.lastIndexOf('+'), s.lastIndexOf('-'));
            if (dot > 0 && tz > dot) s = s.substring(0, dot) + s.substring(tz);
            if (s.length() > 6 && s.charAt(s.length() - 3) == ':') s = s.substring(0, s.length() - 3) + s.substring(s.length() - 2);
            java.text.SimpleDateFormat f = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", java.util.Locale.US);
            return f.parse(s).getTime();
        } catch (Exception e) {
            return 0;
        }
    }

    private void finish(final boolean tell, String msg) {
        boolean was = on;
        on = false;
        main.removeCallbacks(beat);
        if (lm != null) try { lm.removeUpdates(this); } catch (Exception ignored) { }
        final SharedPreferences p = Peera.prefs(this);
        final String t = p.getString("token", null);
        p.edit().clear().apply();
        if (tell && t != null) {
            net.execute(new Runnable() {
                @Override
                public void run() {
                    try { Peera.rpc("loc_stop_dev", new JSONObject().put("p_token", t)); } catch (Exception ignored) { }
                }
            });
        }
        if (msg != null && was) toast(msg);
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE); else stopForeground(true);
        stopSelf();
    }

    private void toast(final String m) {
        main.post(new Runnable() { public void run() { Toast.makeText(getApplicationContext(), m, Toast.LENGTH_LONG).show(); } });
    }

    private void refresh() {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (nm != null && on) nm.notify(NID, notice());
    }

    /* the notification that is there as long as the place is shared: what it is, until when, and a stop button */
    private Notification notice() {
        NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        if (Build.VERSION.SDK_INT >= 26 && nm != null && nm.getNotificationChannel(CH) == null) {
            NotificationChannel ch = new NotificationChannel(CH, "ლაივ ლოკაცია", NotificationManager.IMPORTANCE_LOW);
            ch.setDescription("ჩანს, სანამ შენი ლოკაცია ზიარდება");
            ch.setShowBadge(false);
            nm.createNotificationChannel(ch);
        }
        int fl = Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT : PendingIntent.FLAG_UPDATE_CURRENT;
        PendingIntent stop = PendingIntent.getService(this, 1, new Intent(this, LocService.class).setAction("stop_tell"), fl);
        Intent open = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.peera.my/#map"), this, LauncherActivity.class);
        PendingIntent show = PendingIntent.getActivity(this, 2, open, fl);
        String aud = "public".equals(Peera.prefs(this).getString("aud", "friends")) ? "ყველას უჩანს" : "მეგობრებს უჩანს";
        Notification.Builder b = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, CH) : new Notification.Builder(this);
        b.setSmallIcon(R.drawable.ic_loc)
                .setContentTitle("ლაივ ლოკაცია ჩართულია")
                .setContentText(aud + " · Peera")
                .setOngoing(true)
                .setContentIntent(show)
                .addAction(new Notification.Action.Builder(null, "გაჩერება", stop).build());
        if (Build.VERSION.SDK_INT >= 24 && expiresAt > 0) {
            b.setWhen(expiresAt).setUsesChronometer(true).setChronometerCountDown(true).setShowWhen(true);
        }
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE);
        return b.build();
    }

    @Override
    public void onDestroy() {
        on = false;
        main.removeCallbacks(beat);
        if (lm != null) try { lm.removeUpdates(this); } catch (Exception ignored) { }
        net.shutdown();
        super.onDestroy();
    }
}
