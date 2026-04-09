import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notif_listener_bridge.dart';
import '../utils/app_theme.dart';

class NotificationPermissionSliver extends StatefulWidget {
  const NotificationPermissionSliver({super.key});

  @override
  State<NotificationPermissionSliver> createState() => _NotificationPermissionSliverState();
}

class _NotificationPermissionSliverState extends State<NotificationPermissionSliver> {
  bool _isGranted = true; // Default true so it doesn't blink
  bool _globalEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final granted = await NotifListenerBridge.isAccessGranted();
    if (mounted) {
      setState(() => _isGranted = granted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NotifListenerBridge.globalConfigStream,
      builder: (context, snapshot) {
        _globalEnabled = snapshot.data ?? false;

        // Tampilkan hanya jika Global ON tapi Izin OFF
        if (!_globalEnabled || _isGranted) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.9),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pencatatan Transaksi Otomatis',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Aktifkan akses notifikasi agar MyDuitGweh bisa mencatat pengeluaranmu otomatis dari WhatsApp & SMS.',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await NotifListenerBridge.openSettings();
                      // Re-check after returning from settings
                      Future.delayed(const Duration(seconds: 2), _checkStatus);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Aktifkan Sekarang',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
