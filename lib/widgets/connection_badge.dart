import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

enum ConnectionQuality { good, fair, poor, disconnected }

class ConnectionBadge extends StatefulWidget {
  final Widget child;
  const ConnectionBadge({super.key, required this.child});

  @override
  State<ConnectionBadge> createState() => _ConnectionBadgeState();
}

class _ConnectionBadgeState extends State<ConnectionBadge> {
  ConnectionQuality _quality = ConnectionQuality.good;
  Timer? _pingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initConnectionCheck();
  }

  void _initConnectionCheck() async {
    // Dengarkan perubahan koneksi
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        if (mounted) setState(() => _quality = ConnectionQuality.disconnected);
        _pingTimer?.cancel();
      } else {
        _checkPing();
        // Cek secara berkala tiap 10 detik
        _pingTimer?.cancel();
        _pingTimer =
            Timer.periodic(const Duration(seconds: 10), (_) => _checkPing());
      }
    });

    // Initial check
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      if (mounted) setState(() => _quality = ConnectionQuality.disconnected);
    } else {
      _checkPing();
      _pingTimer =
          Timer.periodic(const Duration(seconds: 10), (_) => _checkPing());
    }
  }

  Future<void> _checkPing() async {
    final startTime = DateTime.now();
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 3));
      final elapsedTimeMs = DateTime.now().difference(startTime).inMilliseconds;
      if (mounted) {
        setState(() {
          if (response.statusCode >= 200 && response.statusCode <= 299) {
            if (elapsedTimeMs < 400) {
              _quality = ConnectionQuality.good; // Ijo (Lancar)
            } else {
              _quality = ConnectionQuality.fair; // Kuning (Agak Lambat)
            }
          } else {
            _quality =
                ConnectionQuality.poor; // Merah (Koneksi jelek dari Server)
          }
        });
      }
    } catch (_) {
      // Timeout atau error
      if (mounted) {
        setState(
            () => _quality = ConnectionQuality.disconnected); // Merah/Putus
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  Color _getBadgeColor() {
    switch (_quality) {
      case ConnectionQuality.good:
        return Colors.greenAccent.shade400;
      case ConnectionQuality.fair:
        return Colors.amber.shade400;
      case ConnectionQuality.poor:
      case ConnectionQuality.disconnected:
        return Colors.redAccent.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          bottom: 2,
          right: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getBadgeColor(),
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).cardColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _getBadgeColor().withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
