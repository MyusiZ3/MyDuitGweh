import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../utils/ui_helper.dart';
import '../../services/auth_service.dart';

class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  bool _isSuperAdmin = false;
  bool _maintenanceMode = false;
  final TextEditingController _minVersionController = TextEditingController();
  final TextEditingController _maintenanceMsgController =
      TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _checkSuperAdmin();
  }

  Future<void> _checkSuperAdmin() async {
    final isSuper = await _authService.isSuperAdmin();
    if (mounted) {
      setState(() {
        _isSuperAdmin = isSuper;
      });
    }
  }

  Future<void> _loadConfig() async {
    try {
      final configDoc = await _firestore.collection('app_config').doc('global').get();
      if (configDoc.exists) {
        final data = configDoc.data()!;
        setState(() {
          _maintenanceMode = data['isMaintenance'] ?? false;
          _minVersionController.text = data['minVersion'] ?? '1.0.0';
          _maintenanceMsgController.text = data['maintenanceMessage'] ??
              'Aplikasi sedang dalam pemeliharaan rutin.';
          _startTime = (data['maintenanceStartTime'] as Timestamp?)?.toDate();
          _endTime = (data['maintenanceEndTime'] as Timestamp?)?.toDate();
        });
      }
    } catch (e) {
      debugPrint("Gagal load config: $e");
    }
  }

  Future<void> _selectDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          final dt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startTime = dt;
          } else {
            _endTime = dt;
          }
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);

    final batch = _firestore.batch();
    final configRef = _firestore.collection('app_config').doc('global');
    final historyRef = configRef.collection('history').doc();

    final Map<String, dynamic> configData = {
      'isMaintenance': _maintenanceMode,
      'minVersion': _minVersionController.text,
      'maintenanceMessage': _maintenanceMsgController.text,
      'maintenanceStartTime':
          _startTime != null ? Timestamp.fromDate(_startTime!) : null,
      'maintenanceEndTime':
          _endTime != null ? Timestamp.fromDate(_endTime!) : null,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    batch.set(configRef, configData, SetOptions(merge: true));

    // Determine log action based on what changed
    String logAction = 'CONFIG_UPDATE';
    if (_maintenanceMode) {
      logAction = 'MAINTENANCE_TOGGLE';
    }

    batch.set(historyRef, {
      ...configData,
      'updatedAt': FieldValue.serverTimestamp(),
      'action': logAction,
      'updatedBy': _authService.auth.currentUser?.uid ?? 'system',
    });

    await batch.commit();

    setState(() => _isSaving = false);
    if (mounted) {
      _showSuccessSheet();
    }
  }

  Future<void> _clearHistory({DocumentReference? singleDoc}) async {
    final isSingle = singleDoc != null;
    final confirmed = await UIHelper.showConfirmDialog(
      context: context,
      title: isSingle ? 'Hapus Histori Ini?' : 'Clear Semua History?',
      message: isSingle
          ? 'Data konfigurasi ini akan dihapus permanen.'
          : 'Hapus seluruh histori konfigurasi aplikasi? Tindakan ini tidak bisa dibatalkan.',
    );

    if (confirmed == true) {
      try {
        if (isSingle) {
          await singleDoc.delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Item histori dihapus.')));
          }
        } else {
          final snapshot = await _firestore
              .collection('app_config')
              .doc('global')
              .collection('history')
              .get();
          final batch = _firestore.batch();
          for (var doc in snapshot.docs) {
            final docData = doc.data();
            final action = docData['action'] ?? docData['type'] ?? '';
            if (action == 'CONFIG_UPDATE') {
              batch.delete(doc.reference);
            }
          }
          await batch.commit();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Semua histori dihapus.')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal menghapus histori: $e')));
        }
      }
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text('Config Updated!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                  'Semua perubahan berhasil disimpan dan tercatat di histori.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('SIP!'))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('App Config'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).padding.bottom + 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Parameters',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
            const SizedBox(height: 24),
            _buildConfigTile(),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Change History',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                if (_isSuperAdmin)
                  TextButton.icon(
                    onPressed: () => _clearHistory(),
                    icon: const Icon(Icons.delete_sweep_rounded,
                        size: 16, color: Colors.redAccent),
                    label: const Text('Clear All',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHistoryList(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3))
                  : const Text('SAVE CONFIG',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigTile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Status Maintenance',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Aktifkan manual atau biarkan jadwal berjalan.',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ])),
              Switch.adaptive(
                  value: _maintenanceMode,
                  activeColor: Colors.redAccent,
                  onChanged: (v) => setState(() => _maintenanceMode = v)),
            ],
          ),
          const Divider(height: 32),
          TextField(
            controller: _maintenanceMsgController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Pesan Maintenance',
              hintText: 'Misal: Maaf ya, lagi benerin pipa bocor...',
              prefixIcon: Icon(Icons.message_rounded),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTimePicker(
                  label: 'Start Schedule',
                  value: _startTime,
                  onTap: () => _selectDateTime(true),
                  onClear: () => setState(() => _startTime = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTimePicker(
                  label: 'End Schedule',
                  value: _endTime,
                  onTap: () => _selectDateTime(false),
                  onClear: () => setState(() => _endTime = null),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          TextField(
            controller: _minVersionController,
            decoration: const InputDecoration(
              labelText: 'Update Paksa vMin',
              hintText: '1.0.0',
              prefixIcon: Icon(Icons.verified_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14,
                    color: value != null ? AppColors.primary : Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value != null
                        ? DateFormat('dd MMM, HH:mm').format(value)
                        : '--:--',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: value != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.redAccent),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('app_config')
          .doc('global')
          .collection('history')
          .orderBy('updatedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        // Only show CONFIG_UPDATE entries in this screen's history
        final configDocs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final action = d['action'] ?? d['type'] ?? '';
          return action == 'CONFIG_UPDATE' || action == 'MAINTENANCE_TOGGLE';
        }).toList();

        if (configDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('Belum ada perubahan config.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: configDocs.length,
          itemBuilder: (context, index) {
            final doc = configDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final DateTime date =
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final start =
                (data['maintenanceStartTime'] as Timestamp?)?.toDate();
            final end = (data['maintenanceEndTime'] as Timestamp?)?.toDate();
            final maintenanceEnabled = data['isMaintenance'] ?? false;

            String status = 'INACTIVE';
            Color statusColor = Colors.grey;

            if (maintenanceEnabled) {
              final now = DateTime.now();
              if (start != null && end != null) {
                if (now.isBefore(start)) {
                  status = 'PENDING';
                  statusColor = Colors.orange;
                } else if (now.isAfter(end)) {
                  status = 'END';
                  statusColor = Colors.red;
                } else {
                  status = 'ONGOING';
                  statusColor = Colors.green;
                }
              } else if (start != null) {
                if (now.isBefore(start)) {
                  status = 'PENDING';
                  statusColor = Colors.orange;
                } else {
                  status = 'ONGOING';
                  statusColor = Colors.green;
                }
              } else {
                status = 'ONGOING';
                statusColor = Colors.green;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.settings_backup_restore_rounded,
                      size: 20, color: statusColor),
                ),
                title: Row(
                  children: [
                    Text('v${data['minVersion']}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(data['maintenanceMessage'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(DateFormat('dd MMM HH:mm').format(date),
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
                trailing: _isSuperAdmin
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.redAccent),
                        onPressed: () =>
                            _clearHistory(singleDoc: doc.reference),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
