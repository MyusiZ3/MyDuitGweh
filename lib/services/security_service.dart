import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_device/safe_device.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/ui_helper.dart';

class SecurityService {
  final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricKey = 'use_biometrics';

  // --- NEW MONITORING LOGIC ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Log a security event
  Future<void> logEvent({
    required String type,
    required String severity, // 'low', 'medium', 'high', 'critical'
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('security_logs').add({
        'type': type,
        'severity': severity,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'uid': _firebaseAuth.currentUser?.uid ?? 'anonymous',
        'userEmail': _firebaseAuth.currentUser?.email ?? 'N/A',
        'metadata': metadata ?? {},
        'isRead': false,
      });
    } catch (e) {
      print('Error logging security event: $e');
    }
  }

  // Stream of unread logs count
  Stream<int> getUnreadCountStream() {
    return _firestore
        .collection('security_logs')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Stream of all logs (sorted by timestamp)
  Stream<QuerySnapshot> getAllLogsStream() {
    return _firestore
        .collection('security_logs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final unread = await _firestore
        .collection('security_logs')
        .where('isRead', isEqualTo: false)
        .get();
    
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Emergency: Global Maintenance Toggle
  Future<void> toggleGlobalMaintenance(bool enable) async {
    await _firestore.collection('app_config').doc('global').update({
      'isMaintenance': enable,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    await logEvent(
      type: 'EMERGENCY_ACTION',
      severity: 'critical',
      message: 'Maintenance mode ${enable ? 'ENABLED' : 'DISABLED'} by admin.',
    );
  }
  // --- END NEW MONITORING LOGIC ---

  Future<bool> isBiometricAvailable() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate =
        canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  Future<bool> authenticate(BuildContext context) async {
    try {
      if (!await isBiometricAvailable()) return true;

      // STEP 1: Tampilkan backdrop kustom (Center Aligned)
      UIHelper.showAuthDialog(context, 'Scan sidik jari atau wajah untuk membuka MyDuitGweh');

      // STEP 2: Langsung panggil native auth setelah backdrop muncul
      final bool result = await _auth.authenticate(
        localizedReason: 'Otentikasi Keamanan MyDuitGweh',
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Otentikasi Diperlukan',
            biometricHint: 'Sentuh sensor sidik jari',
            cancelButton: 'Gunakan PIN',
          ),
          IOSAuthMessages(
            cancelButton: 'Batal',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      // STEP 3: Tutup backdrop setelah selesai
      if (context.mounted) Navigator.pop(context);

      return result;
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, enabled);
  }

  /// Mengecek apakah device sudah di-root/jailbreak atau menggunakan emulator
  static Future<bool> isDeviceSafe() async {
    // Return true aja pas web/desktop
    if (kIsWeb) return true;

    try {
      final isJailBroken = await SafeDevice.isJailBroken;

      if (isJailBroken) {
        return false; // Bahaya karena root / jailbreak
      }

      return true;
    } catch (e) {
      // Fallback
      return true;
    }
  }
}
