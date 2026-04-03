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
import 'package:flutter/services.dart';
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
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                        'AI System Engine', Icons.auto_awesome_rounded),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildCommandCard(
                          title: 'AI Advisor Quota',
                          subtitle: _resetDurationMinutes < 60
                              ? '$_maxChatsPerHour chat / $_resetDurationMinutes min'
                              : '$_maxChatsPerHour chat / ${(_resetDurationMinutes / 60).toStringAsFixed(_resetDurationMinutes % 60 == 0 ? 0 : 1)} jam',
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
                                      } else if (action ==
                                          'MAINTENANCE_SCHEDULE') {
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
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: ui.Color.fromARGB(255, 0, 122, 255)),
                      const SizedBox(width: 12),
                      const Text('AI Advisor Management',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.5)),
                      const Spacer(),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                      'Atur limitasi akses AI untuk semua pengguna publik.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Box with Glass style
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.info_outline_rounded,
                                    size: 16, color: Colors.blue),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'INFO RESET KUOTA',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Sistem menggunakan Fixed Window. Kuota user akan di-reset (kembali ke 0) setiap interval yang ditentukan sejak chat pertama mereka dalam siklus tersebut.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blueGrey,
                                          height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Max Chats Input Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Max Chats per Hour',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16)),
                                Text('Jatah pesan per user',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            Text('$tempMaxChats',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: ui.Color.fromRGBO(0, 122, 255, 1),
                                    letterSpacing: -1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24),
                          ),
                          child: Slider(
                            value: tempMaxChats.toDouble(),
                            min: 1,
                            max: 100,
                            divisions: 99,
                            activeColor: ui.Color.fromRGBO(0, 122, 255, 1),
                            inactiveColor: ui.Color.fromRGBO(0, 122, 255, 1)
                                .withOpacity(0.1),
                            onChanged: (v) =>
                                setModalState(() => tempMaxChats = v.round()),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Cycle Input Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Reset Cycle (Minutes)',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16)),
                                Text('Jendela reset kuota (60 = 1 Jam)',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            Text('$tempInterval',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: ui.Color.fromRGBO(0, 122, 255, 1),
                                    letterSpacing: -1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24),
                          ),
                          child: Slider(
                            value: tempInterval.toDouble(),
                            min: 5,
                            max: 1440,
                            divisions: 287,
                            activeColor: ui.Color.fromRGBO(0, 122, 255, 1),
                            inactiveColor: ui.Color.fromRGBO(0, 122, 255, 1)
                                .withOpacity(0.1),
                            onChanged: (v) =>
                                setModalState(() => tempInterval = v.round()),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Status Toggle Component
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: Colors.black.withOpacity(0.03)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: tempAiEnabled
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  tempAiEnabled
                                      ? Icons.check_circle_rounded
                                      : Icons.pause_circle_rounded,
                                  color:
                                      tempAiEnabled ? Colors.green : Colors.red,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tempAiEnabled
                                          ? 'Service Active'
                                          : 'Service Paused',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15),
                                    ),
                                    Text(
                                      'Klik switch untuk ubah status.',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: tempAiEnabled,
                                activeColor: Colors.green,
                                onChanged: (v) =>
                                    setModalState(() => tempAiEnabled = v),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 64,
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
                                      _authService.auth.currentUser?.uid ??
                                          'system',
                                }, SetOptions(merge: true));

                                // Add to logs
                                await FirebaseFirestore.instance
                                    .collection('app_config')
                                    .doc('global')
                                    .collection('history')
                                    .add({
                                  'updatedBy':
                                      _authService.auth.currentUser?.uid ??
                                          'system',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                  'action': tempAiEnabled != _isAiEnabled
                                      ? 'AI_STATUS_CHANGED'
                                      : 'AI_QUOTA_UPDATE',
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
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 12),
                                        Text('Konfigurasi AI diperbarui! ✨'),
                                      ],
                                    ),
                                    backgroundColor: AppColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.redAccent),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: const Text('SIMPAN PERUBAHAN',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showAIHealthCheck() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.health_and_safety_rounded,
                          color: ui.Color.fromRGBO(0, 122, 255, 1)),
                      const SizedBox(width: 12),
                      const Text('AI Health Diagnostic',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.5)),
                      const Spacer(),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 20)),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                      'Validasi status Gemini & Groq API secara real-time.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('app_settings')
                        .doc('ai_config')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final data =
snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final List<String> geminiKeys =
                          List<String>.from(data['gemini_keys'] ?? []);
                      final List<String> groqKeys =
                          List<String>.from(data['groq_keys'] ?? []);

                      Widget buildKeyCard(String key, int index,
                          String provider, List<String> allKeys) {
                        final obscuredKey = key.length > 12
                            ? "${key.substring(0, 6)}...${key.substring(key.length - 4)}"
                            : key;
                        final isGroq = provider == 'groq';
                        final keyField = isGroq ? 'groq_keys' : 'gemini_keys';
                        final keyColor = isGroq
                            ? const Color(0xFFF55036)
                            : ui.Color.fromRGBO(0, 122, 255, 1);
                        final keyIcon =
                            isGroq ? Icons.bolt_rounded : Icons.vpn_key_rounded;

                        String healthStatus = 'unknown';
                        String healthMessage = 'Tap TEST to verify';

                        return StatefulBuilder(
                          builder: (context, setItemState) {
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.04)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.fromLTRB(
                                        20, 10, 10, 10),
                                    leading: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: keyColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(keyIcon,
                                          color: keyColor, size: 20),
                                    ),
                                    title: Text(
                                      obscuredKey,
                                      style: const TextStyle(
                                        fontFamily: 'Monospace',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${isGroq ? "Groq" : "Gemini"} Config #${index + 1}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500]),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Colors.redAccent,
                                          size: 22),
                                      onPressed: () async {
                                        final confirm =
                                            await UIHelper.showConfirmDialog(
                                                context: context,
                                                title: 'Delete Key?',
                                                message:
                                                    'Are you sure you want to remove this API key?',
                                                confirmText: 'Delete');
                                        if (confirm == true) {
                                          allKeys.removeAt(index);
                                          await FirebaseFirestore.instance
                                              .collection('app_settings')
                                              .doc('ai_config')
                                              .update({keyField: allKeys});
                                        }
                                      },
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    height: 1,
                                    color: Colors.black.withOpacity(0.03),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 12, 12, 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: healthStatus == 'ok'
                                                      ? Colors.green
                                                      : (healthStatus == 'limit'
                                                          ? Colors.orange
                                                          : (healthStatus == 'invalid' || healthStatus == 'error'
                                                              ? Colors.red
                                                              : Colors.grey[400])),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  healthStatus == 'checking'
                                                      ? 'Validating...'
                                                      : healthMessage,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.2,
                                                    color: healthStatus == 'ok'
                                                        ? Colors.green[800]
                                                        : (healthStatus ==
                                                                'unknown'
                                                            ? AppColors.textHint
                                                            : Colors.orange[800]),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          height: 38,
                                          child: ElevatedButton(
                                            onPressed: healthStatus == 'checking'
                                                ? null
                                                : () async {
                                                    setItemState(() {
                                                      healthStatus = 'checking';
                                                    });
                                                    try {
                                                      final statusMap = isGroq
                                                          ? await AIService().checkGroqKeyStatus(key)
                                                          : await AIService().checkKeyStatus(key);
                                                      setItemState(() {
                                                        healthStatus = statusMap['status'] ?? 'error';
                                                        healthMessage = statusMap['message'] ?? 'Error';
                                                      });
                                                    } catch (e) {
                                                      setItemState(() {
                                                        healthStatus = 'error';
                                                        healthMessage = 'Failed: $e';
                                                      });
                                                    }
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary.withOpacity(0.1),
                                              foregroundColor: AppColors.primary,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 20),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16)),
                                            ),
                                            child: healthStatus == 'checking'
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                                                  )
                                                : const Row(
                                                    children: [
                                                      Icon(Icons.bolt_rounded, size: 14),
                                                      SizedBox(width: 6),
                                                      Text('TEST',
                                                          style: TextStyle(
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: 12)),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }

                      Widget buildSectionHeader(String label, IconData icon,
                          Color color, int count, VoidCallback onAdd) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: Row(
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(icon, size: 16, color: color)),
                              const SizedBox(width: 12),
                              Text(label,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1)),
                              const Spacer(),
                              Text('$count Keys',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500])),
                              const SizedBox(width: 12),
                              GestureDetector(
                                  onTap: onAdd,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.add_rounded,
                                        color: Colors.white, size: 18),
                                  )),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.only(top: 24, bottom: 32),
                        children: [
                          buildSectionHeader(
                              'GEMINI API',
                              Icons.auto_awesome_rounded,
                              ui.Color.fromRGBO(0, 122, 255, 1),
                              geminiKeys.length,
                              () => _showAddKeyDialog(setModalState, 'gemini')),
                          if (geminiKeys.isEmpty)
                            Container(
                                padding: const EdgeInsets.all(32),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24)),
                                child: const Center(
                                    child: Text('No Gemini keys configured',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500))))
                          else
                            ...geminiKeys.asMap().entries.map((e) =>
                                buildKeyCard(
                                    e.value, e.key, 'gemini', geminiKeys)),
                          const SizedBox(height: 32),
                          buildSectionHeader(
                              'GROQ API',
                              Icons.bolt_rounded,
                              const Color(0xFFF55036),
                              groqKeys.length,
                              () => _showAddKeyDialog(setModalState, 'groq')),
                          if (groqKeys.isEmpty)
                            Container(
                                padding: const EdgeInsets.all(32),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24)),
                                child: const Center(
                                    child: Text('No Groq keys configured',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500))))
                          else
                            ...groqKeys.asMap().entries.map((e) =>
                                buildKeyCard(e.value, e.key, 'groq', groqKeys)),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('DONE',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showAddKeyDialog(Function setParentModalState, String provider) {
    final TextEditingController keyController = TextEditingController();
    final bool isGroq = provider == 'groq';
    final String keyFieldName = isGroq ? 'groq_keys' : 'gemini_keys';
    final Color providerColor =
        isGroq ? const Color(0xFFF55036) : AppColors.primary;
    final String providerLabel = isGroq ? 'GROQ' : 'GEMINI';
    final String hintText =
        isGroq ? 'Masukkan Groq Key (gsk_...)' : 'Masukkan API Key (AIzaSy...)';
    bool isCheckingKey = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                  isGroq
                                      ? Icons.bolt_rounded
                                      : Icons.vpn_key_rounded,
                                  color: providerColor),
                              const SizedBox(width: 12),
                              Text('Add $providerLabel API',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: -0.5)),
                              const Spacer(),
                              IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 20)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text('TAMBAHKAN API KEY BARU',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textHint)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: keyController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: hintText,
                              hintStyle: TextStyle(
                                  color: AppColors.textHint.withOpacity(0.5)),
                              filled: true,
                              fillColor:
                                  AppColors.surfaceVariant.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(Icons.vpn_key_outlined,
                                  size: 20,
                                  color: providerColor.withOpacity(0.5)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final clipboardData =
                                        await Clipboard.getData(
                                            Clipboard.kTextPlain);
                                    if (clipboardData != null &&
                                        clipboardData.text != null) {
                                      keyController.text = clipboardData.text!;
                                    }
                                  },
                                  icon: Icon(Icons.paste_rounded,
                                      size: 16, color: providerColor),
                                  label: Text('Paste',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: providerColor)),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor:
                                        providerColor.withOpacity(0.1),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: providerColor.withOpacity(0.3),
                                          width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: isGroq
                                          ? [
                                              const Color(0xFFF55036),
                                              const Color(0xFFFF7A66)
                                            ]
                                          : [
                                              AppColors.primary,
                                              const Color(0xFF8B5CF6)
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: providerColor.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isCheckingKey
                                        ? null
                                        : () async {
                                            final keyText =
                                                keyController.text.trim();
                                            if (keyText.isEmpty) return;

                                            if (isGroq) {
                                              if (!keyText.startsWith('gsk_') ||
                                                  keyText.length < 20) {
                                                if (context.mounted) {
                                                  UIHelper.showErrorSnackBar(
                                                      context,
                                                      'Format Groq Key tidak valid. Key harus diawali "gsk_".');
                                                }
                                                return;
                                              }
                                            } else {
                                              if (!keyText.startsWith('AIza') ||
                                                  keyText.length < 30) {
                                                if (context.mounted) {
                                                  UIHelper.showErrorSnackBar(
                                                      context,
                                                      'Format Gemini Key tidak valid. Key harus diawali "AIza".');
                                                }
                                                return;
                                              }
                                            }

                                            setDialogState(
                                                () => isCheckingKey = true);

                                            try {
                                              final statusResult = isGroq
                                                  ? await AIService()
                                                      .checkGroqKeyStatus(
                                                          keyText)
                                                  : await AIService()
                                                      .checkKeyStatus(keyText);

                                              if (statusResult['isValid'] !=
                                                  true) {
                                                if (context.mounted) {
                                                  UIHelper.showErrorSnackBar(
                                                      context,
                                                      '❌ ${statusResult['message']}');
                                                }
                                                setDialogState(() =>
                                                    isCheckingKey = false);
                                                return;
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                UIHelper.showErrorSnackBar(
                                                    context,
                                                    'Gagal verifikasi: $e');
                                              }
                                              setDialogState(
                                                  () => isCheckingKey = false);
                                              return;
                                            }

                                            try {
                                              final configRef =
                                                  FirebaseFirestore
                                                      .instance
                                                      .collection(
                                                          'app_settings')
                                                      .doc('ai_config');

                                              final config =
                                                  await configRef.get();

                                              List<String> keys = [];
                                              if (config.exists) {
                                                keys = List<String>.from(
                                                    config.data()?[
                                                            keyFieldName] ??
                                                        []);
                                              }

                                              if (keys.contains(keyText)) {
                                                if (context.mounted) {
                                                  UIHelper.showErrorSnackBar(
                                                      context,
                                                      'API Key ini sudah ada di daftar!');
                                                }
                                                setDialogState(() =>
                                                    isCheckingKey = false);
                                                return;
                                              }

                                              keys.add(keyText);

                                              await configRef.set(
                                                {keyFieldName: keys},
                                                SetOptions(merge: true),
                                              );

                                              await FirebaseFirestore.instance
                                                  .collection('app_config')
                                                  .doc('global')
                                                  .collection('history')
                                                  .add({
                                                'updatedBy': FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid ??
                                                    'system',
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                                'action': isGroq
                                                    ? 'GROQ_KEY_ADDED'
                                                    : 'AI_KEY_ADDED',
                                              });

                                              if (context.mounted)
                                                Navigator.pop(context);
                                              if (context.mounted) {
                                                UIHelper.showSuccessSnackBar(
                                                    context,
                                                    '✅ $providerLabel Key valid dan berhasil ditambahkan!');
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                UIHelper.showErrorSnackBar(
                                                    context, 'Gagal: $e');
                                              }
                                              setDialogState(
                                                  () => isCheckingKey = false);
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: isCheckingKey
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white),
                                            ),
                                          )
                                        : const Text('Simpan & Validasi',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppColors.surfaceVariant),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 20, color: AppColors.textHint),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tambahkan API Key baru ke dalam rotasi sistem untuk menambah kuota global.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
