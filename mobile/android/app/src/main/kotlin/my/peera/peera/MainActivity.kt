package my.peera.peera

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.tasks.Tasks
import com.google.firebase.installations.FirebaseInstallations
import com.google.firebase.messaging.FirebaseMessaging
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    /* the screen a notification asked for ("map": the live location's notification), until the app takes it */
    private var openAsked: String? = null
    private var permWait: MethodChannel.Result? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.getStringExtra("open")?.let { openAsked = it }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        intent?.getStringExtra("open")?.let { openAsked = it }
        // the channel Peera's notifications arrive on: with sound and a banner; its name shows in the phone's settings
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("peera", "შეტყობინებები", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "მიმოწერა, კომენტარები, მეგობრები"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // videos before upload: size, poster frame, a lighter copy
        val video = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "peera/video")
        val tools = VideoTools(this, video)
        video.setMethodCallHandler { call, result -> tools.handle(call, result) }
        // the live location: asking for it, the place now, and the service that shares it with the app closed
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "peera/loc").setMethodCallHandler { call, result ->
            when (call.method) {
                "permission" -> askLocation(result, call.argument<Boolean>("ask") != false)
                "here" -> here(result)
                "start" -> {
                    LocService.prefs(this).edit()
                        .putString("token", call.argument<String>("token"))
                        .putString("aud", if (call.argument<String>("aud") == "public") "public" else "friends")
                        .putInt("min", call.argument<Int>("min") ?: 60)
                        .putBoolean("approx", call.argument<Boolean>("approx") == true)
                        .putString("url", call.argument<String>("url"))
                        .putString("key", call.argument<String>("key"))
                        .putBoolean("pending", true)
                        .apply()
                    try {
                        LocService.start(this)
                        result.success(true)
                    } catch (e: Exception) {
                        LocService.prefs(this).edit().remove("token").remove("pending").apply()
                        result.success(false)
                    }
                }
                "stop" -> {
                    LocService.stop(this, call.argument<Boolean>("tell") == true)
                    result.success(true)
                }
                "running" -> result.success(LocService.prefs(this).getString("token", null) != null)
                "takeOpen" -> {
                    result.success(openAsked)
                    openAsked = null
                }
                "settings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        // "ჩართვა" on the profile: the phone's own notification settings for this app
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "peera/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "notificationSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    }
                    startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                // why registering for notifications failed: each step with the whole chain of causes
                "pushDiagnose" -> Thread {
                    val out = StringBuilder()
                    fun chain(e: Throwable?): String {
                        val parts = mutableListOf<String>()
                        var x = e
                        while (x != null && parts.size < 6) {
                            parts.add("${x.javaClass.simpleName}: ${x.message}")
                            x = x.cause
                        }
                        return parts.joinToString(" <- ")
                    }
                    try {
                        val gms = packageManager.getPackageInfo("com.google.android.gms", 0)
                        out.append("gms ${gms.versionName}; ")
                    } catch (e: Exception) {
                        out.append("gms missing; ")
                    }
                    out.append("android ${Build.VERSION.SDK_INT} ${Build.MANUFACTURER} ${Build.MODEL}; ")
                    try {
                        val t = Tasks.await(FirebaseInstallations.getInstance().getToken(false), 30, TimeUnit.SECONDS)
                        out.append("fis ok ${t.token.length}; ")
                    } catch (e: Exception) {
                        out.append("fis: ${chain(e)}; ")
                    }
                    try {
                        val fid = Tasks.await(FirebaseInstallations.getInstance().id, 30, TimeUnit.SECONDS)
                        out.append("fid ${fid.take(6)}; ")
                        Tasks.await(FirebaseMessaging.getInstance().register(), 30, TimeUnit.SECONDS)
                        out.append("register ok; ")
                    } catch (e: Exception) {
                        out.append("register: ${chain(e)}; ")
                    }
                    runOnUiThread { result.success(out.toString()) }
                }.start()
                else -> result.notImplemented()
            }
        }
    }

    private fun has(p: String) = checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
    private fun located() = has(Manifest.permission.ACCESS_FINE_LOCATION) || has(Manifest.permission.ACCESS_COARSE_LOCATION)

    /* "granted", or "denied" (asked now and refused), or "blocked" (the phone no longer asks: only its settings can) */
    private fun askLocation(result: MethodChannel.Result, ask: Boolean) {
        val need = mutableListOf<String>()
        if (!located()) {
            need.add(Manifest.permission.ACCESS_FINE_LOCATION)
            need.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        // the running share is always shown in a notification
        if (Build.VERSION.SDK_INT >= 33 && !has(Manifest.permission.POST_NOTIFICATIONS)) need.add(Manifest.permission.POST_NOTIFICATIONS)
        if (located() && (need.isEmpty() || !ask)) {
            result.success("granted")
            return
        }
        if (!ask) {
            result.success("denied")
            return
        }
        permWait?.success(if (located()) "granted" else "denied")
        permWait = result
        requestPermissions(need.toTypedArray(), 7)
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, res: IntArray) {
        super.onRequestPermissionsResult(code, perms, res)
        if (code != 7) return
        val r = permWait ?: return
        permWait = null
        r.success(
            when {
                located() -> "granted"
                !shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION) -> "blocked"
                else -> "denied"
            }
        )
    }

    /* where the phone is now: a fresh known place at once, otherwise the first fix within 15 seconds */
    private fun here(result: MethodChannel.Result) {
        val lm = getSystemService(LOCATION_SERVICE) as? LocationManager
        if (lm == null || !located()) {
            result.success(null)
            return
        }
        fun out(l: Location?) = l?.let { mapOf("lat" to it.latitude, "lng" to it.longitude, "acc" to it.accuracy.toDouble()) }
        try {
            val known: Location? = lm.getProviders(true).mapNotNull { lm.getLastKnownLocation(it) }.maxByOrNull { it.time }
            if (known != null && System.currentTimeMillis() - known.time < 60000 && known.accuracy < 200) {
                result.success(out(known))
                return
            }
            val main = Handler(Looper.getMainLooper())
            var done = false
            lateinit var listener: LocationListener
            val finish = { l: Location? ->
                if (!done) {
                    done = true
                    try { lm.removeUpdates(listener) } catch (e: Exception) {}
                    result.success(out(l ?: known))
                }
            }
            listener = object : LocationListener {
                override fun onLocationChanged(l: Location) { finish(l) }
                @Deprecated("old phones") override fun onStatusChanged(p: String?, s: Int, b: Bundle?) {}
                override fun onProviderEnabled(p: String) {}
                override fun onProviderDisabled(p: String) {}
            }
            var any = false
            for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
                if (lm.isProviderEnabled(p)) {
                    lm.requestLocationUpdates(p, 1000L, 0f, listener, Looper.getMainLooper())
                    any = true
                }
            }
            if (!any) {
                finish(null)
                return
            }
            main.postDelayed({ finish(null) }, 15000)
        } catch (e: SecurityException) {
            result.success(null)
        }
    }
}
