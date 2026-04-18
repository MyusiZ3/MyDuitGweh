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
    if (hour < 11) return '${ToneManager.t('greeting_pagi')} ';
    if (hour < 15) return '${ToneManager.t('greeting_siang')} ';
    if (hour < 18) return '${ToneManager.t('greeting_sore')} ';
    return '${ToneManager.t('greeting_malam')} ';
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor:
          Colors.transparent, // Background handled by flexibleSpace
      expandedHeight: 140,
      collapsedHeight: 70,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final headerColor =
              isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white;
          final textColor = isDark ? Colors.white : const Color(0xFF1D1D1F);
          final subTextColor = isDark ? Colors.white70 : Colors.black54;

          final collapsePercent = ((140 - top) / (140 - 70)).clamp(0.0, 1.0);
          final isCollapsed = collapsePercent > 0.3; 

          return FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.blurBackground,
              StretchMode.zoomBackground,
            ],
            centerTitle: false,
            titlePadding: EdgeInsets.zero,
            background: Container(color: headerColor),
            title: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 10 * collapsePercent,
                  sigmaY: 10 * collapsePercent,
                ),
                child: Container(
                  width: double.infinity,
                  height: top,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(collapsePercent * 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(collapsePercent * 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting Row (Smaller when collapsed)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: 1.0,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getGreetingText(),
                                style: TextStyle(
                                  fontSize: 10 + (2 * (1 - collapsePercent)),
                                  color: subTextColor,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _getDisplayName(user, limit: isCollapsed ? 8 : 15),
                                      style: TextStyle(
                                        fontSize:
                                            18 + (10 * (1 - collapsePercent)),
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                        letterSpacing: -0.5 -
                                            (0.8 * (1 - collapsePercent)),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  if (isAdmin) ...[
                                    const SizedBox(width: 8),
                                    _buildAdminBadge(),
                                  ],
                                ],
                              ),
                              // Spacing to keep title aligned at bottom
                              SizedBox(
                                  height: 12 + (8 * (1 - collapsePercent))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              _buildActionButtons(context),
              const SizedBox(width: 8),
              _buildProfileAvatar(context),
            ],
          ),
        ),
      ],
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

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotificationsTap,
              icon: Icon(
                CupertinoIcons.bell,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : const Color(0xFF1D1D1F),
                size: 26,
              ),
            ),
            if (unreadBroadcasts > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadBroadcasts > 9 ? '9+' : '$unreadBroadcasts',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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
