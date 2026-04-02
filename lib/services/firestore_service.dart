import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/chat_message_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateProfessionalId(String prefix) {
    final now = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random =
        List.generate(4, (index) => chars[Random().nextInt(chars.length)])
            .join();
    return '$prefix-$now-$random';
  }

  Stream<List<WalletModel>> getWalletsStream(String uid) {
    return _firestore
        .collection('wallets')
        .where('members', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  Stream<List<WalletModel>> getPersonalWalletsStream(String uid) {
    return _firestore
        .collection('wallets')
        .where('members', arrayContains: uid)
        .where('type', isEqualTo: 'personal')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  Stream<List<WalletModel>> getColabWalletsStream(String uid) {
    return _firestore
        .collection('wallets')
        .where('members', arrayContains: uid)
        .where('type', isEqualTo: 'colab')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  Future<String> createWallet(WalletModel wallet) async {
    final customId = _generateProfessionalId('WLT');
    final docRef = _firestore.collection('wallets').doc(customId);
    String? inviteCode;
    if (wallet.type == 'colab') inviteCode = _generateInviteCode();
    await docRef
        .set(wallet.copyWith(id: customId, inviteCode: inviteCode).toJson());
    return customId;
  }

  Future<void> deleteWallet(String walletId) async {
    final transactions = await _firestore
        .collection('transactions')
        .where('walletId', isEqualTo: walletId)
        .get();
    final batch = _firestore.batch();
    for (var doc in transactions.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('wallets').doc(walletId));
    await batch.commit();
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)])
        .join();
  }

  Future<bool> joinWalletByCode(String code, String uid) async {
    try {
      final query = await _firestore
          .collection('wallets')
          .where('inviteCode', isEqualTo: code.toUpperCase().trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return false;

      final doc = query.docs.first;
      final members = List<String>.from(doc.data()['members'] ?? []);

      if (members.contains(uid)) return true;

      await doc.reference.update({
        'members': FieldValue.arrayUnion([uid])
      });
      return true;
    } catch (e) {
      debugPrint('Join error: $e');
      return false;
    }
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final customTxId = _generateProfessionalId('TX');
    final batch = _firestore.batch();

    final walletRef =
        _firestore.collection('wallets').doc(transaction.walletId);
    final transactionRef =
        _firestore.collection('transactions').doc(customTxId);

    batch.set(transactionRef, transaction.copyWith(id: customTxId).toJson());

    final incrementVal =
        transaction.isIncome ? transaction.amount : -transaction.amount;
    batch.update(walletRef, {'balance': FieldValue.increment(incrementVal)});

    await batch.commit();
  }

  Stream<List<TransactionModel>> getAllTransactionsStream(
      List<String> walletIds) {
    if (walletIds.isEmpty) return Stream.value([]);
    return _firestore
        .collection('transactions')
        .where('walletId', whereIn: walletIds.take(30).toList())
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  Stream<List<TransactionModel>> getFilteredTransactionsStream({
    required List<String> walletIds,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    if (walletIds.isEmpty) return Stream.value([]);
    final start =
        DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return _firestore
        .collection('transactions')
        .where('walletId', whereIn: walletIds.take(30).toList())
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  Future<List<TransactionModel>> getFilteredTransactions({
    required List<String> walletIds,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categories,
  }) async {
    if (walletIds.isEmpty) return [];
    final start =
        DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    Query query = _firestore
        .collection('transactions')
        .where('walletId', whereIn: walletIds.take(30).toList())
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
    if (categories != null &&
        categories.isNotEmpty &&
        !categories.contains('All')) {
      query = query.where('category', whereIn: categories.take(30).toList());
    }
    query = query.orderBy('date', descending: true);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromJson(
            doc.data() as Map<String, dynamic>,
            docId: doc.id))
        .toList();
  }

  Stream<List<TransactionModel>> getTransactionsStream(String walletId) {
    return _firestore
        .collection('transactions')
        .where('walletId', isEqualTo: walletId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    final batch = _firestore.batch();

    final walletRef =
        _firestore.collection('wallets').doc(transaction.walletId);
    final transactionRef =
        _firestore.collection('transactions').doc(transaction.id);

    batch.delete(transactionRef);

    final incrementVal =
        transaction.isIncome ? -transaction.amount : transaction.amount;
    batch.update(walletRef, {'balance': FieldValue.increment(incrementVal)});

    await batch.commit();
  }

  Future<bool> addMemberByEmail(String walletId, String email) async {
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (userQuery.docs.isEmpty) return false;
    final memberUid = userQuery.docs.first.id;

    // Jangan langsung di-add ke members, kita kirimkan NOTIFIKASI UNDANGAN:
    final currentUser = FirebaseAuth.instance.currentUser;
    final senderName = currentUser?.displayName ?? 'Seseorang';

    final walletDoc =
        await _firestore.collection('wallets').doc(walletId).get();
    final walletName = walletDoc.data() != null
        ? (walletDoc.data()!['walletName'] ?? 'Dompet Kolaborasi')
        : 'Dompet Kolaborasi';

    await _firestore
        .collection('users')
        .doc(memberUid)
        .collection('notifications')
        .add({
      'type': 'invite',
      'title': 'Undangan Kolaborasi',
      'message':
          '$senderName mengundangmu untuk bergabung ke dompet "$walletName"',
      'status': 'pending',
      'walletId': walletId,
      'isRead': false,
      'senderUid': currentUser?.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return true;
  }

  Future<Map<String, dynamic>?> getUserInfo(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> leaveWallet(String walletId, String uid) async {
    await _firestore.collection('wallets').doc(walletId).update({
      'members': FieldValue.arrayRemove([uid])
    });
  }

  // ══════════════════════════════════════════════════
  // CHAT KOLABORASI
  // ══════════════════════════════════════════════════

  Stream<List<ChatMessage>> getMessagesStream(String walletId) {
    return _firestore
        .collection('wallets')
        .doc(walletId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  Future<void> sendMessage({
    required String walletId,
    required String senderUid,
    required String senderName,
    required String message,
  }) async {
    await _firestore
        .collection('wallets')
        .doc(walletId)
        .collection('messages')
        .add({
      'senderUid': senderUid,
      'senderName': senderName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isEdited': false,
      'isDeleted': false,
    });
  }

  /// Edit a chat message (mark as edited, update text)
  Future<void> editMessage({
    required String walletId,
    required String messageId,
    required String newMessage,
  }) async {
    await _firestore
        .collection('wallets')
        .doc(walletId)
        .collection('messages')
        .doc(messageId)
        .update({
      'message': newMessage,
      'isEdited': true,
    });
  }

  /// Unsend / delete a chat message (mark as deleted)
  Future<void> deleteMessage({
    required String walletId,
    required String messageId,
  }) async {
    await _firestore
        .collection('wallets')
        .doc(walletId)
        .collection('messages')
        .doc(messageId)
        .update({
      'message': 'Pesan ini telah dihapus',
      'isDeleted': true,
    });
  }

  /// Mark chat as read by storing user's last-read timestamp.
  /// Only updates if the new timestamp is newer or not provided.
  Future<void> markChatAsRead(String walletId, String uid,
      {DateTime? until}) async {
    try {
      final docRef = _firestore
          .collection('wallets')
          .doc(walletId)
          .collection('readReceipts')
          .doc(uid);

      if (until != null) {
        final doc = await docRef.get();
        if (doc.exists) {
          final currentRead = (doc.data()?['lastRead'] as Timestamp?)?.toDate();
          if (currentRead != null && currentRead.isAfter(until)) {
            // Already read past this point
            return;
          }
        }
      }

      await docRef.set({
        'lastRead': until != null
            ? Timestamp.fromDate(until)
            : FieldValue.serverTimestamp()
      });
    } catch (e) {
      debugPrint('markChatAsRead failed: $e');
    }
  }

  /// Stream of unread message count for a specific wallet
  /// This listener triggers whenever EITHER a new message arrives OR a user marks messages as read.
  Stream<int> getUnreadCountStream(String walletId, String uid) {
    late StreamController<int> controller;
    StreamSubscription? receiptSub;
    StreamSubscription? messagesSub;

    void updateMessagesListener(Timestamp? lastRead) {
      messagesSub?.cancel();

      // Default to now if never opened. Prevents downloading ALL historical messages as unread.
      final filterTime = lastRead ?? Timestamp.now();

      messagesSub = _firestore
          .collection('wallets')
          .doc(walletId)
          .collection('messages')
          .where('timestamp', isGreaterThan: filterTime)
          .snapshots()
          .listen((msgSnap) {
        try {
          final count = msgSnap.docs.where((doc) {
            final data = doc.data();
            return data['senderUid'] != uid;
          }).length;

          if (!controller.isClosed) {
            controller.add(count);
          }
        } catch (e) {
          debugPrint('Error counting unread: $e');
        }
      });
    }

    controller = StreamController<int>(
      onListen: () {
        receiptSub = _firestore
            .collection('wallets')
            .doc(walletId)
            .collection('readReceipts')
            .doc(uid)
            .snapshots()
            .listen((receiptSnap) {
          try {
            Timestamp? lastRead;
            if (receiptSnap.exists) {
              lastRead = receiptSnap.data()?['lastRead'] as Timestamp?;
            }
            updateMessagesListener(lastRead);
          } catch (e) {
            debugPrint('Error updating receipt listener: $e');
          }
        });
      },
      onCancel: () {
        receiptSub?.cancel();
        messagesSub?.cancel();
      },
    );

    return controller.stream;
  }

  // ══════════════════════════════════════════════════
  // ADMIN TOOLS: MAINTENANCE & BROADCAST
  // ══════════════════════════════════════════════════

  Stream<DocumentSnapshot> getMaintenanceConfigStream() {
    return _firestore.collection('app_config').doc('global').snapshots();
  }

  Future<void> updateMaintenanceConfig({
    required bool isEnabled,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final data = {
      'isMaintenance': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (startTime != null)
      data['maintenanceStartTime'] = Timestamp.fromDate(startTime);
    if (endTime != null)
      data['maintenanceEndTime'] = Timestamp.fromDate(endTime);

    await _firestore
        .collection('app_config')
        .doc('global')
        .set(data, SetOptions(merge: true));

    // Log history
    await _firestore
        .collection('app_config')
        .doc('global')
        .collection('history')
        .add({
      'type': 'MAINTENANCE_TOGGLE',
      'value': isEnabled,
      'startTime': startTime != null ? Timestamp.fromDate(startTime) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime) : null,
      'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendGlobalBroadcast({
    required String title,
    required String message,
    required String type, // info, urgent, news
    DateTime? scheduledTime,
  }) async {
    await _firestore.collection('broadcasts').add({
      'title': title,
      'message': message,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'scheduledTime':
          scheduledTime != null ? Timestamp.fromDate(scheduledTime) : null,
      'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
    });

    // Log to Global Activity History
    await _firestore
        .collection('app_config')
        .doc('global')
        .collection('history')
        .add({
      'action': 'BROADCAST',
      'title': title,
      'message': message,
      'broadcastType': type,
      'updatedBy': FirebaseAuth.instance.currentUser?.uid ?? 'system',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> getBroadcastsStream(
      {bool includePast = false}) {
    Query query = _firestore
        .collection('broadcasts')
        .orderBy('timestamp', descending: true);

    if (!includePast) {
      query = query.limit(5); // Only show few for banner
    } else {
      query = query.limit(50); // Show more for history
    }

    return query.snapshots().map((snap) {
      final now = DateTime.now();
      return snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // Status logic
        final scheduled = (data['scheduledTime'] as Timestamp?)?.toDate();
        if (scheduled != null && scheduled.isAfter(now)) {
          data['status'] = 'pending';
        } else {
          data['status'] = 'ongoing';
        }
        return data;
      }).toList();
    });
  }

  Future<void> deleteBroadcast(String id) async {
    await _firestore.collection('broadcasts').doc(id).delete();
  }
}
