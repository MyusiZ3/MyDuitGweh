import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notif_listener_bridge.dart';
import '../utils/app_theme.dart';

class NotificationPermissionFloatingCard extends StatefulWidget {
  const NotificationPermissionFloatingCard({super.key});

  @override
  State<NotificationPermissionFloatingCard> createState() =>
      _NotificationPermissionFloatingCardState();
}

class _NotificationPermissionFloatingCardState
    extends State<NotificationPermissionFloatingCard>
    with SingleTickerProviderStateMixin {
  bool _isGranted = true;
  bool _globalEnabled = false;
  bool _isDismissed = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('notif_banner_dismissed') ?? false;
    final granted = await NotifListenerBridge.isAccessGranted();

    if (mounted) {
      setState(() {
        _isGranted = granted;
        _isDismissed = dismissed;
      });
      if (!granted && !dismissed) {
        _animController.forward();
      }
    }
  }

  Future<void> _dismiss() async {
    await _animController.reverse();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_banner_dismissed', true);
    if (mounted) setState(() => _isDismissed = true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NotifListenerBridge.globalConfigStream,
      builder: (context, snapshot) {
        _globalEnabled = snapshot.data ?? false;

        if (!_globalEnabled || _isGranted || _isDismissed) {
          return const SizedBox.shrink();
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // 1. Heavy Backdrop Blur
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: AppColors.primary.withOpacity(0.12)),
                ),
              ),
              
              // 2. Compact Centered Vibrant Blue Card
              Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.86,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withBlue(255).withGreen(120),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Row for Icon and Text
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Auto-Magic Sync!',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          color: Colors.white,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.8),
                                        ),
                                        child: Text(
                                          'EXPERIMENTAL',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 7.5,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Biar MyDuit catat biaya pengeluaran & SMS secara otomatis.',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.85),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Action Buttons
                        ElevatedButton(
                          onPressed: () async {
                            await NotifListenerBridge.openSettings();
                            Future.delayed(
                                const Duration(seconds: 3), _checkStatus);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            'Aktifkan Sekarang',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _dismiss,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.7),
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          child: Text(
                            'Nanti Saja',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
