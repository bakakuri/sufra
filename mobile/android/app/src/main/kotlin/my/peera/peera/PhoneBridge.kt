package my.peera.peera

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/** The app's own files handed to other apps (the installer, for an update): only the cache's "updates" folder. */
class PeeraFiles : FileProvider()

/**
 * "peera/system": the phone itself for the app. What phone and Android it is (for the error reports), a link to the
 * site or something shared from another app that opened Peera (kept until the app takes it), and installing a new
 * version the app downloaded (after checking it is the file the release names).
 */
class PhoneBridge(private val act: Activity) {
    var channel: MethodChannel? = null

    /** the intent that brought a link or a share, until the app takes it */
    private var incoming: Intent? = null

    /** keeps [i] when it carries a link to the site or a share; tells the app if it is running */
    fun offer(i: Intent?, fresh: Boolean) {
        if (i == null || !fresh || (i.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return
        val link = i.action == Intent.ACTION_VIEW && (i.data?.host == "www.peera.my" || i.data?.host == "peera.my")
        val share = i.action == Intent.ACTION_SEND || i.action == Intent.ACTION_SEND_MULTIPLE
        if (!link && !share) return
        incoming = i
        channel?.invokeMethod("arrived", null)
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "device" -> result.success(
                mapOf(
                    "model" to Build.MODEL,
                    "maker" to Build.MANUFACTURER,
                    "android" to Build.VERSION.RELEASE,
                    "sdk" to Build.VERSION.SDK_INT,
                    "abis" to Build.SUPPORTED_ABIS.toList(),
                    "cache" to act.cacheDir.absolutePath,
                )
            )
            "take" -> {
                val i = incoming
                incoming = null
                if (i == null) {
                    result.success(null)
                } else {
                    // copying shared files can take a moment (a video): away from the screen's thread
                    Thread {
                        val out = try { read(i) } catch (e: Exception) { null }
                        act.runOnUiThread { result.success(out) }
                    }.start()
                }
            }
            "canInstall" -> result.success(if (Build.VERSION.SDK_INT >= 26) act.packageManager.canRequestPackageInstalls() else true)
            "allowInstall" -> {
                try {
                    act.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${act.packageName}")))
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
            "install" -> {
                val path = call.argument<String>("path") ?: ""
                val sha = (call.argument<String>("sha256") ?: "").lowercase()
                Thread {
                    val f = File(path)
                    val ok = f.isFile && f.canonicalPath.startsWith(File(act.cacheDir, "updates").canonicalPath) && (sha.isEmpty() || sha256(f) == sha)
                    act.runOnUiThread {
                        if (!ok) {
                            result.success("bad")
                        } else {
                            try {
                                val uri = FileProvider.getUriForFile(act, "${act.packageName}.files", f)
                                val view = Intent(Intent.ACTION_VIEW)
                                    .setDataAndType(uri, "application/vnd.android.package-archive")
                                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                                act.startActivity(view)
                                result.success("ok")
                            } catch (e: Exception) {
                                result.success("fail")
                            }
                        }
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    private fun sha256(f: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        f.inputStream().use { s ->
            val buf = ByteArray(1 shl 16)
            while (true) {
                val n = s.read(buf)
                if (n < 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    /** a link: its address; a share: its words and its files, copied into the app's cache (at most ten) */
    private fun read(i: Intent): Map<String, Any?> {
        if (i.action == Intent.ACTION_VIEW) return mapOf("kind" to "link", "url" to i.dataString)
        val uris = mutableListOf<Uri>()
        if (i.action == Intent.ACTION_SEND_MULTIPLE) {
            val list: List<Uri>? = if (Build.VERSION.SDK_INT >= 33) {
                i.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                i.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }
            list?.let { uris.addAll(it) }
        } else {
            val one: Uri? = if (Build.VERSION.SDK_INT >= 33) {
                i.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            one?.let { uris.add(it) }
        }
        val dir = File(act.cacheDir, "shared")
        dir.mkdirs()
        dir.listFiles()?.forEach { it.delete() }
        val files = mutableListOf<Map<String, String>>()
        for ((n, u) in uris.take(10).withIndex()) {
            try {
                val mime = act.contentResolver.getType(u) ?: i.type ?: ""
                val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "bin"
                val f = File(dir, "s$n.$ext")
                act.contentResolver.openInputStream(u)?.use { inp -> f.outputStream().use { inp.copyTo(it) } } ?: continue
                files.add(mapOf("path" to f.absolutePath, "mime" to mime))
            } catch (e: Exception) {
            }
        }
        return mapOf("kind" to "share", "text" to (i.getStringExtra(Intent.EXTRA_TEXT) ?: ""), "files" to files)
    }
}
