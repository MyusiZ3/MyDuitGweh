import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import 'user_management_screen.dart';
import 'global_insights_screen.dart';
import 'app_config_screen.dart';
import 'broadcast_center_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/currency_formatter.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  final AuthService _authService = AuthService();
  bool _isSuperAdmin = false;
  bool _isConfigLoading = true;

  int _totalUsers = 0;
  int _totalWallets = 0;
  double _totalLiquidity = 0.0;

  @override
  void initState() {
    super.initState();
    _checkSuperAdmin();
    _loadStats();
  }

  Future<void> _checkSuperAdmin() async {
    try {
      final isSuper = await _authService.isSuperAdmin(forceRefresh: true);
      if (mounted) {
        setState(() {
          _isSuperAdmin = isSuper;
          _isConfigLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConfigLoading = false);
      }
    }
  }

  void _loadStats() {
    // Basic stats for the dashboard
    FirebaseFirestore.instance.collection('users').count().get().then((snap) {
      if (mounted) setState(() => _totalUsers = snap.count ?? 0);
    });

    FirebaseFirestore.instance.collectionGroup('wallets').snapshots().listen((snap) {
      if (mounted) {
        double total = 0;
        for (var doc in snap.docs) {
          total += (doc.data()['balance'] ?? 0);
        }
        setState(() {
          _totalWallets = snap.docs.length;
          _totalLiquidity = total;
        });
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Admin Control Panel', 
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isConfigLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsHeader(),
              const SizedBox(height: 32),
              _buildSectionHeader('System Hub', Icons.grid_view_rounded),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.15,
                children: [
                _buildCommandCard(
                  title: 'User Manager',
                  subtitle: 'User list & Access',
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                ),
                _buildCommandCard(
                  title: 'Broadcast Center',
                  subtitle: 'Push Alerts',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFFF43F5E),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastCenterScreen())),
                ),
                _buildCommandCard(
                  title: 'App Config',
                  subtitle: 'System Meta',
                  icon: Icons.settings_suggest_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppConfigScreen())),
                ),
                _buildCommandCard(
                  title: 'Live Insights',
                  subtitle: 'Analytics Core',
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalInsightsScreen())),
                ),
              ],
            ),
            if (_isSuperAdmin) ...[
              const SizedBox(height: 32),
              _buildSectionHeader('System & Utility', Icons.settings_rounded),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('app_config').doc('global').snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.hasData ? snapshot.data!.data() as Map<String, dynamic>? ?? {} : {};
                final isMaintenance = data['isMaintenance'] ?? false;
                final startTime = (data['maintenanceStartTime'] as Timestamp?)?.toDate();
                
                return Column(
                  children: [
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: _buildCommandCard(
                        title: 'Maintenance Mode',
                        subtitle: isMaintenance ? 'STATUS: AKTIF' : (startTime != null ? 'TERJADWAL: ${DateFormat('HH:mm').format(startTime)}' : 'STATUS: NON-AKTIF'),
                        icon: Icons.construction_rounded,
                        color: isMaintenance ? Colors.red : Colors.grey,
                        onTap: () => _showMaintenanceControl(isMaintenance, startTime, data['message'] ?? ''),
                        isRestricted: !_isSuperAdmin,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
            ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('app_config')
                    .doc('global')
                    .collection('history')
                    .orderBy('updatedAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 16, color: Colors.blueGrey),
                                SizedBox(width: 8),
                                Text('Global Activity Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full log history coming soon.')));
                              },
                              child: const Text('VIEW ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: Text('No admin activities recorded.', style: TextStyle(fontSize: 11, color: Colors.grey))),
                          )
                        else
                          ...snapshot.data!.docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final action = data['action'] ?? 'ACTIVITY';
                            final time = (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                            
                            IconData icon = Icons.info_outline_rounded;
                            Color color = Colors.grey;
                            String title = 'Admin Action';
                            
                            if (action == 'BROADCAST') {
                              icon = Icons.campaign_rounded;
                              color = Colors.blue;
                              title = data['title'] ?? 'Global Broadcast';
                            } else if (action == 'MAINTENANCE_TOGGLE') {
                              icon = Icons.construction_rounded;
                              color = Colors.orange;
                              title = 'System Maintenance';
                            } else if (action == 'ROLE_CHANGE') {
                              icon = Icons.manage_accounts_rounded;
                              color = Colors.purple;
                              title = 'Role Permission Updated';
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                                    child: Icon(icon, size: 12, color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, 
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        Text(DateFormat('dd MMM, HH:mm').format(time), 
                                          style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(4)),
                                    child: Text(action.toString().split('_').last, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  );
                }
              ),
            ],
            const SizedBox(height: 120),
          ],
        ),
      ),
    ),
    bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastCenterScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('BROADCAST CENTER', 
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommandCard({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap,
    bool isRestricted = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRestricted ? () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akses terbatas untuk Owner/SuperAdmin saja!')));
          } : onTap,
          borderRadius: BorderRadius.circular(24),
          child: Opacity(
            opacity: isRestricted ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      if (isRestricted) Icon(Icons.lock_rounded, color: Colors.grey[400], size: 16),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(title, 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.5)),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(subtitle, 
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 40, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('System Analytics', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 8),
                    SizedBox(width: 8),
                    Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatItem('Users', _totalUsers.toString(), Icons.people_rounded, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatItem('Wallets', _totalWallets.toString(), Icons.wallet_rounded, Colors.teal)),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatItem('Liquidity', CurrencyFormatter.formatCurrency(_totalLiquidity), Icons.account_balance_rounded, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceControl(bool currentStatus, DateTime? startTime, String currentMsg) async {
    final TextEditingController msgController = TextEditingController(text: currentMsg);
    DateTime? selectedStartTime = startTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(context).padding.bottom + 32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Maintenance Control', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Status Aktif Sekarang'),
                trailing: Switch(
                  value: currentStatus,
                  onChanged: (val) async {
                    await FirebaseFirestore.instance.collection('app_config').doc('global').update({'isMaintenance': val});
                    // Log to history
                    await FirebaseFirestore.instance.collection('app_config').doc('global').collection('history').add({
                      'updatedBy': _authService.auth.currentUser?.uid ?? 'system',
                      'updatedAt': FieldValue.serverTimestamp(),
                      'action': 'MAINTENANCE_TOGGLE',
                      'status': val ? 'ON' : 'OFF',
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Jadwal Mulai (Opsional)'),
                subtitle: Text(selectedStartTime == null ? 'Pilih Waktu' : DateFormat('dd MMM, HH:mm').format(selectedStartTime!)),
                trailing: const Icon(Icons.event_rounded),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 7)));
                  if (date != null) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (time != null) {
                      setModalState(() => selectedStartTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                    }
                  }
                },
              ),
              if (selectedStartTime != null)
                TextButton(onPressed: () => setModalState(() => selectedStartTime = null), child: const Text('Hapus Jadwal', style: TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              TextField(
                controller: msgController,
                decoration: const InputDecoration(labelText: 'Pesan Pemeliharaan', hintText: 'Aplikasi sedang diperbarui...'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('app_config').doc('global').update({
                      'maintenanceStartTime': selectedStartTime != null ? Timestamp.fromDate(selectedStartTime!) : null,
                      'message': msgController.text,
                    });
                    // Log to history
                    await FirebaseFirestore.instance.collection('app_config').doc('global').collection('history').add({
                      'updatedBy': _authService.auth.currentUser?.uid ?? 'system',
                      'updatedAt': FieldValue.serverTimestamp(),
                      'action': 'MAINTENANCE_SCHEDULE',
                      'time': selectedStartTime != null ? DateFormat('dd MMM, HH:mm').format(selectedStartTime!) : 'CLEARED',
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cleanup: Removed duplicated or unused methods
}

