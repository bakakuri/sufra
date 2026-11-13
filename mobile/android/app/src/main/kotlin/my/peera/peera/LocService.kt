package my.peera.peera

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.widget.Toast
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/* The shared place while the app is closed (as in the site's Android app): a foreground service, always with its
   notification and a stop button, that sends the place to the server when it moved (every 8 seconds at most) or,
   standing still, every minute. It holds only this phone's secret for the share (loc_device_token), which can do
   nothing but move or stop this person's place. The first fix starts the share as chosen in the app. It stops when the
   person stops it (here or in the app or on the site), when the share runs out, or when the server no longer knows
   the secret. It never starts by itself. */
class LocService : Service(), LocationListener {
    companion object {
        private const val CH = "loc"
        private const val NID = 42
        private const val MOVE_MS = 8000L
        private const val STILL_MS = 60000L

        fun prefs(c: Context): SharedPreferences = c.getSharedPreferences("loc", Context.MODE_PRIVATE)

        fun start(c: Context) {
            val i = Intent(c, LocService::class.java).setAction("start")
            if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
        }

        /* tell: also end the share on the server (the notification's button) */
        fun stop(c: Context, tell: Boolean) {
            val i = Intent(c, LocService::class.java).setAction(if (tell) "stop_tell" else "stop")
            try {
                c.startService(i)
            } catch (e: Exception) {
                prefs(c).edit().clear().apply()
            }
        }

        class RpcError(msg: String) : Exception(msg)

        /* POST /rest/v1/rpc/<fn> as the public role; the secret travels in the body */
        fun rpc(c: Context, fn: String, body: JSONObject): JSONObject {
            val p = prefs(c)
            val base = p.getString("url", null) ?: throw RpcError("no_server")
            val key = p.getString("key", null) ?: throw RpcError("no_server")
            val con = URL("$base/rest/v1/rpc/$fn").openConnection() as HttpURLConnection
            try {
                con.requestMethod = "POST"
                con.connectTimeout = 15000
                con.readTimeout = 20000
                con.doOutput = true
                con.setRequestProperty("apikey", key)
                con.setRequestProperty("Authorization", "Bearer $key")
                con.setRequestProperty("Content-Type", "application/json")
                con.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                val code = con.responseCode
                val stream = if (code >= 400) con.errorStream else con.inputStream
                val out = ByteArrayOutputStream()
                stream?.use { it.copyTo(out) }
                val text = out.toString("UTF-8").trim()
                if (code >= 400) {
                    val msg = try { JSONObject(text).optString("message", text) } catch (e: Exception) { text }
                    throw RpcError(msg)
                }
                return if (text.startsWith("{")) JSONObject(text) else JSONObject()
            } finally {
                con.disconnect()
            }
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private val net = Executors.newSingleThreadExecutor()
    private var lm: LocationManager? = null
    private var last: Location? = null
    private var sent: Location? = null
    private var sentAt = 0L
    @Volatile private var busy = false
    @Volatile private var on = false
    private var expiresAt = 0L

    override fun onBind(i: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, id: Int): Int {
        val a = intent?.action ?: "start"
        if (a == "stop" || a == "stop_tell") {
            finish(a == "stop_tell", null)
            return START_NOT_STICKY
        }
        if (prefs(this).getString("token", null) == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val n = notice()
            if (Build.VERSION.SDK_INT >= 29) startForeground(NID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            else startForeground(NID, n)
        } catch (e: Exception) {
            // Android does not let a location service start from the background: it waits for the next tap in the app
            stopSelf()
            return START_NOT_STICKY
        }
        if (!on) {
            on = true
            listen()
            main.postDelayed(beat, 20000)
        } else {
            // started again (other choices, a new secret): the new share starts with the next place
            sentAt = 0
            maybeSend()
        }
        return START_STICKY
    }

    private fun listen() {
        val m = getSystemService(LOCATION_SERVICE) as? LocationManager ?: return
        lm = m
        try {
            var any = false
            if (m.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                m.requestLocationUpdates(LocationManager.GPS_PROVIDER, 5000L, 10f, this, Looper.getMainLooper())
                any = true
            }
            if (m.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                m.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 10000L, 20f, this, Looper.getMainLooper())
                any = true
            }
            var k: Location? = null
            for (p in m.getProviders(true)) {
                val l = m.getLastKnownLocation(p)
                if (l != null && (k == null || l.time > k.time)) k = l
            }
            if (k != null && System.currentTimeMillis() - k.time < 120000) onLocationChanged(k)
            if (!any) toast("ტელეფონში ლოკაცია (GPS) გამორთულია")
        } catch (e: SecurityException) {
            finish(false, "ლოკაციაზე წვდომა არ არის")
        }
    }

    private val beat = object : Runnable {
        override fun run() {
            if (!on) return
            if (expiresAt > 0 && System.currentTimeMillis() > expiresAt) {
                finish(false, "ლაივ ლოკაციის გაზიარება დასრულდა")
                return
            }
            maybeSend()
            main.postDelayed(this, 20000)
        }
    }

    override fun onLocationChanged(l: Location) {
        val prev = last
        // a rough network fix right after a good GPS one
        if (prev != null && l.accuracy > 150 && prev.accuracy < l.accuracy && l.time - prev.time < 30000) return
        last = l
        prefs(this).edit().putFloat("lat", l.latitude.toFloat()).putFloat("lng", l.longitude.toFloat()).putLong("at", System.currentTimeMillis()).apply()
        maybeSend()
    }

    @Deprecated("old phones") override fun onStatusChanged(p: String?, s: Int, b: Bundle?) {}
    override fun onProviderEnabled(p: String) {}
    override fun onProviderDisabled(p: String) {}

    private fun maybeSend() {
        val l = last ?: return
        if (busy || !on) return
        val now = System.currentTimeMillis()
        val moved = sent?.distanceTo(l) ?: 1e9f
        if (now - sentAt < (if (moved >= 15) MOVE_MS else STILL_MS)) return
        busy = true
        val p = prefs(this)
        net.execute {
            try {
                val t = p.getString("token", null)
                if (t == null) {
                    main.post { finish(false, null) }
                    return@execute
                }
                val b = JSONObject().put("p_token", t).put("p_lat", l.latitude).put("p_lng", l.longitude).put("p_acc", Math.round(l.accuracy))
                val first = p.getBoolean("pending", false)
                val r: JSONObject
                if (first) {
                    b.put("p_audience", p.getString("aud", "friends")).put("p_minutes", p.getInt("min", 60)).put("p_approx", p.getBoolean("approx", false))
                    r = rpc(this, "loc_share_dev", b)
                    p.edit().remove("pending").apply()
                } else {
                    b.put("p_heading", if (l.hasBearing()) l.bearing.toInt() else JSONObject.NULL)
                        .put("p_speed", if (l.hasSpeed()) l.speed.toDouble() else JSONObject.NULL)
                    r = rpc(this, "loc_update_dev", b)
                }
                if (!r.optBoolean("on", false)) {
                    main.post { finish(false, if (first) null else "ლაივ ლოკაციის გაზიარება დასრულდა") }
                    return@execute
                }
                if (!r.optBoolean("skip", false)) {
                    sent = l
                    sentAt = System.currentTimeMillis()
                }
                val ex = r.optString("expires_at", "")
                val exp = if (ex.isEmpty() || ex == "null") 0L else parse(ex)
                main.post {
                    if (exp != expiresAt) {
                        expiresAt = exp
                        refresh()
                    }
                }
            } catch (e: RpcError) {
                val m = e.message ?: ""
                if (m.contains("minor_public") || m.contains("not_allowed") || m.contains("bad_token")) {
                    main.post { finish(false, if (m.contains("minor_public")) "18 წლამდე ლოკაციას მხოლოდ მეგობრებს უზიარებ" else "ლოკაციის გაზიარება ვერ ჩაირთო") }
                }
            } catch (e: Exception) {
                // no connection: the next fix tries again
            } finally {
                busy = false
            }
        }
    }

    /* "2026-11-13T09:15:00.123+00:00" (java.time needs Android 8; this works on 7 too) */
    private fun parse(iso: String): Long = try {
        var s = iso.replace(" ", "T").replace("Z", "+00:00")
        val dot = s.indexOf('.')
        val tz = maxOf(s.lastIndexOf('+'), s.lastIndexOf('-'))
        if (dot > 0 && tz > dot) s = s.substring(0, dot) + s.substring(tz)
        if (s.length > 6 && s[s.length - 3] == ':') s = s.substring(0, s.length - 3) + s.substring(s.length - 2)
        java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", java.util.Locale.US).parse(s)?.time ?: 0L
    } catch (e: Exception) {
        0L
    }

    private fun finish(tell: Boolean, msg: String?) {
        val was = on
        on = false
        main.removeCallbacks(beat)
        try { lm?.removeUpdates(this) } catch (e: Exception) {}
        val p = prefs(this)
        val t = p.getString("token", null)
        val url = p.getString("url", null)
        val key = p.getString("key", null)
        // the server's address stays for the next share; the secret and the choices go
        p.edit().clear().putString("url", url).putString("key", key).apply()
        if (tell && t != null) {
            net.execute {
                try { rpc(this, "loc_stop_dev", JSONObject().put("p_token", t)) } catch (e: Exception) {}
            }
        }
        if (msg != null && was) toast(msg)
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
        stopSelf()
    }

    private fun toast(m: String) {
        main.post { Toast.makeText(applicationContext, m, Toast.LENGTH_LONG).show() }
    }

    private fun refresh() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as? NotificationManager ?: return
        if (on) nm.notify(NID, notice())
    }

    /* the notification that is there as long as the place is shared: what it is, until when, and a stop button */
    private fun notice(): Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as? NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm != null && nm.getNotificationChannel(CH) == null) {
            val ch = NotificationChannel(CH, "ლაივ ლოკაცია", NotificationManager.IMPORTANCE_LOW)
            ch.description = "ჩანს, სანამ შენი ლოკაცია ზიარდება"
            ch.setShowBadge(false)
            nm.createNotificationChannel(ch)
        }
        val fl = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        val stop = PendingIntent.getService(this, 1, Intent(this, LocService::class.java).setAction("stop_tell"), fl)
        val open = Intent(this, MainActivity::class.java).putExtra("open", "map").addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val show = PendingIntent.getActivity(this, 2, open, fl)
        val aud = if (prefs(this).getString("aud", "friends") == "public") "ყველას უჩანს" else "მეგობრებს უჩანს"
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CH) else @Suppress("DEPRECATION") Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_loc)
            .setContentTitle("ლაივ ლოკაცია ჩართულია")
            .setContentText("$aud · Peera")
            .setOngoing(true)
            .setContentIntent(show)
            .addAction(Notification.Action.Builder(null, "გაჩერება", stop).build())
        if (Build.VERSION.SDK_INT >= 24 && expiresAt > 0) {
            b.setWhen(expiresAt).setUsesChronometer(true).setChronometerCountDown(true).setShowWhen(true)
        }
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        return b.build()
    }

    override fun onDestroy() {
        on = false
        main.removeCallbacks(beat)
        try { lm?.removeUpdates(this) } catch (e: Exception) {}
        net.shutdown()
        super.onDestroy()
    }
}
