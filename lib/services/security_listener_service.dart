import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'package:flutter/material.dart';
import '../utils/ui_helper.dart';

class SecurityListenerService {
  static final SecurityListenerService _instance = SecurityListenerService._internal();
  factory SecurityListenerService() => _instance;
  SecurityListenerService._internal();

  StreamSubscription? _subscription;
  DateTime _lastNotifiedTime = DateTime.now();
  static const String _prefKey = 'last_security_notif_time';

  void startListening(String adminUid) async {
    if (_subscription != null) return;
    
    // Load last notification time from preferences
    final prefs = await SharedPreferences.getInstance();
    final lastTimeMillis = prefs.getInt(_prefKey);
    if (lastTimeMillis != null) {
      _lastNotifiedTime = DateTime.fromMillisecondsSinceEpoch(lastTimeMillis);
    } else {
      // First time? Set to now
      _lastNotifiedTime = DateTime.now();
      await prefs.setInt(_prefKey, _lastNotifiedTime.millisecondsSinceEpoch);
    }

    debugPrint('--- SECURITY LISTENER: Started for Admin $adminUid ---');

    // Subscribe ke log keamanan terbaru yang belum dibaca
    _subscription = FirebaseFirestore.instance
        .collection('security_logs')
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(1) // Ambil yang paling baru saja untuk trigger
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final timestamp = data['timestamp'] as Timestamp?;
          
          debugPrint('--- SECURITY LISTENER: Detected Change: ${change.type}, Data: $data');
          
          if (timestamp == null) {
            debugPrint('--- SECURITY LISTENER: Timestamp is NULL');
            continue;
          }

          final severity = data['severity'] ?? 'low';
          final type = data['type'] ?? 'UNKNOWN';
          final message = data['message'] ?? '';

          final isRecent = timestamp.toDate().isAfter(_lastNotifiedTime.subtract(const Duration(seconds: 5)));
          final isSevere = (severity == 'high' || severity == 'critical' || severity == 'medium');

          debugPrint('--- SECURITY LISTENER CHECK: isRecent=$isRecent, isSevere=$isSevere, severity=$severity, time=${timestamp.toDate()}, lastNotified=$_lastNotifiedTime');

          if (isRecent && isSevere) {
            _lastNotifiedTime = timestamp.toDate();
            _triggerPopup(type, message, severity);
            
            // Persist the last notification time
            SharedPreferences.getInstance().then((prefs) {
              prefs.setInt(_prefKey, _lastNotifiedTime.millisecondsSinceEpoch);
            });
          }
        }
      }
    }, onError: (e) {
      debugPrint('--- SECURITY LISTENER ERROR: $e ---');
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    debugPrint('--- SECURITY LISTENER: Stopped ---');
  }

  void _triggerPopup(String type, String message, String severity) {
    String emoji = severity == 'critical' ? '🚨' : '⚠️';
    Color color = (severity == 'critical' || severity == 'high') 
      ? const Color(0xFFF43F5E) // Red
      : Colors.orange;

    // 1. Show stylized in-app toast (Snackbar-like)
    UIHelper.showGlobalInfoToast(
      '$emoji SECURITY ALERT: $type\n$message',
      color: color,
      icon: severity == 'critical' ? Icons.security_rounded : Icons.warning_amber_rounded,
    );

    // 2. Also keep system notification for when app is in background
    NotificationService().showInstant(
      id: DateTime.now().millisecond,
      title: '$emoji SECURITY ALERT: $type',
      body: message,
    );
  }
}
