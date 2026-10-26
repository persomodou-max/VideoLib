package com.videolib.videolib

import android.app.PictureInPictureParams
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val PIP_CHANNEL    = "videolib/pip"
        private const val THUMB_CHANNEL  = "videolib/thumbnail"
        private const val SYSINFO_CHANNEL = "flutter/system_info"
    }

    // Thread pool for thumbnail generation – keeps off the main thread
    private val thumbExecutor = Executors.newFixedThreadPool(3)
    private val mainHandler   = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── System info (SDK version — replaces device_info_plus) ────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSINFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSdkVersion" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }

        // ── PiP ────────────────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "enterPiP") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                            enterPictureInPictureMode(params)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("PIP_ERROR", e.message, null)
                        }
                    } else {
                        result.error("UNSUPPORTED", "PiP requires Android 8+", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // ── Thumbnail via MediaMetadataRetriever ───────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, THUMB_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getThumbnail") {
                    val path     = call.argument<String>("path")
                    val timeUs   = (call.argument<Int>("timeUs") ?: 5_000_000).toLong()
                    val maxWidth = call.argument<Int>("maxWidth") ?: 320
                    val quality  = call.argument<Int>("quality") ?: 70

                    if (path == null) {
                        result.error("BAD_ARGS", "path is required", null)
                        return@setMethodCallHandler
                    }

                    // Submit to thread pool – never block the main/platform thread
                    thumbExecutor.submit {
                        val bytes = extractThumbnail(path, timeUs, maxWidth, quality)
                        // Post result back to main thread for Flutter method channel
                        mainHandler.post {
                            if (bytes != null && bytes.isNotEmpty()) {
                                result.success(bytes)
                            } else {
                                result.error("THUMB_FAILED", "No frame extracted", null)
                            }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun extractThumbnail(
        path: String,
        requestedTimeUs: Long,
        maxWidth: Int,
        quality: Int
    ): ByteArray? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)

            // Get actual duration so we don't seek past the end
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
            val durationUs = durationMs * 1_000L

            // Pick seek position: 10 % of duration, capped at 30 s
            val seekUs = when {
                durationUs <= 0L          -> 0L
                durationUs < 2_000_000L   -> 0L                         // < 2 s  → first frame
                durationUs < 10_000_000L  -> durationUs / 5             // < 10 s → 20%
                else                      -> (durationUs / 10L)
                                                .coerceAtMost(30_000_000L)
            }

            // Try closest sync frame first (fast), then exact (slower)
            var bitmap: Bitmap? = retriever.getFrameAtTime(
                seekUs,
                MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            )
            if (bitmap == null) {
                bitmap = retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            }
            if (bitmap == null) return null

            // Scale to maxWidth keeping aspect ratio
            val scaled = if (bitmap.width > maxWidth) {
                val ratio = maxWidth.toFloat() / bitmap.width
                val h     = (bitmap.height * ratio).toInt().coerceAtLeast(1)
                Bitmap.createScaledBitmap(bitmap, maxWidth, h, true)
            } else {
                bitmap
            }

            ByteArrayOutputStream().use { out ->
                scaled.compress(Bitmap.CompressFormat.JPEG, quality, out)
                out.toByteArray()
            }
        } catch (e: Exception) {
            null
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        thumbExecutor.shutdownNow()
        super.onDestroy()
    }
}
