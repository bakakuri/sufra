package my.peera.peera

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

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
}
