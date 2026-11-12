package my.peera.peera

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
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
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
}
