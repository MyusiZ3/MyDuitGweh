import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'user_management_screen.dart';
import 'global_insights_screen.dart';
import 'broadcast_center_screen.dart';
import 'app_config_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      const Text('Admin Console', 
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -1.2)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 20),
                      ),
                    ],
                  ),
                  const Text('Kelola ekosistem MyDuitGweh di satu tempat.', 
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
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
                        subtitle: 'Kelola peran & status akun.',
                        icon: Icons.manage_accounts_rounded,
                        color: Colors.indigoAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Live Insights',
                        subtitle: 'Analisis kesehatan ekonomi app.',
                        icon: Icons.query_stats_rounded,
                        color: Colors.deepOrangeAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalInsightsScreen())),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'Broadcast',
                        subtitle: 'Kirim pengumuman massal.',
                        icon: Icons.campaign_rounded,
                        color: Colors.tealAccent[700]!,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastCenterScreen())),
                      ),
                      _buildMenuCard(
                        context,
                        title: 'App Config',
                        subtitle: 'Ganti maintenance & versi app.',
                        icon: Icons.dns_rounded,
                        color: Colors.purpleAccent,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppConfigScreen())),
                      ),
                    ],
                  ),
                  const Text('System Health', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  _buildStatusTile('Database Engine', 'Operational', Icons.storage_rounded, Colors.green),
                  _buildStatusTile('Notification Node', 'Active', Icons.notifications_active_rounded, Colors.green),
                  _buildStatusTile('Auth Service', 'Healthy', Icons.security_rounded, Colors.green),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 40),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark.withOpacity(0.9),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -40,
              bottom: -40,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.dashboard_customize_rounded, size: 240, color: Colors.white),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level: SuperAdmin', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text('COMMAND HUB', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(String label, String status, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Text(status, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(36),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(36),
             border: Border.all(color: AppColors.surfaceVariant),
             boxShadow: [
               BoxShadow(color: color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
