import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../connection_badge.dart';

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

  String _getGreetingText() {
    if (greeting != null) return greeting!;
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi 🌤️';
    if (hour < 15) return 'Selamat Siang ☀️';
    if (hour < 18) return 'Selamat Sore ⛅';
    return 'Selamat Malam 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      expandedHeight: 90,
      toolbarHeight: 80,
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: 24,
      title: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getGreetingText(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  Text(
                    user?.displayName ?? 'Pengguna',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    _buildAdminBadge(),
                  ],
                ],
              ),
            ],
          ),
          const Spacer(),
          _buildActionButtons(context),
          const SizedBox(width: 4),
          _buildProfileAvatar(context),
        ],
      ),
    );
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
            isSuperAdmin ? 'OWNER' : 'ADMIN',
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
                color: Theme.of(context).textTheme.titleLarge?.color,
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
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage:
                    user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null
                    ? const Icon(CupertinoIcons.person_fill,
                        size: 22, color: AppColors.primary)
                    : null,
              ),
              if (isAdmin)
                Positioned(
                  top: -3,
                  left: -3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceDark
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white12
                            : Colors.transparent,
                        width: 0.5,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: AppColors.primary,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
