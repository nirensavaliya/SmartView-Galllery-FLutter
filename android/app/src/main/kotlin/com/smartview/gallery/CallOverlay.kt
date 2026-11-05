package com.smartview.gallery

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Size
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.util.concurrent.Executors

object CallOverlay {
    private const val PREFS = "smartview_call_settings"
    private const val ENABLED = "enabled"

    private var windowManager: WindowManager? = null
    private var card: LinearLayout? = null
    private var titleView: TextView? = null
    private var detailView: TextView? = null
    private var photosRow: LinearLayout? = null
    private val loader = Executors.newSingleThreadExecutor()

    fun isEnabled(context: Context): Boolean {
        return context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(ENABLED, false)
    }

    fun setEnabled(context: Context, enabled: Boolean) {
        context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(ENABLED, enabled)
            .apply()
        if (!enabled) {
            hide(context)
        }
    }

    fun show(context: Context, rawNumber: String?) {
        val appContext = context.applicationContext
        if (!isEnabled(appContext) || !Settings.canDrawOverlays(appContext)) {
            return
        }
        val number = rawNumber?.trim().orEmpty()
        val name = lookupName(appContext, number)
        val title = when {
            name.isNotEmpty() -> name
            number.isNotEmpty() -> "Unknown number"
            else -> "Incoming call"
        }
        val detail = when {
            name.isNotEmpty() && number.isNotEmpty() -> number
            number.isNotEmpty() -> "This number is not in your contacts"
            else -> "Android hid the caller number"
        }

        android.os.Handler(appContext.mainLooper).post {
            ensureCard(appContext)
            titleView?.text = title
            detailView?.text = detail
            photosRow?.removeAllViews()
        }
        loader.execute {
            val photos = latestPhotos(appContext)
            android.os.Handler(appContext.mainLooper).post {
                val row = photosRow ?: return@post
                row.removeAllViews()
                photos.forEach { bitmap ->
                    row.addView(photoView(appContext, bitmap))
                }
            }
        }
    }

    fun hide(context: Context) {
        val appContext = context.applicationContext
        android.os.Handler(appContext.mainLooper).post {
            val view = card ?: return@post
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {
            }
            card = null
            titleView = null
            detailView = null
            photosRow = null
            windowManager = null
        }
    }

    private fun ensureCard(context: Context) {
        if (card != null) {
            return
        }
        val manager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(context, 16), dp(context, 14), dp(context, 16), dp(context, 14))
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 18).toFloat()
                setColor(Color.parseColor("#151B26"))
            }
        }
        root.addView(label(context, "Incoming call", 12, Color.parseColor("#8FB4FF")))
        val title = label(context, "Incoming call", 18, Color.WHITE).apply {
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, dp(context, 4), 0, 0)
        }
        val detail = label(context, "", 13, Color.parseColor("#C5CEDB")).apply {
            setPadding(0, dp(context, 4), 0, 0)
        }
        val photos = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(context, 12), 0, 0)
        }
        root.addView(title)
        root.addView(detail)
        root.addView(photos)

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
            android.graphics.PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.TOP
        params.y = dp(context, 28)
        params.horizontalMargin = 0.04f
        try {
            manager.addView(root, params)
            windowManager = manager
            card = root
            titleView = title
            detailView = detail
            photosRow = photos
        } catch (_: Exception) {
            card = null
        }
    }

    private fun label(context: Context, text: String, size: Int, color: Int): TextView {
        return TextView(context).apply {
            this.text = text
            setTextColor(color)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, size.toFloat())
        }
    }

    private fun photoView(context: Context, bitmap: Bitmap): ImageView {
        return ImageView(context).apply {
            setImageBitmap(bitmap)
            scaleType = ImageView.ScaleType.CENTER_CROP
            val size = dp(context, 58)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                marginEnd = dp(context, 8)
            }
            background = GradientDrawable().apply {
                cornerRadius = dp(context, 10).toFloat()
                setColor(Color.parseColor("#243044"))
            }
            clipToOutline = true
            outlineProvider = android.view.ViewOutlineProvider.BACKGROUND
        }
    }

    private fun lookupName(context: Context, number: String): String {
        if (number.isEmpty()) {
            return ""
        }
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(number),
        )
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0).orEmpty() else ""
            } ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    private fun latestPhotos(context: Context): List<Bitmap> {
        val photos = mutableListOf<Bitmap>()
        val projection = arrayOf(MediaStore.Images.Media._ID)
        try {
            context.contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC",
            )?.use { cursor ->
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                while (cursor.moveToNext() && photos.size < 4) {
                    val id = cursor.getLong(idColumn)
                    val uri = Uri.withAppendedPath(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                        id.toString(),
                    )
                    val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        context.contentResolver.loadThumbnail(uri, Size(180, 180), null)
                    } else {
                        null
                    }
                    if (bitmap != null) {
                        photos.add(bitmap)
                    }
                }
            }
        } catch (_: Exception) {
        }
        return photos
    }

    private fun dp(context: Context, value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            context.resources.displayMetrics,
        ).toInt()
    }
}

class CallWatchService : Service() {
    private var telephony: TelephonyManager? = null
    private var receiverRegistered = false

    @Suppress("DEPRECATION")
    private val listener = object : PhoneStateListener() {
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            when (state) {
                TelephonyManager.CALL_STATE_RINGING ->
                    CallOverlay.show(this@CallWatchService, phoneNumber)
                TelephonyManager.CALL_STATE_IDLE -> CallOverlay.hide(this@CallWatchService)
            }
        }
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            when (state) {
                TelephonyManager.EXTRA_STATE_RINGING -> CallOverlay.show(context, number)
                TelephonyManager.EXTRA_STATE_IDLE -> CallOverlay.hide(context)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        startInForeground()
        telephony = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
        @Suppress("DEPRECATION")
        telephony?.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
        val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
        receiverRegistered = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        return START_STICKY
    }

    override fun onDestroy() {
        @Suppress("DEPRECATION")
        telephony?.listen(listener, PhoneStateListener.LISTEN_NONE)
        if (receiverRegistered) {
            unregisterReceiver(receiver)
            receiverRegistered = false
        }
        CallOverlay.hide(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground() {
        val channelId = "call_overlay"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                channelId,
                "Call info",
                NotificationManager.IMPORTANCE_MIN,
            )
            channel.setShowBadge(false)
            manager.createNotificationChannel(channel)
        }
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle("Call info is on")
                .setContentText("Incoming calls can show recent photos")
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Call info is on")
                .setContentText("Incoming calls can show recent photos")
                .setSmallIcon(android.R.drawable.sym_call_incoming)
                .build()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                41,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(41, notification)
        }
    }
}
