import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../utils/ui_helper.dart';
import '../widgets/empty_state_widget.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Notifikasi',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.titleLarge?.color)),
        leading: IconButton(
          icon: Icon(CupertinoIcons.chevron_back,
              color: Theme.of(context).iconTheme.color, size: 20),
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
              if (notifSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingWidget());
              }

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
          color: const Color(0xFFF87171).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.delete,
                color: Color(0xFFF87171), size: 22),
            SizedBox(height: 2),
            Text('Hapus',
                style: TextStyle(
                    color: Color(0xFFF87171),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = data['type'] ?? 'info';
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    Color accentColor = const Color(0xFF6366F1); // Brand Periwinkle
    if (type == 'urgent') accentColor = const Color(0xFFF87171); // Pastel Coral
    if (type == 'news') accentColor = const Color(0xFF818CF8); // Pastel Indigo

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.speaker_2_fill, color: accentColor, size: 20),
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
                          color: accentColor.withOpacity(0.15),
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
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMM, HH:mm').format(timestamp),
                    style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withOpacity(0.5),
                        fontSize: 11),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = data['type'] ?? 'info';
    final isRead = data['isRead'] ?? false;
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    final cardBg = isDark ? const Color(0xFF1C1C22) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isRead ? cardBg.withOpacity(0.6) : cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 12,
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
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13,
                            height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('dd MMM, HH:mm').format(timestamp),
                        style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.5),
                            fontSize: 11),
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
                        color: Color(0xFF6366F1), shape: BoxShape.circle),
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
        icon = CupertinoIcons.person_add_solid;
        color = const Color(0xFF6366F1); // Pastel Periwinkle
        break;
      case 'transaction':
        icon = CupertinoIcons.doc_text_fill;
        color = const Color(0xFF34D399); // Pastel Mint
        break;
      default:
        icon = CupertinoIcons.bell_fill;
        color = const Color(0xFF6366F1);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, String docId, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _respondToInvite(context, docId, data, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
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
              side: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.12)),
              foregroundColor: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
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
    return const EmptyStateWidget(
      title: 'Belum Ada Notifikasi',
      subtitle: 'Semua notifikasi transaksi & aktivitas kamu akan muncul di sini.',
      icon: CupertinoIcons.bell_fill,
      paddingVertical: 60,
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
