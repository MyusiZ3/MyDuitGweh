import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../connection_badge.dart';
import '../../utils/tone_dictionary.dart';

class HomeSliverAppBar extends StatelessWidget {
  final User? user;
  final String? greeting;
  final bool isAdmin;
  final bool isSuperAdmin;
  final int unreadBroadcasts;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final String uid;

  const HomeSliverAppBar({
    super.key,
    required this.user,
    this.greeting,
    required this.isAdmin,
    required this.isSuperAdmin,
    required this.unreadBroadcasts,
    required this.onNotificationsTap,
    required this.onProfileTap,
    required this.uid,
  });

  // lib/widgets/home/home_sliver_app_bar.dart

  String _getGreetingText() {
    if (greeting != null) return greeting!;
    final hour = DateTime.now().hour;
    if (hour >= 3 && hour < 11) return '${ToneManager.t('greeting_pagi')} ';
    if (hour >= 11 && hour < 15) return '${ToneManager.t('greeting_siang')} ';
    if (hour >= 15 && hour < 18) return '${ToneManager.t('greeting_sore')} ';
    return '${ToneManager.t('greeting_malam')} ';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF18181B);
    final subTextColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF3F1F7),
      expandedHeight: 140,
      collapsedHeight: 70,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: Row(
            children: [
              _buildActionButton(
                context,
                icon: CupertinoIcons.bell,
                badgeCount: unreadBroadcasts,
                onTap: onNotificationsTap,
              ),
              const SizedBox(width: 10),
              _buildProfileAvatar(context),
            ],
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.blurBackground,
        ],
        centerTitle: false,
        titlePadding: EdgeInsets.zero,
        background: Container(
          color: isDark ? const Color(0xFF121214) : const Color(0xFFF3F1F7),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreetingText(),
                  style: TextStyle(
                    fontSize: 14,
                    color: subTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _getDisplayName(user),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 10),
                      _buildAdminBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayName(User? user, {int limit = 20}) {
    String rawName = user?.displayName?.split(' ').first ?? 'Pengguna';
    if (rawName.length > limit) {
      return '${rawName.substring(0, limit)}...';
    }
    return rawName;
  }

  Widget _buildAdminBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSuperAdmin
              ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
              : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isSuperAdmin ? const Color(0xFFFFD700) : Colors.blue)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isSuperAdmin ? CupertinoIcons.sparkles : CupertinoIcons.shield_fill,
            color: Colors.white,
            size: 10,
          ),
          const SizedBox(width: 4),
          Text(
            isSuperAdmin
                ? ToneManager.t('badge_owner')
                : ToneManager.t('badge_admin'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E22) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : const Color(0xFF18181B),
              size: 20,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context) {
    return GestureDetector(
      onTap: onProfileTap,
      child: ConnectionBadge(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none, // Agar icon tidak terpotong saat ditaruh di luar
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(CupertinoIcons.person_fill,
                        size: 22, color: AppColors.primary)
                    : null,
              ),
              if (isAdmin)
                Positioned(
                  top: -4, // Geser sedikit ke atas luar lingkaran
                  left: -4, // Geser sedikit ke kiri luar lingkaran
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // White background only for the center checkmark
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.checkmark_seal_fill,
                        color: AppColors.primary,
                        size: 15,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
