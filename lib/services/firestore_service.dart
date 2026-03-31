import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  //  ID GENERATORS (FOR PROFESSIONAL LOOK)
  // ============================================================
  
  String _generateProfessionalId(String prefix) {
    // Menghasilkan ID unik: PREFIX-TIMESTAMP-RANDOM4
    final now = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = List.generate(4, (index) => chars[Random().nextInt(chars.length)]).join();
    return '$prefix-$now-$random';
  }

  // ============================================================
  //  WALLET OPERATIONS
  // ============================================================

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

  /// Get personal wallets only
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

  /// Get colab wallets only
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
    
    await docRef.set(wallet.copyWith(
      id: customId,
      inviteCode: inviteCode,
    ).toJson());
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
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  Future<bool> joinWalletByCode(String code, String uid) async {
    final query = await _firestore
        .collection('wallets')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return false;
    final doc = query.docs.first;
    final members = List<String>.from(doc.data()['members'] ?? []);
    if (members.contains(uid)) return true;
    await doc.reference.update({'members': FieldValue.arrayUnion([uid])});
    return true;
  }

  // ============================================================
  //  TRANSACTION OPERATIONS
  // ============================================================

  Future<void> addTransaction(TransactionModel transaction) async {
    final customTxId = _generateProfessionalId('TX');
    
    await _firestore.runTransaction((txn) async {
      final walletRef = _firestore.collection('wallets').doc(transaction.walletId);
      final walletSnapshot = await txn.get(walletRef);
      if (!walletSnapshot.exists) throw Exception('Wallet not found');
      
      final currentBalance = (walletSnapshot.data()!['balance'] as num).toDouble();
      final double newBalance = transaction.isIncome ? currentBalance + transaction.amount : currentBalance - transaction.amount;
      
      final transactionRef = _firestore.collection('transactions').doc(customTxId);
      
      txn.set(transactionRef, transaction.copyWith(id: customTxId).toJson());
      txn.update(walletRef, {'balance': newBalance});
    });
  }

  Future<List<TransactionModel>> getFilteredTransactions({
    required List<String> walletIds,
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categories,
  }) async {
    if (walletIds.isEmpty) return [];

    final start = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    Query query = _firestore.collection('transactions')
        .where('walletId', whereIn: walletIds.take(30).toList())
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true);

    if (categories != null && categories.isNotEmpty && !categories.contains('All')) {
      query = query.where('category', whereIn: categories);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromJson(doc.data() as Map<String, dynamic>, docId: doc.id))
        .toList();
  }

  Stream<List<TransactionModel>> getTransactionsStream(String walletId) {
    return _firestore.collection('transactions')
        .where('walletId', isEqualTo: walletId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data(), docId: doc.id)).toList());
  }

  Stream<List<TransactionModel>> getLatestTransactions(List<String> walletIds, {int limit = 5}) {
    if (walletIds.isEmpty) return Stream.value([]);
    return _firestore.collection('transactions')
        .where('walletId', whereIn: walletIds.take(30).toList())
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data(), docId: doc.id)).toList());
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    await _firestore.runTransaction((txn) async {
      final walletRef = _firestore.collection('wallets').doc(transaction.walletId);
      final walletSnapshot = await txn.get(walletRef);
      if (!walletSnapshot.exists) throw Exception('Wallet not found');
      
      final currentBalance = (walletSnapshot.data()!['balance'] as num).toDouble();
      final double newBalance = transaction.isIncome ? currentBalance - transaction.amount : currentBalance + transaction.amount;
      
      final transactionRef = _firestore.collection('transactions').doc(transaction.id);
      txn.delete(transactionRef);
      txn.update(walletRef, {'balance': newBalance});
    });
  }

  // ============================================================
  //  MEMBER & USER OPERATIONS
  // ============================================================

  Future<bool> addMemberByEmail(String walletId, String email) async {
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) return false;
    final memberUid = userQuery.docs.first.id;

    await _firestore.collection('wallets').doc(walletId).update({
      'members': FieldValue.arrayUnion([memberUid]),
    });
    return true;
  }

  Future<Map<String, dynamic>?> getUserInfo(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }
}
