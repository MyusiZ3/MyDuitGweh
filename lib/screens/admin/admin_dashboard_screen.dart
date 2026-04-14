import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_service.dart';
import 'user_management_screen.dart';
import 'global_insights_screen.dart';
import 'broadcast_center_screen.dart';
import 'app_config_screen.dart';
import 'security_monitor_screen.dart';
import '../../services/security_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AuthService _authService = AuthService();
  bool _isSuper = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    try {
      bool isSuper = await _authService.isSuperAdmin(forceRefresh: true);

      // Retry once if false (Firestore sync delay)
      if (!isSuper) {
        await Future.delayed(const Duration(milliseconds: 1500));
        isSuper = await _authService.isSuperAdmin(forceRefresh: true);
      }

      if (mounted) {
        setState(() {
          _isSuper = isSuper;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Admin Console',
                          style: TextStyle(
                              color: Theme.of(context).textTheme.displayLarge?.color,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              letterSpacing: -1.2)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isSuper ? Colors.amber : Theme.of(context).primaryColor)
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                            _isSuper
                                ? Icons.stars_rounded
                                : Icons.shield_rounded,
                            color: _isSuper
                                ? Colors.amber[700]
                                : Theme.of(context).primaryColor,
                            size: 20),
                      ),
                    ],
                  ),
                  Text(
                      _isSuper
                          ? 'Selamat datang kembali, Owner.'
                          : 'Akses dashboard administrator.',
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),

                  // GRID MENU
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.9,
                      children: [
                        _buildMenuCard(
                          context,
                          title: 'User Control',
                          subtitle: _isSuper
                              ? 'Kelola peran & status akun.'
                              : 'Lihat daftar pengguna.',
                          icon: Icons.manage_accounts_rounded,
                          color: Colors.indigoAccent,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const UserManagementScreen())),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Live Insights',
                          subtitle: 'Analisis kesehatan ekonomi app.',
                          icon: Icons.query_stats_rounded,
                          color: Colors.deepOrangeAccent,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => GlobalInsightsScreen(isSuperAdmin: _isSuper))),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'Broadcast',
                          subtitle: 'Kirim pengumuman massal.',
                          icon: Icons.campaign_rounded,
                          color: Colors.tealAccent[700]!,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BroadcastCenterScreen())),
                        ),
                        _buildMenuCard(
                          context,
                          title: 'App Config',
                          subtitle: _isSuper
                              ? 'Ganti maintenance & versi app.'
                              : 'Lihat konfigurasi app.',
                          icon: Icons.dns_rounded,
                          color: Colors.purpleAccent,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AppConfigScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSecurityHubBanner(context),
                    const SizedBox(height: 32),
                    Text('System Health',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.titleLarge?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    _buildStatusTile('Database Engine', 'Operational',
                        Icons.storage_rounded, Colors.green),
                    _buildStatusTile('Notification Node', 'Active',
                        Icons.notifications_active_rounded, Colors.green),
                    _buildStatusTile('Auth Service', 'Healthy',
                        Icons.security_rounded, Colors.green),

                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 40),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityHubBanner(BuildContext context) {
    return StreamBuilder<int>(
      stream: SecurityService().getUnreadCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final bool hasAlert = count > 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecurityMonitorScreen()),
            ),
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: hasAlert
                      ? [Colors.red[900]!, Colors.red[700]!]
                      : (Theme.of(context).brightness == Brightness.dark
                          ? [const Color(0xFF1E1E2E), const Color(0xFF2D2D44)]
                          : [const Color(0xFF2D2D44), const Color(0xFF434361)]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasAlert ? Colors.red : Colors.black).withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _PulseIcon(isActive: hasAlert),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SECURITY HUB',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasAlert
                              ? '$count Ancaman Terdeteksi'
                              : 'Sistem Terpantau Aman',
                          style: TextStyle(
                            color: hasAlert ? Colors.white : Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: hasAlert ? Colors.white : Colors.white24,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context) {

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isSuper
                      ? [
                          const Color(0xFFB8860B), // Dark Goldenrod
                          Theme.of(context).brightness == Brightness.dark 
                              ? Colors.black 
                              : const Color(0xFF8B6B00),
                        ]
                      : [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColorDark.withOpacity(0.9),
                        ],
                ),
              ),
            ),
            Positioned(
              right: -40,
              bottom: -40,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                    _isSuper
                        ? Icons.stars_rounded
                        : Icons.dashboard_customize_rounded,
                    size: 240,
                    color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Level: ${_isSuper ? 'OWNER / SUPER ADMIN' : 'ADMINISTRATOR'}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const Text('COMMAND HUB',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(
      String label, String status, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceVariantDark.withOpacity(0.5)
            : AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Text(status,
              style: TextStyle(
                  fontWeight: FontWeight.w900, color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(36),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.05),
            ),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  final bool isActive;
  const _PulseIcon({required this.isActive});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 48 * _controller.value,
              height: 48 * _controller.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (widget.isActive ? Colors.red : Colors.cyanAccent)
                    .withOpacity(1 - _controller.value),
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.isActive ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isActive ? Icons.gpp_maybe_rounded : Icons.security_rounded,
            color: widget.isActive ? Colors.red[900] : (Theme.of(context).brightness == Brightness.dark ? Colors.cyanAccent : Colors.indigo),
            size: 24,
          ),
        ),
      ],
    );
  }
}
