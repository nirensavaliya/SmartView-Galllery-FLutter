package com.smartview.gallery

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.SparseIntArray
import java.nio.ByteBuffer
import androidx.media3.common.MediaItem
import androidx.media3.transformer.Composition
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

object VideoTrim {
    private var transformer: Transformer? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun start(
        context: Context,
        sourcePath: String,
        startMs: Long,
        endMs: Long,
        result: MethodChannel.Result,
    ) {
        if (endMs - startMs < 500) {
            result.error(
                "INVALID_RANGE",
                "Select at least half a second",
                null,
            )
            return
        }

        val source = File(sourcePath)
        if (!source.exists() || !source.isFile) {
            result.error("SOURCE_NOT_FOUND", "Video file not found", null)
            return
        }

        val output = File(context.cacheDir, "trim_${System.currentTimeMillis()}.mp4")
        if (output.exists()) {
            output.delete()
        }

        Thread {
            try {
                copyRange(source, output, startMs, endMs)
                if (!output.exists() || output.length() <= 0L) {
                    throw IllegalStateException("Trimmed file is empty")
                }
                mainHandler.post { result.success(output.absolutePath) }
            } catch (error: Exception) {
                android.util.Log.e("VideoTrim", "Copy trim failed", error)
                output.delete()
                mainHandler.post {
                    exportWithTransformer(context, source, output, startMs, endMs, result)
                }
            }
        }.start()
    }

    private fun copyRange(source: File, output: File, startMs: Long, endMs: Long) {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            extractor.setDataSource(source.absolutePath)
            val mux = MediaMuxer(output.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            muxer = mux
            val indexMap = SparseIntArray()
            var maxInput = 4 * 1024 * 1024
            var rotation = 0
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/") && !mime.startsWith("audio/")) continue
                extractor.selectTrack(index)
                if (mime.startsWith("video/") && format.containsKey(MediaFormat.KEY_ROTATION)) {
                    rotation = format.getInteger(MediaFormat.KEY_ROTATION)
                }
                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    maxInput = maxOf(maxInput, format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE))
                }
                indexMap.put(index, mux.addTrack(format))
            }
            if (indexMap.size() == 0) {
                throw IllegalStateException("No audio or video track")
            }
            mux.setOrientationHint(rotation)
            mux.start()

            val startUs = startMs * 1000L
            val endUs = endMs * 1000L
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            val buffer = ByteBuffer.allocate(maxInput)
            val info = MediaCodec.BufferInfo()
            var originUs = -1L
            while (true) {
                val track = extractor.sampleTrackIndex
                if (track < 0) break
                val sampleUs = extractor.sampleTime
                if (sampleUs < 0L || sampleUs > endUs) break
                buffer.clear()
                info.size = extractor.readSampleData(buffer, 0)
                if (info.size < 0) break
                buffer.position(0)
                buffer.limit(info.size)
                if (originUs < 0L) originUs = sampleUs
                info.offset = 0
                info.presentationTimeUs = (sampleUs - originUs).coerceAtLeast(0L)
                info.flags = extractor.sampleFlags
                val muxTrack = indexMap.get(track, -1)
                if (muxTrack >= 0) {
                    mux.writeSampleData(muxTrack, buffer, info)
                }
                extractor.advance()
            }
            mux.stop()
        } finally {
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
            extractor.release()
        }
    }

    private fun exportWithTransformer(
        context: Context,
        source: File,
        output: File,
        startMs: Long,
        endMs: Long,
        result: MethodChannel.Result,
    ) {
        if (output.exists()) output.delete()
        var replied = false
        fun reply(path: String?, error: String?) {
            if (replied) return
            replied = true
            if (path != null) {
                result.success(path)
            } else {
                output.delete()
                result.error("TRIM_FAILED", error ?: "Unable to trim video", null)
            }
        }

        val item = MediaItem.Builder()
            .setUri(Uri.fromFile(source))
            .setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(startMs)
                    .setEndPositionMs(endMs)
                    .build(),
            )
            .build()
        val created = Transformer.Builder(context).build()
        transformer?.cancel()
        transformer = created
        created.addListener(object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                reply(output.absolutePath, null)
            }

            override fun onError(
                composition: Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                reply(null, exportException.message)
            }
        })
        try {
            created.start(item, output.absolutePath)
        } catch (error: Exception) {
            reply(null, error.message)
        }
    }

    fun frames(
        context: Context,
        sourcePath: String,
        assetId: String?,
        count: Int,
    ): List<ByteArray> {
        val retriever = MediaMetadataRetriever()
        try {
            if (!openSource(retriever, context, sourcePath, assetId)) {
                return emptyList()
            }
            val durationMs = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull()
                ?: 0L
            val safeCount = count.coerceIn(6, 10)
            val frames = ArrayList<ByteArray>(safeCount)
            for (index in 0 until safeCount) {
                val timeUs = if (durationMs <= 0L) {
                    0L
                } else {
                    (durationMs * 1000L * (index + 1) / (safeCount + 1))
                }
                val bitmap = frameAt(retriever, timeUs) ?: continue
                frames.add(jpeg(bitmap))
                bitmap.recycle()
            }
            if (frames.isEmpty()) {
                val bitmap = retriever.getFrameAtTime(-1) ?: return emptyList()
                val bytes = jpeg(bitmap)
                bitmap.recycle()
                repeat(safeCount) { frames.add(bytes) }
            }
            return frames
        } catch (error: Exception) {
            android.util.Log.e("VideoTrim", "Frame read failed", error)
            return emptyList()
        } finally {
            retriever.release()
        }
    }

    private fun openSource(
        retriever: MediaMetadataRetriever,
        context: Context,
        sourcePath: String,
        assetId: String?,
    ): Boolean {
        val mediaId = assetId
            ?.substringAfterLast("/")
            ?.filter { it.isDigit() }
            ?.toLongOrNull()
        if (mediaId != null) {
            try {
                val uri = ContentUris.withAppendedId(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    mediaId,
                )
                retriever.setDataSource(context, uri)
                return true
            } catch (_: Exception) {
            }
        }
        return try {
            retriever.setDataSource(sourcePath)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun frameAt(retriever: MediaMetadataRetriever, timeUs: Long): Bitmap? {
        return retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            ?: retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
    }

    private fun jpeg(bitmap: Bitmap): ByteArray {
        val maxSide = 240
        val longest = maxOf(bitmap.width, bitmap.height).coerceAtLeast(1)
        val scale = maxSide.toFloat() / longest
        val width = (bitmap.width * scale).toInt().coerceAtLeast(1)
        val height = (bitmap.height * scale).toInt().coerceAtLeast(1)
        val scaled = if (width == bitmap.width && height == bitmap.height) {
            bitmap
        } else {
            Bitmap.createScaledBitmap(bitmap, width, height, true)
        }
        val stream = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, 72, stream)
        if (scaled != bitmap) scaled.recycle()
        return stream.toByteArray()
    }
}
