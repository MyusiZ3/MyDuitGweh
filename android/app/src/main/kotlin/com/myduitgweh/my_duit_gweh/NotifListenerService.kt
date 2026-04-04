package com.myduitgweh.my_duit_gweh

import android.content.ComponentName
import android.util.Log // Tambah log
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicReference

class NotifListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "NotifListenerSvc"
        // Channel names — harus sama persis dengan Flutter
        const val EVENT_CHANNEL = "com.myduitgweh/notif_stream"
        const val METHOD_CHANNEL = "com.myduitgweh/notif_control"

        // Daftar package yang diizinkan untuk dicapture
        private val TARGET_PACKAGES = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "com.instagram.android",
            "com.zhiliaoapp.musically",      // TikTok
            "com.twitter.android",
            "com.facebook.katana",
            "com.facebook.orca",              // Messenger
            "com.google.android.apps.messaging", // SMS Google
            "com.android.mms",               // SMS default
        )

        // Singleton EventSink untuk kirim data real-time ke Flutter
        val eventSink = AtomicReference<EventChannel.EventSink?>(null)

        var isEnabled = false

        // Cek apakah user sudah grant Notification Access
        fun isNotificationAccessGranted(context: Context): Boolean {
            val enabledListeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            ) ?: return false
            val packageName = context.packageName
            return enabledListeners.contains(packageName)
        }

        // Buka Notification Access Settings
        fun openNotificationAccessSettings(context: Context) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener Connected!")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || !isEnabled) return

        val packageName = sbn.packageName ?: return
        Log.d(TAG, "Received notification from: $packageName")

        // Hanya proses package dari daftar target
        if (!TARGET_PACKAGES.contains(packageName)) {
            Log.d(TAG, "Package $packageName not in target, skipping.")
            return
        }

        try {
            val extras = sbn.notification?.extras ?: return
            val title = extras.getCharSequence("android.title")?.toString() ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""

            // Skip jika title dan text kosong atau hanya notif kosong
            if (title.isBlank() && text.isBlank()) return

            val data = mapOf(
                "package" to packageName,
                "title" to title,
                "text" to text,
                "timestamp" to System.currentTimeMillis(),
                "id" to "${sbn.id}_${sbn.postTime}"
            )

            // Kirim ke Flutter via EventChannel (main thread)
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                eventSink.get()?.success(data)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Tidak perlu action saat notif dihapus
    }
}
