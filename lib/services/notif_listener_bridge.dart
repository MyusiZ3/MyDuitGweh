import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'notif_local_db_service.dart';
import 'notif_sync_service.dart';

/// Service untuk komunikasi Flutter ↔ Android Native via MethodChannel / EventChannel
class NotifListenerBridge {
  static const _methodChannel =
      MethodChannel('com.myduitgweh/notif_control');
  static const _eventChannel =
      EventChannel('com.myduitgweh/notif_stream');

  static const _prefKeyEnabled = 'notif_listener_enabled';

  static Stream<CapturedNotification>? _notifStream;

  // ─── Singleton-like stream ──────────────────────────────
  static Stream<CapturedNotification> get notificationStream {
    _notifStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((data) => data is Map)
        .map((data) {
      final map = Map<String, dynamic>.from(data as Map);
      debugPrint('🔔 Flutter: Received Notif from ${map['package']}');
      return CapturedNotification(
        id: map['id']?.toString() ??
            '${map['timestamp']}_${map['package']}',
        package_: map['package'] ?? '',
        title: map['title'] ?? '',
        text: map['text'] ?? '',
        timestamp: (map['timestamp'] as int?) ?? 0,
      );
    }).asyncMap((notif) async {
      // Langsung simpan ke SQLite saat terima
      await NotifLocalDbService.insertNotification(notif);
      return notif;
    });
    return _notifStream!;
  }

  // ─── Cek apakah Notification Access sudah di-grant ─────
  static Future<bool> isAccessGranted() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isAccessGranted') ??
          false;
    } catch (_) {
      return false;
    }
  }

  // ─── Buka Settings untuk grant Notification Access ─────
  static Future<void> openSettings() async {
    try {
      await _methodChannel.invokeMethod('openSettings');
    } catch (_) {}
  }

  // ─── Toggle ON/OFF listener di Android native ───────────
  static Future<void> setEnabled(bool enabled) async {
    try {
      await _methodChannel.invokeMethod('setEnabled', {'enabled': enabled});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyEnabled, enabled);
    } catch (e) {
      debugPrint('NotifBridge.setEnabled error: $e');
    }
  }

  // ─── Ambil status ON/OFF dari SharedPreferences ─────────
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? false;
  }

  // ─── Cek Status Global dari Firestore ──────────────────
  static Stream<bool> get globalConfigStream {
    return FirebaseFirestore.instance
        .collection('app_config')
        .doc('notification_listener')
        .snapshots()
        .map((snap) => snap.data()?['isEnabled'] ?? false);
  }

  // ─── Update Global Config (Hanya SuperAdmin) ────────────
  static Future<void> updateGlobalConfig(bool enabled, {int? syncInterval}) async {
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc('notification_listener')
        .set({
      'isEnabled': enabled,
      if (syncInterval != null) 'syncInterval': syncInterval,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Init saat app start — sesuaikan dengan status global ──
  static Future<void> initOnAppStart() async {
    // Listen status global
    globalConfigStream.listen((globalEnabled) async {
      if (globalEnabled) {
        final granted = await isAccessGranted();
        if (granted) {
          await setEnabled(true);
          // Mulai sync periodic jika belum
          final interval = await NotifSyncService.getSavedInterval();
          await NotifSyncService.scheduleSync(intervalMinutes: interval);
          
          // Mulai listen stream data
          notificationStream.listen((_) {});
        }
      } else {
        // Matikan total jika admin menonaktifkan fitur secara global
        await setEnabled(false);
        await NotifSyncService.cancelSync();
      }
    });
  }
}
