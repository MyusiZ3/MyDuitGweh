import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';

class BroadcastCenterScreen extends StatefulWidget {
  const BroadcastCenterScreen({super.key});

  @override
  State<BroadcastCenterScreen> createState() => _BroadcastCenterScreenState();
}

class _BroadcastCenterScreenState extends State<BroadcastCenterScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  bool _isSending = false;

  void _showBroadcastSuccess() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.rocket_launch_rounded, color: Colors.blue, size: 80),
            ),
            const SizedBox(height: 32),
            const Text('BROADCAST TERKIRIM!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 12),
            const Text('Pesan kamu sudah meluncur ke semua kotak masuk pengguna MyDuitGweh.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('MANTAP JIWA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendToAll() async {
    if (_titleController.text.isEmpty || _msgController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi judul dan pesan dulu Bang!')));
      return;
    }

    setState(() => _isSending = true);

    try {
      final users = await FirebaseFirestore.instance.collection('users').get();
      final batch = FirebaseFirestore.instance.batch();

      for (var user in users.docs) {
        final notifRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('notifications')
            .doc();
            
        batch.set(notifRef, {
          'title': _titleController.text,
          'message': _msgController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'displayCount': 0, // Reset counter untuk user baru
          'type': 'broadcast',
        });
      }

      await batch.commit();
      
      if (mounted) {
        _titleController.clear();
        _msgController.clear();
        _showBroadcastSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Broadcast Center', style: TextStyle(fontWeight: FontWeight.w900)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kirim Pengumuman 📢', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 8),
            const Text('Pesan ini akan langsung muncul di kotak masuk notifikasi seluruh pengguna.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Judul Pengumuman', hintText: 'Misal: Info Maintenance...'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _msgController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Isi Pesan', alignLabelWithHint: true, hintText: 'Tulis pesan lengkapnya di sini...'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_rounded, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('TIPS FORMATTING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blue)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Gunakan **teks** untuk BOLD dan *teks* untuk ITALIC. Pesan akan tampil maksimal 2x sebagai pop-up di HP user.',
                    style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendToAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _isSending 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('KIRIM SEKARANG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
