package my.peera.peera

import android.media.MediaRecorder
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/* Voice messages: the microphone into a small AAC file (m4a, which the site's browsers play as well). */
class VoiceRec(private val act: MainActivity) {
    private var rec: MediaRecorder? = null
    private var file: File? = null
    private var t0 = 0L

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permission" -> act.askMic(result)
            "start" -> result.success(start())
            "level" -> result.success(level())
            "stop" -> result.success(stop(true))
            "cancel" -> {
                stop(false)
                result.success(null)
            }
            "settings" -> {
                act.openAppSettings()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun recorder(): MediaRecorder = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(act) else MediaRecorder()

    private fun start(): Boolean {
        stop(false)
        val f = File(act.cacheDir, "voice-${System.currentTimeMillis()}.m4a")
        var r: MediaRecorder? = null
        return try {
            r = recorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioChannels(1)
            r.setAudioSamplingRate(44100)
            r.setAudioEncodingBitRate(64000)
            r.setOutputFile(f.absolutePath)
            r.prepare()
            r.start()
            rec = r
            file = f
            t0 = System.currentTimeMillis()
            true
        } catch (e: Exception) {
            try { r?.release() } catch (x: Exception) {}
            f.delete()
            false
        }
    }

    /* how loud it is now, 0..1 (the dot on the recording bar grows with it) */
    private fun level(): Double = try {
        (rec?.maxAmplitude ?: 0) / 32767.0
    } catch (e: Exception) {
        0.0
    }

    /* the file and its length; null when cancelled or when nothing was recorded */
    private fun stop(keep: Boolean): Map<String, Any>? {
        val r = rec ?: return null
        val f = file
        val ms = System.currentTimeMillis() - t0
        rec = null
        file = null
        var ok = true
        try { r.stop() } catch (e: Exception) { ok = false } // straight after starting there is nothing yet
        try { r.release() } catch (e: Exception) {}
        if (!keep || !ok || f == null) {
            f?.delete()
            return null
        }
        return mapOf("path" to f.absolutePath, "ms" to ms)
    }

    fun release() {
        stop(false)
    }
}
