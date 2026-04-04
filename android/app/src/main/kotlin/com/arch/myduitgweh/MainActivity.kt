package com.arch.myduitgweh

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── EventChannel: Kirim notif real-time ke Flutter ──
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, NotifListenerService.EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    NotifListenerService.eventSink.set(sink)
                }
                override fun onCancel(arguments: Any?) {
                    NotifListenerService.eventSink.set(null)
                }
            })

        // ── MethodChannel: Kontrol ON/OFF & cek permission dari Flutter ──
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NotifListenerService.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        NotifListenerService.isEnabled = enabled
                        result.success(null)
                    }
                    "isAccessGranted" -> {
                        result.success(NotifListenerService.isNotificationAccessGranted(this))
                    }
                    "openSettings" -> {
                        NotifListenerService.openNotificationAccessSettings(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
