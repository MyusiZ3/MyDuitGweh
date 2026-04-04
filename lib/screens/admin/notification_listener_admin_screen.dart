import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/notif_listener_bridge.dart';
import '../../utils/app_theme.dart';

class NotificationListenerAdminScreen extends StatefulWidget {
  const NotificationListenerAdminScreen({super.key});

  @override
  State<NotificationListenerAdminScreen> createState() => _NotificationListenerAdminScreenState();
}

class _NotificationListenerAdminScreenState extends State<NotificationListenerAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isGlobalEnabled = false;
  int _syncInterval = 60;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGlobalConfig();
  }

  Future<void> _loadGlobalConfig() async {
    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('notification_listener')
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _isGlobalEnabled = doc.data()?['isEnabled'] ?? false;
        _syncInterval = doc.data()?['syncInterval'] ?? 60;
      });
    }
  }

  Future<void> _toggleGlobal(bool val) async {
    setState(() => _isSaving = true);
    try {
      await NotifListenerBridge.updateGlobalConfig(val, syncInterval: _syncInterval);
      setState(() => _isGlobalEnabled = val);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fitur Global: ${val ? 'AKTIF' : 'NON-AKTIF'}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Notification Control', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Konfigurasi'),
            Tab(text: 'Log User'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfigTab(),
          _buildUserLogsTab(),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionHeader('STATUS FITUR GLOBAL'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: SwitchListTile(
            title: Text('Aktifkan untuk Semua User', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            subtitle: Text('Jika mati, banner izin di Home Screen user akan hilang.', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
            value: _isGlobalEnabled,
            onChanged: _isSaving ? null : _toggleGlobal,
            activeColor: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('PENGATURAN SYNC'),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Interval Sinkronisasi (Menit)', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _syncInterval,
                  items: [15, 30, 60, 180, 360].map((i) => DropdownMenuItem(value: i, child: Text('$i Menit'))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _syncInterval = val);
                      if (_isGlobalEnabled) _toggleGlobal(true);
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Catatan: Sistem menggunakan Workmanager Android. Interval minimum OS adalah 15 menit.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserLogsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final users = snapshot.data!.docs;
        if (users.isEmpty) return const Center(child: Text('Belum ada data user.'));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final name = userData['displayName'] ?? userData['email'] ?? 'User Tanpa Nama';

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: TextStyle(color: AppColors.primary)),
                ),
                title: Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                subtitle: Text('ID: $userId', style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showUserLogDetail(userId, name),
              ),
            );
          },
        );
      },
    );
  }

  void _showUserLogDetail(String userId, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(child: Text('Log Notifikasi: $name', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('captured_notifications')
                      .orderBy('timestamp', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final logs = snap.data!.docs;
                    if (logs.isEmpty) return const Center(child: Text('User ini belum mengirim log.'));

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final log = logs[i].data() as Map<String, dynamic>;
                        final ts = log['timestamp'];
                        final time = (ts is Timestamp) ? ts.toDate() : DateTime.now();
                        final package = log['package']?.toString().toLowerCase() ?? '';
                        final isWA = package.contains('whatsapp');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(isWA ? Icons.message : Icons.sms, size: 16, color: isWA ? Colors.green : Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(log['title'] ?? 'Tanpa Judul', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  Text(DateFormat('dd MMM, HH:mm').format(time), style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(log['body'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('App: $package', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600, letterSpacing: 1.2));
  }
}
