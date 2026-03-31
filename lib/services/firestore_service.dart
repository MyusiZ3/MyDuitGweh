import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  //  WALLET OPERATIONS
  // ============================================================

  /// Stream all wallets where the user is a member
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

  /// Create a new wallet with invite code if it's a colab wallet
  Future<String> createWallet(WalletModel wallet) async {
    final docRef = _firestore.collection('wallets').doc();
    
    String? inviteCode;
    if (wallet.type == 'colab') {
      inviteCode = _generateInviteCode();
    }
    
    await docRef.set(wallet.copyWith(
      id: docRef.id,
      inviteCode: inviteCode,
    ).toJson());
    
    return docRef.id;
  }

  /// Delete a wallet and all its related transactions
  Future<void> deleteWallet(String walletId) async {
    // 1. Get all transactions for this wallet
    final transactions = await _firestore
        .collection('transactions')
        .where('walletId', isEqualTo: walletId)
        .get();

    // 2. Start a batch write for performance and atomicity
    final batch = _firestore.batch();

    // 3. Delete all related transactions
    for (var doc in transactions.docs) {
      batch.delete(doc.reference);
    }

    // 4. Delete the wallet document
    batch.delete(_firestore.collection('wallets').doc(walletId));

    // 5. Commit the batch
    await batch.commit();
  }

  /// Generate a random 6-character invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  /// Join a wallet using an invite code
  Future<bool> joinWalletByCode(String code, String uid) async {
    final query = await _firestore
        .collection('wallets')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    final doc = query.docs.first;
    final members = List<String>.from(doc.data()['members'] ?? []);

    if (members.contains(uid)) return true; // Already a member

    await doc.reference.update({
      'members': FieldValue.arrayUnion([uid]),
    });

    return true;
  }

  // ============================================================
  //  TRANSACTION OPERATIONS (with atomic balance update)
  // ============================================================

  /// Add a transaction and update wallet balance atomically using runTransaction
  Future<void> addTransaction(TransactionModel transaction) async {
    await _firestore.runTransaction((txn) async {
      // 1. Read the current wallet document
      final walletRef =
          _firestore.collection('wallets').doc(transaction.walletId);
      final walletSnapshot = await txn.get(walletRef);

      if (!walletSnapshot.exists) {
        throw Exception('Wallet not found');
      }

      final currentBalance =
          (walletSnapshot.data()!['balance'] as num).toDouble();

      // 2. Calculate new balance
      final double newBalance;
      if (transaction.type == 'income') {
        newBalance = currentBalance + transaction.amount;
      } else {
        newBalance = currentBalance - transaction.amount;
      }

      // 3. Create the transaction document
      final transactionRef = _firestore.collection('transactions').doc();
      txn.set(transactionRef, transaction.toJson());

      // 4. Update the wallet balance
      txn.update(walletRef, {'balance': newBalance});
    });
  }

  /// Stream transactions for a specific wallet
  Stream<List<TransactionModel>> getTransactionsStream(String walletId) {
    return _firestore
        .collection('transactions')
        .where('walletId', isEqualTo: walletId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TransactionModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  /// Stream all transactions for a user across all wallets
  Stream<List<TransactionModel>> getAllTransactionsStream(
      List<String> walletIds) {
    if (walletIds.isEmpty) return Stream.value([]);

    // Firestore 'whereIn' supports max 30 values
    final chunks = <List<String>>[];
    for (var i = 0; i < walletIds.length; i += 30) {
      chunks.add(walletIds.sublist(
          i, i + 30 > walletIds.length ? walletIds.length : i + 30));
    }

    if (chunks.length == 1) {
      return _firestore
          .collection('transactions')
          .where('walletId', whereIn: chunks[0])
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) =>
                  TransactionModel.fromJson(doc.data(), docId: doc.id))
              .toList());
    }

    // If multiple chunks, merge streams
    return Stream.value(<TransactionModel>[]);
  }

  /// Get latest N transactions across all user wallets
  Stream<List<TransactionModel>> getLatestTransactions(
      List<String> walletIds,
      {int limit = 5}) {
    if (walletIds.isEmpty) return Stream.value([]);

    return _firestore
        .collection('transactions')
        .where('walletId', whereIn: walletIds.take(30).toList())
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TransactionModel.fromJson(doc.data(), docId: doc.id))
            .toList());
  }

  /// Delete transaction and reverse the balance atomically
  Future<void> deleteTransaction(TransactionModel transaction) async {
    await _firestore.runTransaction((txn) async {
      final walletRef =
          _firestore.collection('wallets').doc(transaction.walletId);
      final walletSnapshot = await txn.get(walletRef);

      if (!walletSnapshot.exists) {
        throw Exception('Wallet not found');
      }

      final currentBalance =
          (walletSnapshot.data()!['balance'] as num).toDouble();

      // Reverse the balance change
      final double newBalance;
      if (transaction.type == 'income') {
        newBalance = currentBalance - transaction.amount;
      } else {
        newBalance = currentBalance + transaction.amount;
      }

      // Delete the transaction
      final transactionRef =
          _firestore.collection('transactions').doc(transaction.id);
      txn.delete(transactionRef);

      // Update wallet balance
      txn.update(walletRef, {'balance': newBalance});
    });
  }

  // ============================================================
  //  COLAB OPERATIONS
  // ============================================================

  /// Add a member to a colab wallet by email
  Future<bool> addMemberByEmail(String walletId, String email) async {
    // Find user by email
    final userQuery = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) return false;

    final memberUid = userQuery.docs.first.id;

    // Add to members array
    await _firestore.collection('wallets').doc(walletId).update({
      'members': FieldValue.arrayUnion([memberUid]),
    });

    return true;
  }

  /// Remove a member from a colab wallet
  Future<void> removeMember(String walletId, String memberUid) async {
    await _firestore.collection('wallets').doc(walletId).update({
      'members': FieldValue.arrayRemove([memberUid]),
    });
  }

  /// Get user info by UID
  Future<Map<String, dynamic>?> getUserInfo(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Get total balance across all wallets
  Future<double> getTotalBalance(String uid) async {
    final snapshot = await _firestore
        .collection('wallets')
        .where('members', arrayContains: uid)
        .get();

    double total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['balance'] as num).toDouble();
    }
    return total;
  }
}
