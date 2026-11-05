package com.smartview.gallery

import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.app.Activity
import android.content.IntentSender
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterFragmentActivity

import android.provider.Settings

import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "native_camera"

    private val MOVE_WRITE_REQUEST_CODE = 9001

    private var pendingMoveUri: Uri? = null
    private var pendingMovePath: String? = null
    private var pendingMoveResult: MethodChannel.Result? = null
    private var waitingForMediaManagement = false
    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "openCamera" -> {
                    openDeviceCamera(result)
                }

                "trim" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val startMs = call.argument<Number>("startMs")?.toLong()
                    val endMs = call.argument<Number>("endMs")?.toLong()
                    if (sourcePath == null || startMs == null || endMs == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Trim arguments missing",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    VideoTrim.start(
                        context = this,
                        sourcePath = sourcePath,
                        startMs = startMs,
                        endMs = endMs,
                        result = result
                    )
                }

                "trimFrames" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val assetId = call.argument<String>("assetId")
                    val count = call.argument<Int>("count") ?: 8
                    if (sourcePath == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Trim arguments missing",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val frames = VideoTrim.frames(this, sourcePath, assetId, count)
                            runOnUiThread { result.success(frames) }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "FRAMES_FAILED",
                                    error.message ?: "Unable to read video frames",
                                    null
                                )
                            }
                        }
                    }.start()
                }

                "copyMediaToAlbum" -> {

                    val sourcePath =
                        call.argument<String>("sourcePath")

                    val relativePath =
                        call.argument<String>("relativePath")

                    val fileName =
                        call.argument<String>("fileName")

                    val mimeType =
                        call.argument<String>("mimeType")

                    if (
                        sourcePath == null ||
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


                "renameMedia" -> {

                    val id =
                        call.argument<String>("id")

                    val newName =
                        call.argument<String>("newName")

                    if (
                        id == null ||
                        newName == null
                    ) {
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
                "requestMediaManagement" -> {
                    requestMediaManagement(result)
                }
                "moveMediaToAlbum" -> {
                    val assetId = call.argument<String>("assetId")
                    val relativePath = call.argument<String>("relativePath")
                    val isVideo = call.argument<Boolean>("isVideo") ?: false

                    if (assetId == null || relativePath == null) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "assetId or relativePath is missing",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    moveMediaToAlbum(
                        assetId = assetId,
                        relativePath = relativePath,
                        isVideo = isVideo,
                        result = result
                    )
                }

                "openBiometricSettings" -> {
                    try {

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {

                            val intent = Intent(
                                Settings.ACTION_BIOMETRIC_ENROLL
                            )

                            startActivity(intent)

                        } else if (
                            Build.VERSION.SDK_INT >=
                            Build.VERSION_CODES.P
                        ) {

                            val intent = Intent(
                                Settings.ACTION_FINGERPRINT_ENROLL
                            )

                            startActivity(intent)

                        } else {

                            val intent = Intent(
                                Settings.ACTION_SECURITY_SETTINGS
                            )

                            startActivity(intent)
                        }

                        result.success(true)

                    } catch (e: Exception) {

                        try {

                            val fallbackIntent = Intent(
                                Settings.ACTION_SECURITY_SETTINGS
                            )

                            startActivity(fallbackIntent)

                            result.success(true)

                        } catch (ex: Exception) {

                            result.error(
                                "SETTINGS_ERROR",
                                ex.message,
                                null
                            )
                        }
                    }
                }

                "callOverlayStatus" -> {
                    val phoneGranted = androidx.core.content.ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.READ_PHONE_STATE,
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    val callLogGranted = androidx.core.content.ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.READ_CALL_LOG,
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    val contactsGranted = androidx.core.content.ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.READ_CONTACTS,
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    result.success(
                        mapOf(
                            "phone" to phoneGranted,
                            "callLog" to callLogGranted,
                            "contacts" to contactsGranted,
                            "overlay" to Settings.canDrawOverlays(this),
                            "enabled" to CallOverlay.isEnabled(this),
                        ),
                    )
                }

                "setCallOverlayEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    CallOverlay.setEnabled(this, enabled)
                    val service = Intent(this, CallWatchService::class.java)
                    if (enabled) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(service)
                        } else {
                            startService(service)
                        }
                    } else {
                        stopService(service)
                    }
                    result.success(true)
                }

                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName"),
                    )
                    startActivity(intent)
                    result.success(true)
                }

                "requestCallLog" -> {
                    androidx.core.app.ActivityCompat.requestPermissions(
                        this,
                        arrayOf(android.Manifest.permission.READ_CALL_LOG),
                        41021,
                    )
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openDeviceCamera(
        result: MethodChannel.Result
    ) {

        try {

            val intent =
                Intent(
                    MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA
                )

            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
            )

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
    private fun requestMediaManagement(
        result: MethodChannel.Result
    ) {
        try {

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                result.success(true)
                return
            }

            if (MediaStore.canManageMedia(this)) {
                result.success(true)
                return
            }

            val intent = Intent(
                Settings.ACTION_REQUEST_MANAGE_MEDIA,
                Uri.parse("package:$packageName")
            )

            startActivity(intent)

            result.success(false)

        } catch (e: Exception) {

            result.error(
                "MEDIA_MANAGEMENT_ERROR",
                e.message ?: "Unable to open media management settings",
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

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {

            result.error(
                "UNSUPPORTED_ANDROID",
                "Native MediaStore copy requires Android 10+",
                null
            )

            return
        }

        val sourceFile = File(sourcePath)

        if (!sourceFile.exists() ||
            !sourceFile.isFile
        ) {

            result.error(
                "SOURCE_NOT_FOUND",
                "Source file does not exist",
                null
            )

            return
        }

        val resolver = contentResolver

        var destinationUri: Uri? = null

        try {

            val cleanRelativePath =
                relativePath
                    .trim()
                    .replace("\\", "/")
                    .let {
                        if (it.endsWith("/")) {
                            it
                        } else {
                            "$it/"
                        }
                    }

            val isDownload =
                cleanRelativePath
                    .equals(
                        "Download/",
                        ignoreCase = true
                    ) ||
                        cleanRelativePath
                            .startsWith(
                                "Download/",
                                ignoreCase = true
                            )

            val isVideo =
                mimeType.startsWith(
                    "video/",
                    ignoreCase = true
                )


            val collectionUri: Uri

            if (isDownload) {
                collectionUri =
                    MediaStore.Downloads.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY
                    )

            } else if (isVideo) {

                collectionUri =
                    MediaStore.Video.Media.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY
                    )

            } else {


                collectionUri =
                    MediaStore.Images.Media.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY
                    )
            }


            val values =
                ContentValues().apply {

                    put(
                        MediaStore.MediaColumns.DISPLAY_NAME,
                        fileName
                    )

                    put(
                        MediaStore.MediaColumns.MIME_TYPE,
                        mimeType
                    )

                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        cleanRelativePath
                    )

                    put(
                        MediaStore.MediaColumns.IS_PENDING,
                        1
                    )
                }


            destinationUri =
                resolver.insert(
                    collectionUri,
                    values
                )

            if (destinationUri == null) {

                result.error(
                    "MEDIASTORE_INSERT_FAILED",
                    "Unable to create destination media",
                    null
                )

                return
            }

            FileInputStream(sourceFile).use { input ->

                resolver.openOutputStream(
                    destinationUri
                ).use { output ->

                    if (output == null) {

                        throw Exception(
                            "Unable to open destination output stream"
                        )
                    }

                    val buffer =
                        ByteArray(1024 * 1024)

                    var length: Int

                    while (
                        input.read(buffer).also {
                            length = it
                        } > 0
                    ) {

                        output.write(
                            buffer,
                            0,
                            length
                        )
                    }

                    output.flush()
                }
            }

            val publishValues =
                ContentValues().apply {
                    put(
                        MediaStore.MediaColumns.IS_PENDING,
                        0
                    )
                }

            val updated =
                resolver.update(
                    destinationUri,
                    publishValues,
                    null,
                    null
                )

            if (updated <= 0) {

                // Cleanup if publish failed.
                try {
                    resolver.delete(
                        destinationUri,
                        null,
                        null
                    )
                } catch (_: Exception) {
                }

                result.error(
                    "MEDIASTORE_PUBLISH_FAILED",
                    "Unable to publish copied media",
                    null
                )

                return
            }

            // ========================================================
            // RETURN MEDIASTORE ID
            // ========================================================

            val mediaId =
                destinationUri
                    .lastPathSegment

            if (
                mediaId == null ||
                mediaId.isEmpty()
            ) {

                result.error(
                    "MEDIASTORE_ID_FAILED",
                    "Copied media ID could not be determined",
                    null
                )

                return
            }

            android.util.Log.d(
                "GalleryCopy",
                "COPY SUCCESS"
            )

            android.util.Log.d(
                "GalleryCopy",
                "Source      : $sourcePath"
            )

            android.util.Log.d(
                "GalleryCopy",
                "File        : $fileName"
            )

            android.util.Log.d(
                "GalleryCopy",
                "Mime        : $mimeType"
            )

            android.util.Log.d(
                "GalleryCopy",
                "Relative    : $cleanRelativePath"
            )

            android.util.Log.d(
                "GalleryCopy",
                "Destination : $destinationUri"
            )

            android.util.Log.d(
                "GalleryCopy",
                "Media ID    : $mediaId"
            )

            // IMPORTANT:
            // Dart _copyAssetCrossPlatform() expects the newly
            // created asset ID.
            result.success(mediaId)

        } catch (e: SecurityException) {

            if (destinationUri != null) {
                try {
                    resolver.delete(
                        destinationUri,
                        null,
                        null
                    )
                } catch (_: Exception) {
                }
            }

            result.error(
                "MEDIASTORE_PERMISSION",
                "Permission denied while copying media",
                e.message
            )

        } catch (e: Exception) {

            if (destinationUri != null) {
                try {
                    resolver.delete(
                        destinationUri,
                        null,
                        null
                    )
                } catch (_: Exception) {
                }
            }

            result.error(
                "COPY_FAILED",
                e.message ?: "Unable to copy media",
                null
            )
        }
    }
    private fun moveMediaToAlbum(
        assetId: String,
        relativePath: String,
        isVideo: Boolean,
        result: MethodChannel.Result
    ) {
        try {

            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                result.error(
                    "UNSUPPORTED",
                    "Direct MediaStore move requires Android 10+",
                    null
                )
                return
            }

            val mediaId = assetId
                .substringAfterLast("/")
                .toLongOrNull()

            if (mediaId == null) {
                result.error(
                    "INVALID_ID",
                    "Invalid MediaStore asset ID: $assetId",
                    null
                )
                return
            }

            val resolver = contentResolver

            val collectionUri =
                if (isVideo) {
                    MediaStore.Video.Media.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY
                    )
                } else {
                    MediaStore.Images.Media.getContentUri(
                        MediaStore.VOLUME_EXTERNAL_PRIMARY
                    )
                }

            val mediaUri = ContentUris.withAppendedId(
                collectionUri,
                mediaId
            )

            val cleanPath =
                if (relativePath.trim().endsWith("/")) {
                    relativePath.trim()
                } else {
                    "${relativePath.trim()}/"
                }

            android.util.Log.d(
                "MOVE_MEDIA",
                "========================================"
            )

            android.util.Log.d(
                "MOVE_MEDIA",
                "MOVE START"
            )

            android.util.Log.d(
                "MOVE_MEDIA",
                "Media URI = $mediaUri"
            )

            android.util.Log.d(
                "MOVE_MEDIA",
                "Destination = $cleanPath"
            )

            android.util.Log.d(
                "MOVE_MEDIA",
                "Android API = ${Build.VERSION.SDK_INT}"
            )
            // ============================================================
// ANDROID 12+
// ============================================================

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {

                // --------------------------------------------------------
                // 1. Check Media Management special access
                // --------------------------------------------------------
                if (!MediaStore.canManageMedia(this)) {

                    android.util.Log.d(
                        "MOVE_MEDIA",
                        "MEDIA MANAGEMENT ACCESS NOT GRANTED"
                    )

                    // Save pending operation
                    pendingMoveUri = mediaUri
                    pendingMovePath = cleanPath
                    pendingMoveResult = result

                    waitingForMediaManagement = true

                    val intent = Intent(
                        Settings.ACTION_REQUEST_MANAGE_MEDIA,
                        Uri.parse("package:$packageName")
                    )

                    startActivity(intent)

                    // IMPORTANT:
                    // Do NOT call result.error() here.
                    // We will continue after returning from Settings.

                    return
                }

                // --------------------------------------------------------
                // 2. Media Management access is granted
                // --------------------------------------------------------

                android.util.Log.d(
                    "MOVE_MEDIA",
                    "MEDIA MANAGEMENT ACCESS GRANTED"
                )

                try {

                    /*
                     * IMPORTANT:
                     *
                     * Even with MANAGE_MEDIA, use createWriteRequest().
                     *
                     * Because MANAGE_MEDIA allows this request to proceed
                     * without showing the "Allow Gallery Photos to modify
                     * this photo?" confirmation dialog.
                     */

                    val writeRequest = MediaStore.createWriteRequest(
                        contentResolver,
                        listOf(mediaUri)
                    )

                    pendingMoveUri = mediaUri
                    pendingMovePath = cleanPath
                    pendingMoveResult = result

                    android.util.Log.d(
                        "MOVE_MEDIA",
                        "Starting write request"
                    )

                    startIntentSenderForResult(
                        writeRequest.intentSender,
                        MOVE_WRITE_REQUEST_CODE,
                        null,
                        0,
                        0,
                        0
                    )

                    return

                } catch (e: Exception) {

                    android.util.Log.e(
                        "MOVE_MEDIA",
                        "Android 12+ write request failed",
                        e
                    )

                    result.error(
                        "WRITE_REQUEST_FAILED",
                        e.message ?: "Unable to request media write access",
                        null
                    )

                    return
                }
            }

            if (Build.VERSION.SDK_INT == Build.VERSION_CODES.R) {

                android.util.Log.d(
                    "MOVE_MEDIA",
                    "ANDROID 11 - Creating MediaStore write request"
                )

                try {

                    val writeRequest = MediaStore.createWriteRequest(
                        resolver,
                        listOf(mediaUri)
                    )

                    pendingMoveUri = mediaUri
                    pendingMovePath = cleanPath
                    pendingMoveResult = result

                    startIntentSenderForResult(
                        writeRequest.intentSender,
                        MOVE_WRITE_REQUEST_CODE,
                        null,
                        0,
                        0,
                        0
                    )

                    return

                } catch (e: Exception) {

                    android.util.Log.e(
                        "MOVE_MEDIA",
                        "Write request failed",
                        e
                    )

                    result.error(
                        "WRITE_REQUEST_FAILED",
                        e.message ?: "Unable to request write access",
                        null
                    )

                    return
                }
            }

            // ============================================================
            // ANDROID 10 / API 29
            // ============================================================

            performMediaStoreMove(
                mediaUri = mediaUri,
                cleanPath = cleanPath,
                result = result
            )

        } catch (e: SecurityException) {

            android.util.Log.e(
                "MOVE_MEDIA",
                "SecurityException",
                e
            )

            result.error(
                "SECURITY_ERROR",
                e.message ?: "Media permission denied",
                null
            )

        } catch (e: Exception) {

            android.util.Log.e(
                "MOVE_MEDIA",
                "Move failed",
                e
            )

            result.error(
                "MOVE_ERROR",
                e.message ?: "Unable to move media",
                null
            )
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (CallOverlay.isEnabled(this)) {
            val service = Intent(this, CallWatchService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(service)
            } else {
                startService(service)
            }
        }
    }
    override fun onResume() {
        super.onResume()

        if (!waitingForMediaManagement) {
            return
        }

        waitingForMediaManagement = false

        val uri = pendingMoveUri
        val path = pendingMovePath
        val result = pendingMoveResult

        if (uri == null || path == null || result == null) {
            pendingMoveUri = null
            pendingMovePath = null
            pendingMoveResult = null
            return
        }

        // Clear pending values
        pendingMoveUri = null
        pendingMovePath = null
        pendingMoveResult = null

        // Check again after returning from Settings
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {

            if (!MediaStore.canManageMedia(this)) {

                android.util.Log.d(
                    "MOVE_MEDIA",
                    "MEDIA MANAGEMENT ACCESS STILL NOT GRANTED"
                )

                result.error(
                    "MEDIA_MANAGEMENT_DENIED",
                    "Media management permission was not granted.",
                    null
                )

                return
            }
        }

        android.util.Log.d(
            "MOVE_MEDIA",
            "MEDIA MANAGEMENT ACCESS GRANTED AFTER SETTINGS"
        )

        // Now request write access
        try {

            val writeRequest = MediaStore.createWriteRequest(
                contentResolver,
                listOf(uri)
            )

            pendingMoveUri = uri
            pendingMovePath = path
            pendingMoveResult = result

            startIntentSenderForResult(
                writeRequest.intentSender,
                MOVE_WRITE_REQUEST_CODE,
                null,
                0,
                0,
                0
            )

        } catch (e: Exception) {

            android.util.Log.e(
                "MOVE_MEDIA",
                "Write request after settings failed",
                e
            )

            result.error(
                "WRITE_REQUEST_FAILED",
                e.message ?: "Unable to request media write access",
                null
            )
        }
    }
    private fun performMediaStoreMove(
        mediaUri: Uri,
        cleanPath: String,
        result: MethodChannel.Result
    ) {
        try {

            val values = ContentValues().apply {
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    cleanPath
                )
            }

            android.util.Log.d(
                "MOVE_MEDIA",
                "Updating RELATIVE_PATH..."
            )

            val updatedRows = contentResolver.update(
                mediaUri,
                values,
                null,
                null
            )

            if (updatedRows > 0) {

                android.util.Log.d(
                    "MOVE_MEDIA",
                    "MOVE SUCCESS"
                )

                android.util.Log.d(
                    "MOVE_MEDIA",
                    "$mediaUri -> $cleanPath"
                )

                result.success(
                    mediaUri.lastPathSegment
                )

            } else {

                result.error(
                    "MOVE_FAILED",
                    "MediaStore update returned 0 rows",
                    null
                )
            }

        } catch (e: SecurityException) {

            android.util.Log.e(
                "MOVE_MEDIA",
                "Move update SecurityException",
                e
            )

            result.error(
                "SECURITY_ERROR",
                e.message ?: "Permission denied while moving media",
                null
            )

        } catch (e: Exception) {

            android.util.Log.e(
                "MOVE_MEDIA",
                "Move update failed",
                e
            )

            result.error(
                "MOVE_ERROR",
                e.message ?: "Unable to move media",
                null
            )
        }
    }
    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {
        super.onActivityResult(
            requestCode,
            resultCode,
            data
        )

        if (requestCode != MOVE_WRITE_REQUEST_CODE) {
            return
        }

        val uri = pendingMoveUri
        val path = pendingMovePath
        val result = pendingMoveResult

        pendingMoveUri = null
        pendingMovePath = null
        pendingMoveResult = null

        if (uri == null || path == null || result == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {

            android.util.Log.d(
                "MOVE_MEDIA",
                "WRITE ACCESS DENIED"
            )

            result.error(
                "WRITE_PERMISSION_DENIED",
                "User denied media write permission",
                null
            )

            return
        }

        android.util.Log.d(
            "MOVE_MEDIA",
            "WRITE ACCESS GRANTED"
        )

        performMediaStoreMove(
            mediaUri = uri,
            cleanPath = path,
            result = result
        )
    }
    private fun renameMedia(
        assetId: String,
        newName: String,
        result: MethodChannel.Result
    ) {

        try {

            val resolver = contentResolver

            val uri =
                findMediaUri(assetId)

            if (uri == null) {

                result.error(
                    "MEDIA_NOT_FOUND",
                    "Media not found",
                    null
                )

                return
            }

            val values =
                ContentValues().apply {

                    put(
                        MediaStore.MediaColumns.DISPLAY_NAME,
                        newName
                    )
                }

            val updatedRows =
                resolver.update(
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
                e.message
                    ?: "Unable to rename media",
                null
            )
        }
    }

    private fun findMediaUri(
        assetId: String
    ): Uri? {

        val resolver = contentResolver

        val numericId =
            assetId
                .substringAfterLast("/")
                .filter {
                    it.isDigit()
                }

        if (numericId.isEmpty()) {
            return null
        }

        val mediaId =
            numericId.toLongOrNull()
                ?: return null


        val imageUri =
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI

        resolver.query(
            imageUri,
            arrayOf(
                MediaStore.Images.Media._ID
            ),
            "${MediaStore.Images.Media._ID}=?",
            arrayOf(
                mediaId.toString()
            ),
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
            arrayOf(
                MediaStore.Video.Media._ID
            ),
            "${MediaStore.Video.Media._ID}=?",
            arrayOf(
                mediaId.toString()
            ),
            null
        )?.use { cursor ->

            if (cursor.moveToFirst()) {

                return Uri.withAppendedPath(
                    videoUri,
                    mediaId.toString()
                )
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {

            val downloadsUri =
                MediaStore.Downloads.getContentUri(
                    MediaStore.VOLUME_EXTERNAL_PRIMARY
                )

            resolver.query(
                downloadsUri,
                arrayOf(
                    MediaStore.Downloads._ID
                ),
                "${MediaStore.Downloads._ID}=?",
                arrayOf(
                    mediaId.toString()
                ),
                null
            )?.use { cursor ->

                if (cursor.moveToFirst()) {

                    return Uri.withAppendedPath(
                        downloadsUri,
                        mediaId.toString()
                    )
                }
            }
        }

        return null
    }
}