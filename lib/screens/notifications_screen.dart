import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
import '../widgets/loading_widget.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifikasi',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: LoadingWidget());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildNotificationCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final type = data['type'] ?? 'info'; // 'invite', 'transaction', 'info'
    final isRead = data['isRead'] ?? false;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white.withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _handleNotificationTap(context, docId, data),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(type),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'Notifikasi',
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['message'] ?? '',
                        style: TextStyle(color: AppColors.textHint, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM, HH:mm').format(timestamp),
                        style: const TextStyle(color: Colors.black26, fontSize: 11),
                      ),
                      if (type == 'invite' && data['status'] == 'pending') ...[
                        const SizedBox(height: 16),
                        _buildActionButtons(context, docId, data),
                      ]
                    ],
                  ),
                ),
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'invite':
        icon = Icons.group_add_rounded;
        color = AppColors.deepBlue;
        break;
      case 'transaction':
        icon = Icons.receipt_long_rounded;
        color = AppColors.income;
        break;
      default:
        icon = Icons.notifications_rounded;
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildActionButtons(BuildContext context, String docId, Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _respondToInvite(context, docId, data, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Terima', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _respondToInvite(context, docId, data, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.expense),
              foregroundColor: AppColors.expense,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: 80, color: Colors.black12),
          const SizedBox(height: 16),
          const Text('Belum ada notifikasi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black26)),
        ],
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, String docId, Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  Future<void> _respondToInvite(BuildContext context, String docId, Map<String, dynamic> data, bool accept) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final walletId = data['walletId'];
    
    try {
      if (accept) {
        // Logic tambah user ke wallet
        await FirebaseFirestore.instance.collection('wallets').doc(walletId).update({
          'collaborators': FieldValue.arrayUnion([uid])
        });
        UIHelper.showSuccessSnackBar(context, 'Berhasil bergabung dengan dompet!');
      } else {
        UIHelper.showSuccessSnackBar(context, 'Undangan ditolak.');
      }

      // Update status notifikasi
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(docId)
          .update({
            'status': accept ? 'accepted' : 'rejected',
            'isRead': true
          });
          
    } catch (e) {
      UIHelper.showErrorSnackBar(context, 'Gagal menanggapi undangan.');
    }
  }
}
