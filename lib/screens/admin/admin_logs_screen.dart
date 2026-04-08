import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import 'dart:ui';
import '../../utils/ui_helper.dart';
import '../../services/auth_service.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String _searchQuery = "";
  String _selectedCategory = "ALL";
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final isAdmin = await _authService.isSuperAdmin();
    if (mounted) {
      setState(() {
        _isSuperAdmin = isAdmin;
      });
    }
  }

  final List<Map<String, dynamic>> _categories = [
    {'id': 'ALL', 'label': 'Semua', 'icon': Icons.grid_view_rounded},
    {'id': 'BROADCAST', 'label': 'Broadcast', 'icon': Icons.campaign_rounded},
    {
      'id': 'MAINTENANCE_TOGGLE',
      'label': 'Maintenance',
      'icon': Icons.construction_rounded
    },
    {
      'id': 'ROLE_CHANGE',
      'label': 'Akses',
      'icon': Icons.manage_accounts_rounded
    },
    {'id': 'CONFIG_UPDATE', 'label': 'Konfigurasi', 'icon': Icons.settings_rounded},
    {
      'id': 'AI_STATUS_CHANGED',
      'label': 'AI Status',
      'icon': Icons.power_settings_new_rounded
    },
    {
      'id': 'DELETE_USER',
      'label': 'Hapus User',
      'icon': Icons.person_remove_rounded
    },
    {
      'id': 'AI_KEY_ADDED',
      'label': 'API Key +',
      'icon': Icons.vpn_key_rounded
    },
    {
      'id': 'AI_KEY_REMOVED',
      'label': 'API Key -',
      'icon': Icons.key_off_rounded
    },
    {
      'id': 'AI_QUOTA_UPDATE',
      'label': 'AI Quota',
      'icon': Icons.psychology_rounded
    },
    {
      'id': 'SURVEY_TOGGLED',
      'label': 'Survei',
      'icon': Icons.thumbs_up_down_rounded
    },
    {
      'id': 'GROQ_KEY_ADDED',
      'label': 'Groq +',
      'icon': Icons.bolt_rounded
    },
    {
      'id': 'GROQ_KEY_REMOVED',
      'label': 'Groq -',
      'icon': Icons.bolt_rounded
    },
    {
      'id': 'SECURITY_ALERT',
      'label': 'Alert',
      'icon': Icons.security_rounded
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              _buildFilterSection(),
              _buildLogsList(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStatsFloating(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_isSuperAdmin)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: 'Bersihkan Semua Log',
            onPressed: () => _showClearLogsConfirmation(),
          ),
        const SizedBox(width: 8),
      ],
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final top = constraints.biggest.height;
            final isCollapsed = top < 100;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: const Text(
                'Log Riwayat',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
              ),
            );
          },
        ),
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 45, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riwayat Sistem',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Log aktifitas administratif.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat['id']),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cat['icon'],
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat['label'],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Cari aksi atau ID admin...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded,
                color: AppColors.primary.withOpacity(0.4), size: 18),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    final isSecurity = _selectedCategory == 'SECURITY_ALERT';
    
    Query query = isSecurity 
      ? _firestore.collection('security_logs')
      : _firestore.collection('app_config').doc('global').collection('history');

    if (!isSecurity && _selectedCategory != 'ALL') {
      query = query.where('action', isEqualTo: _selectedCategory);
    }

    query = query.orderBy(isSecurity ? 'timestamp' : 'updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final errorMsg = snapshot.error.toString();
          // Jika terjadi error Index, tampilkan info cara perbaiki
          if (errorMsg.contains('index') ||
              errorMsg.contains('FAILED_PRECONDITION')) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_fix_high_rounded,
                            size: 40, color: Colors.orange),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Konfigurasi Indeks Diperlukan',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Filter "${_categories.firstWhere((c) => c['id'] == _selectedCategory)['label']}" memerlukan indeks komposit di Firestore agar dapat diurutkan berdasarkan waktu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600], height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      _buildActionButton(
                        label: 'KEMBALI KE SEMUA',
                        icon: Icons.grid_view_rounded,
                        onPressed: () =>
                            setState(() => _selectedCategory = 'ALL'),
                        isPrimary: true,
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        label: 'LIHAT LOG TERMINAL',
                        icon: Icons.code_rounded,
                        onPressed: () {
                          // Info for user that link is in terminal
                          UIHelper.showInfoSnackBar(context,
                              'Cek terminal VS Code / Log untuk link pembuatan indeks otomatis.');
                        },
                        isPrimary: false,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final action = (data['action'] ?? '').toString().toLowerCase();
          final admin = (data['updatedBy'] ?? '').toString().toLowerCase();
          final title = (data['title'] ?? '').toString().toLowerCase();
          return action.contains(_searchQuery) ||
              admin.contains(_searchQuery) ||
              title.contains(_searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history_toggle_off_rounded,
                        size: 40, color: Colors.grey[300]),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tidak ada aktivitas ditemukan',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coba ubah filter atau kata kunci pencarian.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildLogCard(docs[index]),
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isSecurity = data.containsKey('severity');
    final action = isSecurity ? 'SECURITY_ALERT' : (data['action'] ?? data['type'] ?? 'ACTIVITY');
    final time = (isSecurity ? (data['timestamp'] as Timestamp?) : (data['updatedAt'] as Timestamp?))?.toDate() ?? DateTime.now();
    final admin = isSecurity ? (data['userId'] ?? 'System') : (data['updatedBy'] ?? 'System');

    IconData icon = Icons.info_outline_rounded;
    Color color = Colors.grey;
    String title = isSecurity ? 'Security Alert' : 'Admin Action';
    String subtitle = isSecurity ? (data['message'] ?? '') : 'Pembaruan sistem terdeteksi.';

    if (isSecurity) {
      final severity = data['severity'] ?? 'low';
      icon = severity == 'critical' ? Icons.security_rounded : Icons.warning_amber_rounded;
      color = (severity == 'critical' || severity == 'high') ? Colors.red : Colors.orange;
      title = '[${data['type'] ?? 'ALERT'}]';
    } else if (action == 'BROADCAST') {
      icon = Icons.campaign_rounded;
      color = AppColors.primary;
      title = data['title'] ?? 'Global Broadcast';
      subtitle = 'Mengirim pesan siaran global.';
    } else if (action == 'MAINTENANCE_TOGGLE') {
      icon = Icons.construction_rounded;
      color = Colors.orange;
      title = 'Maintenance Mode';
      subtitle = 'Status beralih ke: ${data['status'] ?? 'Changed'}';
    } else if (action == 'ROLE_CHANGE') {
      icon = Icons.manage_accounts_rounded;
      color = Colors.purple;
      title = 'Izin Akses';
      subtitle = 'Perubahan hak akses pengguna.';
    } else if (action == 'DELETE_USER') {
      icon = Icons.person_remove_rounded;
      color = Colors.red;
      title = 'Hapus Pengguna';
      subtitle = data['userEmail'] ?? 'User ID Dihapus';
    } else if (action == 'CONFIG_UPDATE') {
      icon = Icons.settings_suggest_rounded;
      color = Colors.blueGrey;
      title = 'Konfigurasi Sistem';
      subtitle = 'Parameter aplikasi diperbarui.';
    } else if (action == 'AI_STATUS_CHANGED') {
      final isEnabled = data['enabled'] ?? false;
      icon = isEnabled ? Icons.power_rounded : Icons.power_off_rounded;
      color = isEnabled ? Colors.green : Colors.red;
      title = 'AI Global Status';
      subtitle = 'AI ${isEnabled ? 'DIAKTIFKAN' : 'DIMATIKAN'} secara global.';
    } else if (action == 'SURVEY_TOGGLED') {
      final isEnabled = data['enabled'] ?? false;
      icon = Icons.thumbs_up_down_rounded;
      color = isEnabled ? Colors.cyan : Colors.blueGrey;
      title = 'Status Survei';
      subtitle = 'Survei kepuasan ${isEnabled ? 'DIBUKA' : 'DITUTUP'}.';
    } else if (action == 'AI_KEY_ADDED') {
      icon = Icons.vpn_key_rounded;
      color = Colors.green;
      title = 'API Key Ditambahkan';
      subtitle = 'Kunci AI baru ditambahkan ke rotasi.';
    } else if (action == 'AI_KEY_REMOVED') {
      icon = Icons.key_off_rounded;
      color = Colors.red;
      title = 'API Key Dihapus';
      subtitle = 'Kunci AI dihapus dari rotasi.';
    } else if (action == 'AI_QUOTA_UPDATE') {
      icon = Icons.psychology_rounded;
      color = const Color(0xFF8B5CF6);
      title = 'AI Quota Diubah';
      subtitle = 'Max: ${data['max_chats'] ?? '?'} chat, Interval: ${data['interval'] ?? '?'} menit';
    } else if (action == 'MAINTENANCE_SCHEDULE') {
      icon = Icons.schedule_rounded;
      color = Colors.indigo;
      title = 'Jadwal Maintenance';
      subtitle = 'Waktu: ${data['time'] ?? 'N/A'}';
    } else if (action == 'GROQ_KEY_ADDED') {
      icon = Icons.bolt_rounded;
      color = const Color(0xFFF55036);
      title = 'Groq Key Ditambahkan';
      subtitle = 'Kunci Groq AI baru ditambahkan ke rotasi.';
    } else if (action == 'GROQ_KEY_REMOVED') {
      icon = Icons.bolt_rounded;
      color = Colors.red;
      title = 'Groq Key Dihapus';
      subtitle = 'Kunci Groq AI dihapus dari rotasi.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogDetail(data, title, icon, color),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormat('HH:mm').format(time),
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person_rounded,
                                    size: 8, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  admin.toString().length > 8
                                      ? admin.toString().substring(0, 8)
                                      : admin,
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('dd/MM/yy').format(time),
                            style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
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
      ),
    );
  }

  void _showLogDetail(
      Map<String, dynamic> data, String title, IconData icon, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              24, 32, 24, MediaQuery.of(context).padding.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                        Text('System Audit Detail',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailGrid(data),
                      const Divider(height: 32),
                      const Text('INTERNAL DATA',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey,
                              letterSpacing: 1)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withOpacity(0.04)),
                        ),
                        child: SelectableText(
                          data.entries
                              .where((e) => !['updatedAt', 'updatedBy', 'action', 'type']
                                  .contains(e.key))
                              .map((e) => '${e.key}: ${e.value}')
                              .join('\n'),
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.blueGrey,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailGrid(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: _buildDetailItem(
                    'ADMIN ID', data['updatedBy'] ?? 'System')),
            Expanded(
                child:
                    _buildDetailItem('KATÉGORI', data['action'] ?? 'General')),
          ],
        ),
        const SizedBox(height: 16),
        _buildDetailItem(
            'WAKTU',
            DateFormat('EEEE, dd MMMM yyyy - HH:mm').format(
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now())),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  void _showClearLogsConfirmation() async {
    final bool? confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Hapus Semua Log?',
      message: 'Tindakan ini akan menghapus seluruh riwayat sistem dan log keamanan secara permanen dari database. Apakah Anda yakin?',
      confirmText: 'HAPUS SEMUA',
      cancelText: 'BATAL',
      isDangerous: true,
    );

    if (confirm == true) {
      _clearAllLogs();
    }
  }

  Future<void> _clearAllLogs() async {
    // Fail-safe security check
    if (!_isSuperAdmin) {
      UIHelper.showErrorSnackBar(context, 'Akses ditolak: Hanya SuperAdmin yang dapat melakukan tindakan ini.');
      return;
    }

    UIHelper.showLoadingDialog(context, message: 'Membersihkan log...');

    try {
      // 1. Clear history collection
      final historySnap = await _firestore
          .collection('app_config')
          .doc('global')
          .collection('history')
          .get();

      final batch = _firestore.batch();
      for (var doc in historySnap.docs) {
        batch.delete(doc.reference);
      }

      // 2. Clear security_logs
      final securitySnap = await _firestore.collection('security_logs').get();
      for (var doc in securitySnap.docs) {
        batch.delete(doc.reference);
      }

      // Execute batch
      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Close loading
        UIHelper.showSuccessSnackBar(context, 'Semua log berhasil dibersihkan.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        UIHelper.showErrorSnackBar(context, 'Gagal membersihkan log: $e');
      }
    }
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.primary : Colors.white,
          foregroundColor: isPrimary ? Colors.white : AppColors.textPrimary,
          elevation: isPrimary ? 2 : 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: Colors.grey[200]!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsFloating() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withOpacity(0),
            AppColors.background.withOpacity(0.8),
            AppColors.background,
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.of(context).padding.bottom + 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.9),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('app_config')
                    .doc('global')
                    .collection('history')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TOTAL AKTIFITAS',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count Log Tercatat',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.analytics_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
