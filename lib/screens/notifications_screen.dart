import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
import '../widgets/loading_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final FirestoreService _firestoreService = FirestoreService();
  final Set<String> _dismissedBroadcasts = {};

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('dismissed_broadcasts') ?? [];
    if (mounted) setState(() => _dismissedBroadcasts.addAll(list));
  }

  Future<void> _saveDismissed(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _dismissedBroadcasts.add(id);
    await prefs.setStringList(
        'dismissed_broadcasts', _dismissedBroadcasts.toList());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _markAllAsRead(uid);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifikasi',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getBroadcastsStream(),
        builder: (context, broadcastSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, notifSnap) {
              if (notifSnap.connectionState == ConnectionState.waiting)
                return const Center(child: LoadingWidget());

              // Combine and sort
              List<Map<String, dynamic>> allNotifications = [];

              // 1. App Notifications
              if (notifSnap.hasData) {
                for (var doc in notifSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  data['id'] = doc.id;
                  data['isGlobal'] = false;
                  allNotifications.add(data);
                }
              }

              // 2. Global Broadcasts (limit to 10 latest)
              if (broadcastSnap.hasData) {
                for (var b in broadcastSnap.data!) {
                  final bId = b['id'] as String;
                  if (_dismissedBroadcasts.contains(bId)) continue;

                  b['isGlobal'] = true;
                  b['isRead'] = true;
                  allNotifications.add(b);
                }
              }

              // Sort by timestamp
              allNotifications.sort((a, b) {
                final t1 =
                    (a['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                final t2 =
                    (b['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                return t2.compareTo(t1);
              });

              if (allNotifications.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: allNotifications.length,
                itemBuilder: (context, index) {
                  final data = allNotifications[index];
                  final id = data['id'];
                  final isGlobal = data['isGlobal'] ?? false;

                  final child = isGlobal
                      ? _buildGlobalNotificationCard(context, id, data)
                      : _buildNotificationCard(context, id, data);

                  return _buildSwipeable(
                    id: isGlobal ? 'global_$id' : id,
                    child: child,
                    onDismissed: () {
                      if (isGlobal) {
                        _saveDismissed(id);
                      } else {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('notifications')
                            .doc(id)
                            .delete();
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSwipeable({
    required String id,
    required Widget child,
    required VoidCallback onDismissed,
  }) {
    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.3},
      movementDuration: const Duration(milliseconds: 200),
      onDismissed: (_) => onDismissed(),
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: AppColors.expense, size: 22),
            const SizedBox(height: 2),
            Text('Hapus',
                style: TextStyle(
                    color: AppColors.expense,
                    fontSize: 9,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildGlobalNotificationCard(
      BuildContext context, String id, Map<String, dynamic> data) {
    final type = data['type'] ?? 'info';
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    Color accentColor = AppColors.primary;
    if (type == 'urgent') accentColor = Colors.orange[800]!;
    if (type == 'news') accentColor = Colors.deepPurple;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['title'] ?? 'System Alert',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: accentColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'GLOBAL',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: accentColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['message'] ?? '',
                    style: TextStyle(
                        color: AppColors.textHint, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMM, HH:mm').format(timestamp),
                    style: const TextStyle(color: Colors.black26, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, String docId, Map<String, dynamic> data) {
    final type = data['type'] ?? 'info'; // 'invite', 'transaction', 'info'
    final isRead = data['isRead'] ?? false;
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

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
                          fontWeight:
                              isRead ? FontWeight.bold : FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['message'] ?? '',
                        style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 13,
                            height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM, HH:mm').format(timestamp),
                        style: const TextStyle(
                            color: Colors.black26, fontSize: 11),
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
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
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

  Widget _buildActionButtons(
      BuildContext context, String docId, Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _respondToInvite(context, docId, data, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Terima',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _respondToInvite(context, docId, data, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.expense),
              foregroundColor: AppColors.expense,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Tolak',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
          Icon(Icons.notifications_off_rounded,
              size: 80, color: Colors.black12),
          const SizedBox(height: 16),
          const Text('Belum ada notifikasi',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black26)),
        ],
      ),
    );
  }

  void _handleNotificationTap(
      BuildContext context, String docId, Map<String, dynamic> data) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  Future<void> _respondToInvite(BuildContext context, String docId,
      Map<String, dynamic> data, bool accept) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final walletId = data['walletId'];

    try {
      if (accept) {
        // Logic tambah user ke wallet
        await FirebaseFirestore.instance
            .collection('wallets')
            .doc(walletId)
            .update({
          'members': FieldValue.arrayUnion([uid])
        });
        UIHelper.showSuccessSnackBar(
            context, 'Berhasil bergabung dengan dompet!');
      } else {
        UIHelper.showSuccessSnackBar(context, 'Undangan ditolak.');
      }

      // Update status notifikasi
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(docId)
          .update({'status': accept ? 'accepted' : 'rejected', 'isRead': true});
    } catch (e) {
      UIHelper.showErrorSnackBar(context, 'Gagal menanggapi undangan.');
    }
  }

  void _markAllAsRead(String? uid) async {
    if (uid == null) return;
    final unread = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
