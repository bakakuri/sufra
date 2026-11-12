package my.peera.peera

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/** Videos before upload: their size and length, a picture for the poster, and a lighter copy (H.264) when they are big. */
class VideoTools(private val context: Context, private val channel: MethodChannel) {
    private val main = Handler(Looper.getMainLooper())
    private var running: Transformer? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        when (call.method) {
            "info" -> background(result) { info(path!!) }
            "poster" -> background(result) { poster(path!!) }
            "compress" -> compress(path!!, call.argument<Int>("shortSide") ?: 0, result)
            "cancel" -> {
                running?.cancel()
                running = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any) {
        Thread {
            try {
                val r = work()
                main.post { result.success(r) }
            } catch (e: Exception) {
                main.post { result.error("video", e.message ?: e.javaClass.simpleName, null) }
            }
        }.start()
    }

    private fun info(path: String): Map<String, Any> {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            var w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            var h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val rotation = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            if (rotation == 90 || rotation == 270) {
                val t = w
                w = h
                h = t
            }
            val dur = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            return mapOf("w" to w, "h" to h, "dur" to dur, "size" to File(path).length())
        } finally {
            r.release()
        }
    }

    /** a frame from the first half second, at most 960 px, as JPEG */
    private fun poster(path: String): String {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val dur = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val at = minOf(500_000L, dur * 500L)
            var bmp = r.getFrameAtTime(at, MediaMetadataRetriever.OPTION_CLOSEST_SYNC) ?: throw IllegalStateException("no frame")
            val big = maxOf(bmp.width, bmp.height)
            if (big > 960) {
                val s = 960f / big
                bmp = Bitmap.createScaledBitmap(bmp, (bmp.width * s).toInt(), (bmp.height * s).toInt(), true)
            }
            val out = File(context.cacheDir, "poster-${System.currentTimeMillis()}.jpg")
            FileOutputStream(out).use { bmp.compress(Bitmap.CompressFormat.JPEG, 82, it) }
            return out.path
        } finally {
            r.release()
        }
    }

    /** the phone's own encoder: H.264 around 2.5 Mbit/s, AAC sound, the short side made [shortSide] px when it is given */
    private fun compress(path: String, shortSide: Int, result: MethodChannel.Result) {
        val out = File(context.cacheDir, "video-${System.currentTimeMillis()}.mp4")
        var answered = false
        val transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(context)
                    .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(2_500_000).build())
                    .setEnableFallback(true)
                    .build()
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    running = null
                    if (!answered) {
                        answered = true
                        result.success(out.path)
                    }
                }

                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) {
                    running = null
                    out.delete()
                    if (!answered) {
                        answered = true
                        result.error("compress", exportException.message ?: "export failed", null)
                    }
                }
            })
            .build()
        running = transformer
        val effects: List<Effect> = if (shortSide > 0) listOf(Presentation.createForShortSide(shortSide)) else listOf()
        val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
            .setEffects(Effects(listOf<AudioProcessor>(), effects))
            .build()
        transformer.start(item, out.path)
        // how far it got, to the app every 300 ms
        val holder = ProgressHolder()
        val tick = object : Runnable {
            override fun run() {
                if (running !== transformer) return
                if (transformer.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("progress", holder.progress / 100.0)
                }
                main.postDelayed(this, 300)
            }
        }
        main.postDelayed(tick, 300)
    }
}
