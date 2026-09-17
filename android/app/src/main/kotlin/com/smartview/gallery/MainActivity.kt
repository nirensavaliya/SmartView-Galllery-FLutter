package com.smartview.gallery

import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "native_camera"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "openCamera" -> {
                    openDeviceCamera(result)
                }

                "copyMediaToAlbum" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val relativePath = call.argument<String>("relativePath")
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")

                    if (sourcePath == null ||
                        relativePath == null ||
                        fileName == null ||
                        mimeType == null
                    ) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Copy arguments missing",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    copyMediaToAlbum(
                        sourcePath = sourcePath,
                        relativePath = relativePath,
                        fileName = fileName,
                        mimeType = mimeType,
                        result = result
                    )
                }

                // ============================================================
                // RENAME MEDIA
                // ============================================================
                "renameMedia" -> {

                    val id = call.argument<String>("id")
                    val newName = call.argument<String>("newName")

                    if (id == null || newName == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Rename arguments missing",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    renameMedia(
                        assetId = id,
                        newName = newName,
                        result = result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openDeviceCamera(result: MethodChannel.Result) {

        try {

            val intent =
                Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)

            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            startActivity(intent)

            result.success(true)

        } catch (e: ActivityNotFoundException) {

            result.error(
                "CAMERA_NOT_FOUND",
                "Device camera app not found",
                null
            )

        } catch (e: Exception) {

            result.error(
                "CAMERA_ERROR",
                e.message ?: "Unable to open camera",
                null
            )
        }
    }

    private fun copyMediaToAlbum(
        sourcePath: String,
        relativePath: String,
        fileName: String,
        mimeType: String,
        result: MethodChannel.Result
    ) {

        try {

            val sourceFile = File(sourcePath)

            if (!sourceFile.exists()) {
                result.error(
                    "SOURCE_NOT_FOUND",
                    "Source file does not exist",
                    null
                )
                return
            }

            val resolver: ContentResolver = contentResolver

            val collection: Uri =
                if (mimeType.startsWith("video/")) {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                }

            val values = ContentValues().apply {

                put(
                    MediaStore.MediaColumns.DISPLAY_NAME,
                    fileName
                )

                put(
                    MediaStore.MediaColumns.MIME_TYPE,
                    mimeType
                )

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {

                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        relativePath
                    )

                    put(
                        MediaStore.MediaColumns.IS_PENDING,
                        1
                    )
                }
            }

            val uri = resolver.insert(
                collection,
                values
            )

            if (uri == null) {
                result.error(
                    "INSERT_FAILED",
                    "Unable to create destination media",
                    null
                )
                return
            }

            try {

                resolver.openOutputStream(uri).use { outputStream ->

                    if (outputStream == null) {
                        throw Exception(
                            "Unable to open destination stream"
                        )
                    }

                    FileInputStream(sourceFile).use { inputStream ->

                        val buffer = ByteArray(1024 * 1024)

                        var length: Int

                        while (
                            inputStream.read(buffer).also {
                                length = it
                            } != -1
                        ) {
                            outputStream.write(
                                buffer,
                                0,
                                length
                            )
                        }

                        outputStream.flush()
                    }
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {

                    val pendingValues = ContentValues().apply {
                        put(
                            MediaStore.MediaColumns.IS_PENDING,
                            0
                        )
                    }

                    resolver.update(
                        uri,
                        pendingValues,
                        null,
                        null
                    )
                }

                result.success(
                    uri.toString()
                )

            } catch (e: Exception) {

                resolver.delete(
                    uri,
                    null,
                    null
                )

                throw e
            }

        } catch (e: Exception) {

            result.error(
                "COPY_FAILED",
                e.message ?: "Unable to copy media",
                null
            )
        }
    }

    // ============================================================
    // RENAME MEDIA
    // ============================================================
    private fun renameMedia(
        assetId: String,
        newName: String,
        result: MethodChannel.Result
    ) {

        try {

            val resolver = contentResolver

            val uri = findMediaUri(assetId)

            if (uri == null) {
                result.error(
                    "MEDIA_NOT_FOUND",
                    "Media not found",
                    null
                )
                return
            }

            val values = ContentValues().apply {
                put(
                    MediaStore.MediaColumns.DISPLAY_NAME,
                    newName
                )
            }

            val updatedRows = resolver.update(
                uri,
                values,
                null,
                null
            )

            if (updatedRows > 0) {

                result.success(true)

            } else {

                result.error(
                    "RENAME_FAILED",
                    "Unable to rename media",
                    null
                )
            }

        } catch (e: SecurityException) {

            result.error(
                "RENAME_PERMISSION",
                "Permission denied while renaming media",
                e.message
            )

        } catch (e: Exception) {

            result.error(
                "RENAME_FAILED",
                e.message ?: "Unable to rename media",
                null
            )
        }
    }

    // ============================================================
    // FIND MEDIA URI
    // ============================================================
    private fun findMediaUri(assetId: String): Uri? {

        val resolver = contentResolver

        // photo_manager Android asset IDs normally contain the
        // MediaStore ID. We try to extract the numeric ID.
        val numericId = assetId
            .substringAfterLast("/")
            .filter { it.isDigit() }

        if (numericId.isEmpty()) {
            return null
        }

        val mediaId = numericId.toLongOrNull()
            ?: return null

        val imageUri =
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI

        resolver.query(
            imageUri,
            arrayOf(MediaStore.Images.Media._ID),
            "${MediaStore.Images.Media._ID}=?",
            arrayOf(mediaId.toString()),
            null
        )?.use { cursor ->

            if (cursor.moveToFirst()) {
                return Uri.withAppendedPath(
                    imageUri,
                    mediaId.toString()
                )
            }
        }

        val videoUri =
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI

        resolver.query(
            videoUri,
            arrayOf(MediaStore.Video.Media._ID),
            "${MediaStore.Video.Media._ID}=?",
            arrayOf(mediaId.toString()),
            null
        )?.use { cursor ->

            if (cursor.moveToFirst()) {
                return Uri.withAppendedPath(
                    videoUri,
                    mediaId.toString()
                )
            }
        }

        return null
    }
}