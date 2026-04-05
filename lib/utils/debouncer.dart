import 'dart:async';
import 'package:flutter/material.dart';

/// Throttle: Hanya izinkan satu panggilan dalam window waktu tertentu
/// Berguna untuk Pull-to-Refresh agar tidak memboroskan kuota READ Firestore.
class RefreshThrottle {
  final Duration cooldown;
  DateTime? _lastRefresh;

  RefreshThrottle({this.cooldown = const Duration(seconds: 5)});

  /// Mengecek apakah aksi boleh dilakukan sekarang
  bool get canRefresh {
    if (_lastRefresh == null) return true;
    return DateTime.now().difference(_lastRefresh!) >= cooldown;
  }

  /// Tandai bahwa refresh baru saja dilakukan
  void markRefreshed() => _lastRefresh = DateTime.now();
}

/// Debouncer: Tunda eksekusi sampai tidak ada panggilan baru dalam window tertentu.
/// Berguna untuk Search Bar agar tidak memanggil API tiap kali ngetik satu huruf.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
