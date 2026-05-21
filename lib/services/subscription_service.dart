import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_model.dart';
import '../models/transaction_model.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reference to user's subscriptions collection
  CollectionReference _getUserSubscriptionsCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('subscriptions');
  }

  // Reference to transactions collection (Top Level)
  CollectionReference _getTransactionsCollection() {
    return _firestore.collection('transactions');
  }

  // Reference to wallets collection (Top Level)
  CollectionReference _getWalletsCollection() {
    return _firestore.collection('wallets');
  }

  // Get Subscriptions Stream
  Stream<List<SubscriptionModel>> getSubscriptionsStream(String userId) {
    return _getUserSubscriptionsCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SubscriptionModel.fromJson(
                doc.data() as Map<String, dynamic>,
                docId: doc.id))
            .toList());
  }

  // Add a new subscription
  Future<void> addSubscription({
    required String userId,
    required String name,
    required double amount,
    required int dueDay,
    required String category,
    required String walletId,
  }) async {
    final docId = TransactionModel.generateId(prefix: 'SUB');
    final now = DateTime.now();

    final subscription = SubscriptionModel(
      id: docId,
      name: name,
      amount: amount,
      dueDay: dueDay,
      category: category,
      walletId: walletId,
      createdBy: userId,
      createdAt: now,
      isActive: true,
      paidMonths: [],
    );

    await _getUserSubscriptionsCollection(userId)
        .doc(docId)
        .set(subscription.toJson());
  }

  // Delete a subscription
  Future<void> deleteSubscription(String userId, String subId) async {
    await _getUserSubscriptionsCollection(userId).doc(subId).delete();
  }

  // Update subscription details
  Future<void> updateSubscription({
    required String userId,
    required String subId,
    required String name,
    required double amount,
    required int dueDay,
    required String category,
    required String walletId,
  }) async {
    await _getUserSubscriptionsCollection(userId).doc(subId).update({
      'name': name,
      'amount': amount,
      'dueDay': dueDay,
      'category': category,
      'walletId': walletId,
    });
  }

  // Pay monthly subscription bill
  Future<void> paySubscription({
    required String userId,
    required String userName,
    required SubscriptionModel subscription,
    required String monthStr, // 'YYYY-MM'
    required String walletId, // wallet used to pay
    double? customAmount,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final payAmount = customAmount ?? subscription.amount;

    // 1. Add the monthStr to paidMonths list in Subscription Doc
    final subDocRef = _getUserSubscriptionsCollection(userId).doc(subscription.id);
    batch.update(subDocRef, {
      'paidMonths': FieldValue.arrayUnion([monthStr])
    });

    // 2. Create the associated Transaction
    final transactionId = TransactionModel.generateId();
    final transactionDoc = _getTransactionsCollection().doc(transactionId);

    final transaction = TransactionModel(
      id: transactionId,
      walletId: walletId,
      amount: payAmount,
      type: 'expense',
      category: subscription.category,
      note: 'Pembayaran tagihan ${subscription.name} - $monthStr',
      createdBy: userId,
      createdByName: userName,
      date: now,
      subscriptionId: subscription.id,
    );
    batch.set(transactionDoc, transaction.toJson());

    // 3. Update the Wallet Balance (subtract bill amount)
    final walletDoc = _getWalletsCollection().doc(walletId);
    batch.update(walletDoc, {
      'balance': FieldValue.increment(-payAmount)
    });

    // 4. Update lastTransactionAt for security rules rate limit
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'lastTransactionAt': FieldValue.serverTimestamp()
    });

    // Commit all operations atomically
    await batch.commit();
  }

  // Rollback/delete a subscription monthly payment (refunds wallet & deletes transaction)
  Future<void> rollbackSubscriptionPayment({
    required String userId,
    required SubscriptionModel subscription,
    required String monthStr, // 'YYYY-MM'
  }) async {
    final batch = _firestore.batch();
    
    // Find the associated transaction by subscriptionId first
    var querySnapshot = await _getTransactionsCollection()
        .where('createdBy', isEqualTo: userId)
        .where('subscriptionId', isEqualTo: subscription.id)
        .limit(20)
        .get();

    // Find the specific month's transaction from results
    DocumentSnapshot? targetDoc;
    for (var doc in querySnapshot.docs) {
      final noteStr = doc.get('note') as String? ?? '';
      if (noteStr.contains(monthStr)) {
        targetDoc = doc;
        break;
      }
    }

    // Fallback: If not found, try searching by note prefix/pattern directly (legacy support)
    if (targetDoc == null) {
      final fallbackSnapshot = await _getTransactionsCollection()
          .where('createdBy', isEqualTo: userId)
          .where('note', isEqualTo: 'Pembayaran tagihan ${subscription.name} - $monthStr')
          .limit(1)
          .get();
      if (fallbackSnapshot.docs.isNotEmpty) {
        targetDoc = fallbackSnapshot.docs.first;
      }
    }

    if (targetDoc != null) {
      final walletId = targetDoc.get('walletId') as String?;
      final amount = (targetDoc.get('amount') as num?)?.toDouble() ?? 0.0;

      // 1. Delete transaction
      batch.delete(targetDoc.reference);

      // 2. Refund the wallet balance (if walletId is present)
      if (walletId != null && walletId.isNotEmpty) {
        final walletDoc = _getWalletsCollection().doc(walletId);
        batch.update(walletDoc, {
          'balance': FieldValue.increment(amount)
        });
      }
    }

    // 3. Remove monthStr from paidMonths in Subscription Doc
    final subDocRef = _getUserSubscriptionsCollection(userId).doc(subscription.id);
    batch.update(subDocRef, {
      'paidMonths': FieldValue.arrayRemove([monthStr])
    });

    // 4. Update lastTransactionAt for rate-limiting
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'lastTransactionAt': FieldValue.serverTimestamp()
    });

    await batch.commit();
  }

  // Get historical transactions for a subscription (both by subscriptionId and note-based fallback)
  Future<List<TransactionModel>> getSubscriptionTransactions(
      String userId, String subscriptionId, String subscriptionName) async {
    // 1. Try fetching by subscriptionId
    var querySnapshot = await _getTransactionsCollection()
        .where('createdBy', isEqualTo: userId)
        .where('subscriptionId', isEqualTo: subscriptionId)
        .get();

    // 2. If empty, fall back to note-based query (for legacy payments)
    if (querySnapshot.docs.isEmpty) {
      querySnapshot = await _getTransactionsCollection()
          .where('createdBy', isEqualTo: userId)
          .where('category', isEqualTo: 'Tagihan')
          .get();
      
      final list = querySnapshot.docs
          .map((doc) => TransactionModel.fromJson(doc.data() as Map<String, dynamic>, docId: doc.id))
          .where((t) => t.note.startsWith('Pembayaran tagihan $subscriptionName -'))
          .toList();
      return list;
    }

    return querySnapshot.docs
        .map((doc) => TransactionModel.fromJson(doc.data() as Map<String, dynamic>, docId: doc.id))
        .toList();
  }
}
