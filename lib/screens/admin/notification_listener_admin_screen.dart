import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/notif_listener_bridge.dart';
import '../../utils/app_theme.dart';
import '../../utils/ui_helper.dart';

class NotificationListenerAdminScreen extends StatefulWidget {
  const NotificationListenerAdminScreen({super.key});

  @override
  State<NotificationListenerAdminScreen> createState() =>
      _NotificationListenerAdminScreenState();
}

class _NotificationListenerAdminScreenState
    extends State<NotificationListenerAdminScreen>
    with SingleTickerProviderStateMixin {
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
      await NotifListenerBridge.updateGlobalConfig(val,
          syncInterval: _syncInterval);
      setState(() => _isGlobalEnabled = val);
        UIHelper.showSuccessSnackBar(context, 'Fitur Global: ${val ? 'AKTIF' : 'NON-AKTIF'}');
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
        title: Text('Notification Control',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200)),
          child: SwitchListTile(
            title: Text('Aktifkan untuk Semua User',
                style:
                    GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Jika mati, banner izin di Home Screen user akan hilang.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12)),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Interval Sinkronisasi (Menit)',
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _syncInterval,
                  items: [15, 30, 60, 180, 360]
                      .map((i) =>
                          DropdownMenuItem(value: i, child: Text('$i Menit')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _syncInterval = val);
                      if (_isGlobalEnabled) _toggleGlobal(true);
                    }
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Catatan: Sistem menggunakan Workmanager Android. Interval minimum OS adalah 15 menit.',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: Colors.grey),
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
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!.docs;
        if (users.isEmpty)
          return const Center(child: Text('Belum ada data user.'));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final name = userData['displayName'] ??
                userData['email'] ??
                'User Tanpa Nama';

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(color: AppColors.primary)),
                ),
                title: Text(name,
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold)),
                subtitle: Text('ID: $userId',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11)),
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
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text('Log Notifikasi: $name',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold))),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _triggerRemoteSync(userId),
                            label: const Text('Force Sync'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmDeleteAllLogs(userId),
                            label: const Text('Delete All'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('captured_notifications')
                      .orderBy('receivedAt', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final logs = snap.data!.docs;
                    if (logs.isEmpty)
                      return const Center(
                          child: Text('User ini belum mengirim log.'));

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: logs.length,
                      itemBuilder: (context, i) {
                        final logDoc = logs[i];
                        final log = logDoc.data() as Map<String, dynamic>;
                        // Prioritas: receivedAt (Timestamp) > timestamp (int ms) > capturedAt
                        DateTime time;
                        if (log['receivedAt'] is Timestamp) {
                          time = (log['receivedAt'] as Timestamp).toDate();
                        } else if (log['timestamp'] is int) {
                          time = DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int);
                        } else if (log['timestamp'] is Timestamp) {
                          time = (log['timestamp'] as Timestamp).toDate();
                        } else {
                          time = (log['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                        }
                        final package =
                            log['package']?.toString().toLowerCase() ?? '';
                        final isWA = package.contains('whatsapp');

                        return Dismissible(
                          key: Key(logDoc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          onDismissed: (_) {
                            logDoc.reference.delete();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showLogDetailPopup(log),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(isWA ? Icons.message : Icons.sms,
                                              size: 16,
                                              color: isWA
                                                  ? const Color.fromARGB(
                                                      255, 154, 154, 154)
                                                  : Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                                  log['title'] ?? 'Tanpa Judul',
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13),
                                                  overflow:
                                                      TextOverflow.ellipsis)),
                                          Text(
                                              DateFormat('dd MMM, HH:mm')
                                                  .format(time),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                      fontSize: 10,
                                                      color: Colors.grey)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(log['text'] ?? log['body'] ?? '',
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text('App: $package',
                                          style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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

  Future<void> _triggerRemoteSync(String userId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notif_config')
        .doc('sync')
        .set({'forceSync': true}, SetOptions(merge: true));

    if (mounted) {
      UIHelper.showSuccessSnackBar(context, 'Permintaan sync terkirim. Jika App tujuan aktif, log akan segera muncul.');
    }
  }

  Future<void> _confirmDeleteAllLogs(String userId) async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Hapus Semua Log?',
      message:
          'Semua log notifikasi lokal yang tersimpan di Firebase untuk user ini akan dihapus. Lanjutkan?',
      confirmText: 'Hapus Semua',
      isDangerous: true,
    );

    if (confirm == true) {
      final logsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('captured_notifications');
      final snapshots = await logsRef.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        UIHelper.showSuccessSnackBar(context, '${snapshots.docs.length} log berhasil dihapus.');
      }
    }
  }

  void _showLogDetailPopup(Map<String, dynamic> log) {
    // Prioritas: receivedAt (Timestamp) > timestamp (int ms) > capturedAt
    DateTime time;
    if (log['receivedAt'] is Timestamp) {
      time = (log['receivedAt'] as Timestamp).toDate();
    } else if (log['timestamp'] is int) {
      time = DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int);
    } else if (log['timestamp'] is Timestamp) {
      time = (log['timestamp'] as Timestamp).toDate();
    } else {
      time = (log['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    }
    final syncTime = (log['capturedAt'] as Timestamp?)?.toDate();
    UIHelper.showPremiumDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  log['title'] ?? 'Detail Pesan',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'App: ${log['package']}',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600),
          ),
          Text(
            'Waktu Diterima: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(time)}',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600),
          ),
          if (syncTime != null)
            Text(
              'Synced: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(syncTime)}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: Colors.grey.shade400),
            ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: Text(
                log['text'] ?? log['body'] ?? 'Tidak ada pesan',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, height: 1.5, color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text('Tutup',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
            letterSpacing: 1.2));
  }
}
