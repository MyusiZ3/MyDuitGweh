import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/ui_helper.dart';

class BroadcastCenterScreen extends StatefulWidget {
  const BroadcastCenterScreen({super.key});

  @override
  State<BroadcastCenterScreen> createState() => _BroadcastCenterScreenState();
}

class _BroadcastCenterScreenState extends State<BroadcastCenterScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  String _selectedType = 'info'; // info, urgent, news
  DateTime? _scheduledTime;
  bool _isSending = false;

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _scheduledTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  void _showPreview() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final urgentColor = isDark ? Colors.orangeAccent : Colors.orange[800]!;
        final newsColor = isDark ? Colors.purpleAccent : Colors.deepPurple;
        final infoColor = AppColors.primary;

        final effectiveColor = _selectedType == 'urgent'
            ? urgentColor
            : _selectedType == 'news'
                ? newsColor
                : infoColor;

        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 15)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 24),
                    Icon(
                      _selectedType == 'urgent'
                          ? Icons.priority_high_rounded
                          : _selectedType == 'news'
                              ? Icons.auto_awesome_rounded
                              : Icons.info_rounded,
                      color: effectiveColor,
                      size: 32,
                    ),
                    const SizedBox(height: 16),
                    Text(_titleController.text.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: effectiveColor,
                            decoration: TextDecoration.none)),
                    const SizedBox(height: 12),
                    Material(
                        color: Colors.transparent,
                        child: Text(_msgController.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textSecondary,
                                height: 1.5,
                                decoration: TextDecoration.none))),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text('OK, PREVIEW TUTUP',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  fontSize: 13,
                                  decoration: TextDecoration.none)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBroadcastSuccess() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            40, 48, 40, MediaQuery.of(ctx).padding.bottom + 48),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  color: Colors.blue, size: 48),
            ),
            const SizedBox(height: 32),
            const Text('BROADCAST TERJADWAL!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1)),
            const SizedBox(height: 12),
            const Text(
                'Pesan kamu sudah masuk sistem histori dan akan meluncur otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('MANTAP',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBroadcast() async {
    if (_titleController.text.isEmpty || _msgController.text.isEmpty) {
      UIHelper.showErrorSnackBar(
          context, 'Judul dan pesan tidak boleh kosong.');
      return;
    }

    if (!mounted) return;

    final bool? confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Luncurkan Pesan?',
      message: 'Pesan akan dikirim ke SELURUH user MyDuitGweh. Lanjut?',
      confirmText: 'Luncurkan!',
      cancelText: 'Batal',
    );

    if (confirm != true) return;

    setState(() => _isSending = true);
    print('--- BroadcastCenter: Starting send process...');

    try {
      await _firestoreService.sendGlobalBroadcast(
        title: _titleController.text.trim(),
        message: _msgController.text.trim(),
        type: _selectedType,
        scheduledTime: _scheduledTime,
      );

      print('--- BroadcastCenter: Firestore document created.');

      if (mounted) {
        _titleController.clear();
        _msgController.clear();
        setState(() {
          _scheduledTime = null;
          _isSending = false; // Reset early before success sheet
        });

        // Final check before showing success
        if (context.mounted) {
          _showBroadcastSuccess();
        }
      }
    } catch (e) {
      print('--- BroadcastCenter: Error in _sendBroadcast: $e');
      if (mounted) {
        UIHelper.showErrorSnackBar(context, 'Gagal: $e');
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Broadcast Center',
            style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: (_titleController.text.isNotEmpty &&
                    _msgController.text.isNotEmpty)
                ? _showPreview
                : null,
            icon: const Icon(Icons.remove_red_eye_rounded),
            tooltip: 'Preview Tampilan',
          )
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kirim Pengumuman',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2)),
                  const SizedBox(height: 8),
                  const Text(
                      'Gunakan fitur ini untuk mengirimkan pengumuman penting ke seluruh ekosistem MyDuitGweh.',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 32),
                  _buildInputLabel('TIPE BROADCAST'),
                  Row(
                    children: [
                      _buildTypeButton(
                          'info', Icons.info_outline_rounded, Colors.blue),
                      const SizedBox(width: 8),
                      _buildTypeButton(
                          'news', Icons.auto_awesome_rounded, Colors.purple),
                      const SizedBox(width: 8),
                      _buildTypeButton(
                          'urgent', Icons.priority_high_rounded, Colors.orange),
                      const SizedBox(width: 8),
                      _buildTypeButton(
                          'reminder', Icons.alarm_rounded, Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInputLabel('QUICK TEMPLATES'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTemplateChip(
                            '📔 Jurnal Harian',
                            'Sudah catat pengeluaran hari ini?',
                            'Ayo disiplinkan keuanganmu dengan mencatat setiap transaksi sekarang!'),
                        const SizedBox(width: 8),
                        _buildTemplateChip(
                            '🚀 Update Fitur',
                            'Fitur Baru Hadir!',
                            'Cek fitur terbaru MyDuitGweh yang bikin hidup kamu makin gampang!'),
                        const SizedBox(width: 8),
                        _buildTemplateChip(
                            '⚠️ Maintenance',
                            'Sistem Diperbaiki',
                            'Kami sedang melakukan pemeliharaan rutin untuk kenyamanan Anda.'),
                        const SizedBox(width: 8),
                        _buildTemplateChip(
                            '🤖 AI Advisor Limit',
                            '💡 Tips: AI Advisor Lancar Jaya!',
                            'Wah, jatah chat AI global lagi rame nih! Biar chat kamu tetep lancar tanpa antri limit, yuk masukkan **API Key Pribadi** kamu di menu **Kelola AI**. Gratis & Unlimited lho! 🚀'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInputLabel('JUDUL PENGUMUMAN'),
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        hintText: 'Misal: Fitur Baru Telah Hadir!'),
                  ),
                  const SizedBox(height: 24),
                  _buildInputLabel('ISI PESAN'),
                  TextField(
                    controller: _msgController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Tulis pesan lengkapnya di sini. Gunakan **teks** untuk tebal...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInputLabel('JADWAL KIRIM (OPSIONAL)'),
                  InkWell(
                    onTap: _selectDateTime,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            _scheduledTime == null
                                ? 'Kirim Sekarang'
                                : DateFormat('dd MMM, HH:mm')
                                    .format(_scheduledTime!),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Spacer(),
                          if (_scheduledTime != null)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () =>
                                  setState(() => _scheduledTime = null),
                            )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text('History & Logs',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // History Stream
          SliverToBoxAdapter(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getBroadcastsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: CircularProgressIndicator(),
                  ));
                }
                final logs = snapshot.data!;
                if (logs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                        child: Text('Belum ada riwayat broadcast.',
                            style: TextStyle(color: Colors.grey))),
                  );
                }
                return Column(
                  children: logs.map((b) => _buildLogTile(b)).toList(),
                );
              },
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
              top: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: _isSending
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 3))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rocket_launch_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('LUNCURKAN PESAN',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String type, IconData icon, Color color) {
    bool isSelected = _selectedType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? Colors.white38 : Colors.black38;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected
                    ? color
                    : Theme.of(context).dividerColor.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white70 : unselectedColor),
                  size: 20),
              const SizedBox(height: 4),
              Text(type.toUpperCase(),
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : unselectedColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> b) {
    final type = b['type'] ?? 'info';

    final String status = b['status'] ?? 'ONGOING';
    Color statusColor = Colors.blue;

    if (status == 'PENDING') statusColor = Colors.amber;
    if (status == 'END') statusColor = Colors.grey;
    if (status == 'ONGOING') statusColor = Colors.green;

    final time = (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color typeColor = Colors.blue;
    if (type == 'urgent') typeColor = Colors.orange;
    if (type == 'news') typeColor = Colors.purple;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: statusColor)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(type.toUpperCase(),
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: typeColor)),
              ),
              const Spacer(),
              Text(DateFormat('dd MMM, HH:mm').format(time),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              if (status == 'ongoing')
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined,
                      size: 16, color: Colors.orange),
                  tooltip: 'Akhiri Broadcast',
                  onPressed: () async {
                    final confirm = await UIHelper.showConfirmDialog(
                      context: context,
                      title: 'Akhiri Broadcast?',
                      message:
                          'Status broadcast akan diubah menjadi END dan tidak akan muncul lagi di beranda user.',
                      confirmText: 'Akhiri',
                    );
                    if (confirm == true) {
                      await _firestoreService.endBroadcast(b['id']);
                      if (mounted) {
                        UIHelper.showSuccessSnackBar(
                            context, 'Broadcast berhasil diakhiri.');
                      }
                    }
                  },
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: Colors.grey),
                onPressed: () async {
                  final confirm = await UIHelper.showConfirmDialog(
                    context: context,
                    title: 'Hapus Broadcast?',
                    message:
                        'Ini akan menghapus broadcast dari riwayat sistem secara permanen.',
                    confirmText: 'Hapus',
                    isDangerous: true,
                  );
                  if (confirm == true) {
                    await _firestoreService.deleteBroadcast(b['id']);
                    if (mounted) {
                      UIHelper.showSuccessSnackBar(
                          context, 'Broadcast dihapus.');
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(b['title'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis),
          Text(b['message'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 1.5)),
    );
  }

  Widget _buildTemplateChip(String label, String title, String msg) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: () {
          setState(() {
            _titleController.text = title;
            _msgController.text = msg;
            if (label.contains('📔')) _selectedType = 'reminder';
            if (label.contains('🚀')) _selectedType = 'news';
            if (label.contains('⚠️')) _selectedType = 'urgent';
            if (label.contains('🤖')) _selectedType = 'info';
          });
        },
        label: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color)),
        backgroundColor: Theme.of(context).cardColor,
        side:
            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
    );
  }
}
