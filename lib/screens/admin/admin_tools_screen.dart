import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import 'user_management_screen.dart';
import 'global_insights_screen.dart';
import 'app_config_screen.dart';
import 'broadcast_center_screen.dart';
import 'admin_logs_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/currency_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/ai_service.dart';
import '../../utils/ui_helper.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  final AuthService _authService = AuthService();
  bool _isSuperAdmin = false;
  bool _isConfigLoading = true;
  int _maxChatsPerHour = 10;
  int _resetDurationMinutes = 60;
  bool _isAiEnabled = true;

  int _totalUsers = 0;
  int _totalWallets = 0;
  double _totalLiquidity = 0.0;

  @override
  void initState() {
    super.initState();
    _checkSuperAdmin();
    _loadStats();
    _loadAIConfig();
  }

  Future<void> _loadAIConfig() async {
    try {
      final aiDoc = await FirebaseFirestore.instance
          .collection('app_settings')
          .doc('ai_config')
          .get();
      if (aiDoc.exists && mounted) {
        final data = aiDoc.data()!;
        setState(() {
          _maxChatsPerHour = data['max_chats_per_hour'] ?? 10;
          _resetDurationMinutes = data['reset_duration_minutes'] ?? 60;
          _isAiEnabled = data['is_ai_enabled'] ?? true;
        });
      }
    } catch (e) {
      debugPrint("Gagal load AI config: $e");
    }
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

    FirebaseFirestore.instance
        .collectionGroup('wallets')
        .snapshots()
        .listen((snap) {
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
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isConfigLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const UserManagementScreen())),
                        ),
                        _buildCommandCard(
                          title: 'Broadcast Center',
                          subtitle: 'Push Alerts',
                          icon: Icons.campaign_rounded,
                          color: const Color(0xFFF43F5E),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const BroadcastCenterScreen())),
                        ),
                        _buildCommandCard(
                          title: 'App Config',
                          subtitle: 'System Meta',
                          icon: Icons.settings_suggest_rounded,
                          color: const Color(0xFF10B981),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AppConfigScreen())),
                        ),
                        _buildCommandCard(
                          title: 'Live Insights',
                          subtitle: 'Analytics Core',
                          icon: Icons.analytics_rounded,
                          color: const Color(0xFFF59E0B),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => GlobalInsightsScreen())),
                        ),
                        _buildCommandCard(
                          title: 'AI Advisor Quota',
                          subtitle: '$_maxChatsPerHour chats/hr',
                          icon: Icons.psychology_rounded,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => _showAIQuotaControl(),
                        ),
                        _buildCommandCard(
                          title: 'AI Health Check',
                          subtitle: 'Manage Integrated Keys',
                          icon: Icons.health_and_safety_rounded,
                          color: const Color(0xFF00C9FF),
                          onTap: () => _showAIHealthCheck(),
                        ),
                      ],
                    ),
                    if (_isSuperAdmin) ...[
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                          'System & Utility', Icons.settings_rounded),
                      const SizedBox(height: 16),
                      StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('app_config')
                              .doc('global')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.hasData
                                ? snapshot.data!.data()
                                        as Map<String, dynamic>? ??
                                    {}
                                : {};
                            final isMaintenance =
                                data['isMaintenance'] ?? false;
                            final startTime =
                                (data['maintenanceStartTime'] as Timestamp?)
                                    ?.toDate();

                            return Column(
                              children: [
                                SizedBox(
                                  height: 140,
                                  width: double.infinity,
                                  child: _buildCommandCard(
                                    title: 'Maintenance Mode',
                                    subtitle: isMaintenance
                                        ? 'STATUS: AKTIF'
                                        : (startTime != null
                                            ? 'TERJADWAL: ${DateFormat('HH:mm').format(startTime)}'
                                            : 'STATUS: NON-AKTIF'),
                                    icon: Icons.construction_rounded,
                                    color: isMaintenance
                                        ? Colors.red
                                        : Colors.grey,
                                    onTap: () => _showMaintenanceControl(
                                        isMaintenance,
                                        startTime,
                                        data['message'] ?? ''),
                                    isRestricted: !_isSuperAdmin,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            );
                          }),
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
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.receipt_long_rounded,
                                              size: 16, color: Colors.blueGrey),
                                          SizedBox(width: 8),
                                          Text('Global Activity Logs',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    const AdminLogsScreen()),
                                          );
                                        },
                                        child: const Text('VIEW ALL',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  if (!snapshot.hasData ||
                                      snapshot.data!.docs.isEmpty)
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 20),
                                      child: Center(
                                          child: Text(
                                              'No admin activities recorded.',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey))),
                                    )
                                  else
                                    ...snapshot.data!.docs.map((doc) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final action =
                                          data['action'] ?? 'ACTIVITY';
                                      final time =
                                          (data['updatedAt'] as Timestamp?)
                                                  ?.toDate() ??
                                              DateTime.now();

                                      IconData icon =
                                          Icons.info_outline_rounded;
                                      Color color = Colors.grey;
                                      String title = 'Admin Action';

                                      if (action == 'BROADCAST') {
                                        icon = Icons.campaign_rounded;
                                        color = Colors.blue;
                                        title =
                                            data['title'] ?? 'Global Broadcast';
                                      } else if (action ==
                                          'MAINTENANCE_TOGGLE') {
                                        icon = Icons.construction_rounded;
                                        color = Colors.orange;
                                        title = 'System Maintenance';
                                      } else if (action == 'ROLE_CHANGE') {
                                        icon = Icons.manage_accounts_rounded;
                                        color = Colors.purple;
                                        title = 'Role Permission Updated';
                                      } else if (action == 'CONFIG_UPDATE') {
                                        icon = Icons.settings_rounded;
                                        color = Colors.teal;
                                        title = 'Config Diubah';
                                      } else if (action == 'DELETE_USER') {
                                        icon = Icons.person_remove_rounded;
                                        color = Colors.red;
                                        title = 'User Dihapus';
                                      } else if (action == 'AI_KEY_ADDED') {
                                        icon = Icons.vpn_key_rounded;
                                        color = Colors.green;
                                        title = 'API Key Ditambahkan';
                                      } else if (action == 'AI_KEY_REMOVED') {
                                        icon = Icons.key_off_rounded;
                                        color = Colors.red;
                                        title = 'API Key Dihapus';
                                      } else if (action == 'AI_QUOTA_UPDATE') {
                                        icon = Icons.psychology_rounded;
                                        color = const Color(0xFF8B5CF6);
                                        title = 'AI Quota Diubah';
                                      } else if (action == 'MAINTENANCE_SCHEDULE') {
                                        icon = Icons.schedule_rounded;
                                        color = Colors.indigo;
                                        title = 'Jadwal Maintenance';
                                      }

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                  color: color.withOpacity(0.1),
                                                  shape: BoxShape.circle),
                                              child: Icon(icon,
                                                  size: 12, color: color),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(title,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  Text(
                                                      DateFormat(
                                                              'dd MMM, HH:mm')
                                                          .format(time),
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          color: Colors
                                                              .grey[400])),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: Colors.grey[50],
                                                  borderRadius:
                                                      BorderRadius.circular(4)),
                                              child: Text(
                                                  action
                                                      .toString()
                                                      .split('_')
                                                      .last,
                                                  style: const TextStyle(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.grey)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            );
                          }),
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
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BroadcastCenterScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('BROADCAST CENTER',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1)),
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
          BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRestricted
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('Akses terbatas untuk Owner/SuperAdmin saja!')));
                }
              : onTap,
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
                      if (isRestricted)
                        Icon(Icons.lock_rounded,
                            color: Colors.grey[400], size: 16),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: -0.5)),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500)),
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
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5)),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 40,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('System Analytics',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -1)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 8),
                    SizedBox(width: 8),
                    Text('LIVE',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildStatItem('Users', _totalUsers.toString(),
                      Icons.people_rounded, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(
                  child: _buildStatItem('Wallets', _totalWallets.toString(),
                      Icons.wallet_rounded, Colors.teal)),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatItem(
              'Liquidity',
              CurrencyFormatter.formatCurrency(_totalLiquidity),
              Icons.account_balance_rounded,
              Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
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
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600])),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: -0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceControl(
      bool currentStatus, DateTime? startTime, String currentMsg) async {
    final TextEditingController msgController =
        TextEditingController(text: currentMsg);
    DateTime? selectedStartTime = startTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 32, 24, MediaQuery.of(context).padding.bottom + 32),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Maintenance Control',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Status Aktif Sekarang'),
                trailing: Switch(
                  value: currentStatus,
                  onChanged: (val) async {
                    await FirebaseFirestore.instance
                        .collection('app_config')
                        .doc('global')
                        .update({'isMaintenance': val});
                    // Log to history
                    await FirebaseFirestore.instance
                        .collection('app_config')
                        .doc('global')
                        .collection('history')
                        .add({
                      'updatedBy':
                          _authService.auth.currentUser?.uid ?? 'system',
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
                subtitle: Text(selectedStartTime == null
                    ? 'Pilih Waktu'
                    : DateFormat('dd MMM, HH:mm').format(selectedStartTime!)),
                trailing: const Icon(Icons.event_rounded),
                onTap: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 7)));
                  if (date != null) {
                    final time = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (time != null) {
                      setModalState(() => selectedStartTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute));
                    }
                  }
                },
              ),
              if (selectedStartTime != null)
                TextButton(
                    onPressed: () =>
                        setModalState(() => selectedStartTime = null),
                    child: const Text('Hapus Jadwal',
                        style: TextStyle(color: Colors.red))),
              const SizedBox(height: 16),
              TextField(
                controller: msgController,
                decoration: const InputDecoration(
                    labelText: 'Pesan Pemeliharaan',
                    hintText: 'Aplikasi sedang diperbarui...'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('app_config')
                        .doc('global')
                        .update({
                      'maintenanceStartTime': selectedStartTime != null
                          ? Timestamp.fromDate(selectedStartTime!)
                          : null,
                      'message': msgController.text,
                    });
                    // Log to history
                    await FirebaseFirestore.instance
                        .collection('app_config')
                        .doc('global')
                        .collection('history')
                        .add({
                      'updatedBy':
                          _authService.auth.currentUser?.uid ?? 'system',
                      'updatedAt': FieldValue.serverTimestamp(),
                      'action': 'MAINTENANCE_SCHEDULE',
                      'time': selectedStartTime != null
                          ? DateFormat('dd MMM, HH:mm')
                              .format(selectedStartTime!)
                          : 'CLEARED',
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('SIMPAN PERUBAHAN',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAIQuotaControl() {
    int tempMaxChats = _maxChatsPerHour;
    int tempInterval = _resetDurationMinutes;
    bool tempAiEnabled = _isAiEnabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 32, 24, MediaQuery.of(context).padding.bottom + 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('AI Advisor Quota',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Kontrol jatah konsultasi AI untuk pengguna yang menggunakan integrated key (bawaan admin). Pengguna dengan API Key pribadi tidak akan dibatasi.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Max Chats per Hour',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$tempMaxChats',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF8B5CF6))),
                ],
              ),
              Slider(
                value: tempMaxChats.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: const Color(0xFF8B5CF6),
                onChanged: (v) => setModalState(() => tempMaxChats = v.round()),
              ),
              const Divider(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reset Interval (Minutes)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$tempInterval',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF8B5CF6))),
                ],
              ),
              Slider(
                value: tempInterval.toDouble(),
                min: 5,
                max: 1440,
                divisions: 287,
                activeColor: const Color(0xFF8B5CF6),
                onChanged: (v) => setModalState(() => tempInterval = v.round()),
              ),
              const Divider(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tempAiEnabled ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tempAiEnabled ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tempAiEnabled ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (tempAiEnabled ? Colors.green : Colors.red).withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Icon(
                        tempAiEnabled ? Icons.bolt_rounded : Icons.power_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tempAiEnabled ? 'AI Service Active' : 'AI Service Disabled',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          ),
                          Text(
                            tempAiEnabled ? 'Fitur AI Advisor saat ini aktif untuk semua pengguna.' : 'Akses AI Advisor akan ditutup sementara untuk publik.',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: tempAiEnabled,
                      activeColor: Colors.green,
                      onChanged: (v) => setModalState(() => tempAiEnabled = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('app_settings')
                          .doc('ai_config')
                          .set({
                        'max_chats_per_hour': tempMaxChats,
                        'reset_duration_minutes': tempInterval,
                        'is_ai_enabled': tempAiEnabled,
                        'lastUpdated': FieldValue.serverTimestamp(),
                        'updatedBy':
                            _authService.auth.currentUser?.uid ?? 'system',
                      }, SetOptions(merge: true));

                      // Add to logs
                      await FirebaseFirestore.instance
                          .collection('app_config')
                          .doc('global')
                          .collection('history')
                          .add({
                        'updatedBy':
                            _authService.auth.currentUser?.uid ?? 'system',
                        'updatedAt': FieldValue.serverTimestamp(),
                        'action': tempAiEnabled != _isAiEnabled ? 'AI_STATUS_CHANGED' : 'AI_QUOTA_UPDATE',
                        'status': tempAiEnabled,
                        'max_chats': tempMaxChats,
                        'interval': tempInterval,
                      });

                      setState(() {
                        _maxChatsPerHour = tempMaxChats;
                        _resetDurationMinutes = tempInterval;
                        _isAiEnabled = tempAiEnabled;
                      });

                      if (mounted) Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI Quota configuration saved!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('SAVE CONFIGURATION',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAIHealthCheck() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: SafeArea(
            bottom: true,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Health Diagnostic',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1)),
                          Text('Gemini + Groq API Status',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('app_settings')
                        .doc('ai_config')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final List<String> geminiKeys = List<String>.from(data['gemini_keys'] ?? []);
                      final List<String> groqKeys = List<String>.from(data['groq_keys'] ?? []);

                      Widget buildKeyCard(String key, int index, String provider, List<String> allKeys) {
                        final obscuredKey = key.length > 12 ? "${key.substring(0, 6)}...${key.substring(key.length - 4)}" : key;
                        final isGroq = provider == 'groq';
                        final keyField = isGroq ? 'groq_keys' : 'gemini_keys';
                        final keyColor = isGroq ? const Color(0xFFF55036) : const Color(0xFF00C9FF);
                        final keyIcon = isGroq ? Icons.bolt_rounded : Icons.vpn_key_rounded;
                        return StatefulBuilder(
                          builder: (context, setItemState) {
                        String healthStatus = 'unknown';
                        String healthMessage = 'Tap cek untuk verifikasi';
                        
                        return StatefulBuilder(
                          builder: (context, setItemState) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.black.withOpacity(0.05)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: Column(children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: keyColor.withOpacity(0.1), shape: BoxShape.circle),
                                    child: Icon(keyIcon, color: keyColor, size: 18),
                                  ),
                                  title: Text(obscuredKey, style: const TextStyle(fontFamily: 'Monospace', fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.5)),
                                  subtitle: Text('${isGroq ? "Groq" : "Gemini"} #${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      final confirm = await UIHelper.showConfirmDialog(context: context, title: 'Hapus Key?', message: 'Yakin hapus API Key ini?', confirmText: 'Hapus');
                                      if (confirm == true) {
                                        allKeys.removeAt(index);
                                        await FirebaseFirestore.instance.collection('app_settings').doc('ai_config').update({keyField: allKeys});
                                        await FirebaseFirestore.instance.collection('app_config').doc('global').collection('history').add({
                                          'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? 'system',
                                          'updatedAt': FieldValue.serverTimestamp(),
                                          'action': isGroq ? 'GROQ_KEY_REMOVED' : 'AI_KEY_REMOVED',
                                          'key_index': index,
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const Divider(height: 1, indent: 20, endIndent: 20, color: Color(0xFFF0F0F0)),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                                  child: Row(children: [
                                    Expanded(child: Row(children: [
                                      Container(
                                        width: 10, 
                                        height: 10, 
                                        decoration: BoxDecoration(
                                          color: healthStatus == 'ok' ? Colors.green : (healthStatus == 'limit' ? Colors.orange : (healthStatus == 'invalid' ? Colors.red : (healthStatus == 'error' ? Colors.red : Colors.grey))),
                                          shape: BoxShape.circle,
                                          boxShadow: healthStatus == 'unknown' || healthStatus == 'checking' ? null : [
                                            BoxShadow(
                                              color: (healthStatus == 'ok' ? Colors.green : (healthStatus == 'limit' ? Colors.orange : Colors.red)).withOpacity(0.4),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(healthMessage, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: healthStatus == 'ok' ? Colors.green : (healthStatus == 'limit' ? Colors.orange : (healthStatus == 'invalid' ? Colors.red : (healthStatus == 'error' ? Colors.red : Colors.grey[600])))), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ])),
                                    TextButton(
                                      onPressed: healthStatus == 'checking' ? null : () async {
                                        setItemState(() { healthStatus = 'checking'; healthMessage = 'Verifikasi...'; });
                                        try {
                                          final statusMap = isGroq ? await AIService().checkGroqKeyStatus(key) : await AIService().checkKeyStatus(key);
                                          setItemState(() { 
                                            healthStatus = statusMap['status'] ?? 'error'; 
                                            healthMessage = statusMap['message'] ?? 'Error'; 
                                          });
                                        } catch (e) {
                                          setItemState(() { healthStatus = 'error'; healthMessage = 'Error: $e'; });
                                        }
                                      },
                                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), backgroundColor: Colors.black.withOpacity(0.03), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (healthStatus == 'checking') const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                        else const Icon(Icons.refresh_rounded, size: 14, color: Colors.black),
                                        const SizedBox(width: 6),
                                        Text(healthStatus == 'checking' ? 'Cek...' : 'Cek Status', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                                      ]),
                                    ),
                                  ]),
                                ),
                              ]),
                            );
                          },
                        );
                          },
                        );
                      }

                      Widget buildSectionHeader(String label, IconData icon, Color color, int count, VoidCallback onAdd) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 14, color: color)),
                            const SizedBox(width: 8),
                            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const Spacer(),
                            Text('$count key', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onAdd,
                              child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 14)),
                            ),
                          ]),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          buildSectionHeader('GEMINI', Icons.auto_awesome_rounded, const Color(0xFF00C9FF), geminiKeys.length, () => _showAddKeyDialog(setModalState, 'gemini')),
                          if (geminiKeys.isEmpty)
                            Container(padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Belum ada Gemini key', style: TextStyle(color: Colors.grey, fontSize: 12)))),
                          ...geminiKeys.asMap().entries.map((e) => buildKeyCard(e.value, e.key, 'gemini', geminiKeys)),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          buildSectionHeader('GROQ', Icons.bolt_rounded, const Color(0xFFF55036), groqKeys.length, () => _showAddKeyDialog(setModalState, 'groq')),
                          if (groqKeys.isEmpty)
                            Container(padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Belum ada Groq key', style: TextStyle(color: Colors.grey, fontSize: 12)))),
                          ...groqKeys.asMap().entries.map((e) => buildKeyCard(e.value, e.key, 'groq', groqKeys)),
                        ]),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('DONE',
                          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddKeyDialog(Function setModalState, String provider) {
    final TextEditingController keyController = TextEditingController();
    final bool isGroq = provider == 'groq';
    final String keyFieldName = isGroq ? 'groq_keys' : 'gemini_keys';
    final Color providerColor = isGroq ? const Color(0xFFF55036) : AppColors.primary;
    final String providerLabel = isGroq ? 'GROQ' : 'GEMINI';
    final String hintText = isGroq ? 'Masukkan Groq Key (gsk_...)' : 'Masukkan API Key (AIzaSy...)';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.only(
              left: 32,
              right: 32,
              top: 32,
              bottom: 32 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: providerColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isGroq ? Icons.bolt_rounded : Icons.vpn_key_rounded,
                            color: providerColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ADD $providerLabel API',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tambahkan API Key baru ke dalam rotasi sistem untuk menambah kuota global.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: keyController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                            filled: true,
                            fillColor: Colors.black.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            prefixIcon: const Icon(Icons.key_rounded, size: 18),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.pop(ctx),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'BATAL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final keyText = keyController.text.trim();
                                  if (keyText.isEmpty) return;

                                  // Validate API Key format
                                  if (isGroq) {
                                    if (!keyText.startsWith('gsk_') || keyText.length < 20) {
                                      if (context.mounted) {
                                        UIHelper.showErrorSnackBar(context, 'Format Groq Key tidak valid. Key harus diawali "gsk_".');
                                      }
                                      return;
                                    }
                                  } else {
                                    if (!keyText.startsWith('AIza') || keyText.length < 30) {
                                      if (context.mounted) {
                                        UIHelper.showErrorSnackBar(context, 'Format Gemini Key tidak valid. Key harus diawali "AIza".');
                                      }
                                      return;
                                    }
                                  }

                                  // Verify API Key with Google
                                  try {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                            SizedBox(width: 12),
                                            Text('Memverifikasi API Key ke Google...'),
                                          ],
                                        ),
                                        duration: Duration(seconds: 15),
                                      ),
                                    );

                                    final statusResult = isGroq
                                        ? await AIService().checkGroqKeyStatus(keyText)
                                        : await AIService().checkKeyStatus(keyText);
                                    if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

                                    if (statusResult['isValid'] != true) {
                                      if (context.mounted) {
                                        UIHelper.showErrorSnackBar(context, '❌ ${statusResult['message']}');
                                      }
                                      return;
                                    }
                                  } catch (e) {
                                    if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    if (context.mounted) {
                                      UIHelper.showErrorSnackBar(context, 'Gagal verifikasi: $e');
                                    }
                                    return;
                                  }

                                  try {
                                    final configRef = FirebaseFirestore.instance
                                        .collection('app_settings')
                                        .doc('ai_config');
                                    
                                    final config = await configRef.get();
                                    
                                    List<String> keys = [];
                                    if (config.exists) {
                                      keys = List<String>.from(config.data()?[keyFieldName] ?? []);
                                    }

                                    // Check for duplicates
                                    if (keys.contains(keyText)) {
                                      if (context.mounted) {
                                        UIHelper.showErrorSnackBar(context, 'API Key ini sudah ada di daftar!');
                                      }
                                      return;
                                    }

                                    keys.add(keyText);

                                    await configRef.set(
                                      {keyFieldName: keys},
                                      SetOptions(merge: true),
                                    );

                                    // Log activity
                                    await FirebaseFirestore.instance
                                        .collection('app_config')
                                        .doc('global')
                                        .collection('history')
                                        .add({
                                      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? 'system',
                                      'updatedAt': FieldValue.serverTimestamp(),
                                      'action': isGroq ? 'GROQ_KEY_ADDED' : 'AI_KEY_ADDED',
                                    });

                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      UIHelper.showSuccessSnackBar(context, '✅ $providerLabel Key valid dan berhasil ditambahkan!');
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      UIHelper.showErrorSnackBar(context, 'Gagal: $e');
                                    }
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'SIMPAN KEY',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
