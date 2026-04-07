import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../utils/ui_helper.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;

  void startMonitoring() async {
    // Initial check
    final results = await _connectivity.checkConnectivity();
    _handleConnectivityChange(results);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Check if truly offline (no mobile, no wifi, no ethernet)
    final hasConnection = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );

    if (!hasConnection && !_isOffline) {
      _isOffline = true;
      UIHelper.showNoInternetOverlay();
    } else if (hasConnection && _isOffline) {
      _isOffline = false;
      UIHelper.hideNoInternetOverlay();
    }
  }

  void stopMonitoring() {
    _subscription?.cancel();
  }

  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi || 
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );
  }
}
