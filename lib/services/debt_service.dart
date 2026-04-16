import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';

class DebtService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reference to user's debts collection
  CollectionReference _getUserDebtsCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('debts');
  }

  // Reference to transactions collection (Top Level)
  CollectionReference _getTransactionsCollection() {
    return _firestore.collection('transactions');
  }

  // Reference to wallets collection (Top Level)
  CollectionReference _getWalletsCollection() {
    return _firestore.collection('wallets');
  }

  // Add a new debt/receivable
  Future<void> addDebt({
    required String currentUserId,
    required String currentUserName,
    required String type, // 'utang' or 'piutang'
    required String title,
    required double totalAmount,
    required String walletId,
    DateTime? dueDate,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final debtId = TransactionModel.generateId(prefix: 'DBT');

    // 1. Create the Debt Model
    final debtDoc = _getUserDebtsCollection(currentUserId).doc(debtId);
    final debt = DebtModel(
      id: debtId,
      type: type,
      title: title,
      totalAmount: totalAmount,
      paidAmount: 0.0,
      status: 'active',
      createdAt: now,
      dueDate: dueDate,
      createdBy: currentUserId,
      walletId: walletId,
    );
    batch.set(debtDoc, debt.toJson());

    // 2. Create the associated Transaction
    // If it's an Utang (we borrow money): We receive money in our wallet (Income)
    // If it's a Piutang (we lend money): We give money from our wallet (Expense)
    final transactionId = TransactionModel.generateId();
    final transactionDoc =
        _getTransactionsCollection().doc(transactionId);
    
    final isUtang = type == 'utang';
    final txType = isUtang ? 'income' : 'expense';
    final txCategory = isUtang ? 'Pinjaman' : 'Hutang';

    final transaction = TransactionModel(
      id: transactionId,
      walletId: walletId,
      amount: totalAmount,
      type: txType,
      category: txCategory,
      note: 'Saldo awal untuk $title',
      createdBy: currentUserId,
      createdByName: currentUserName,
      date: now,
      debtId: debtId,
    );
    batch.set(transactionDoc, transaction.toJson());

    // 3. Update the Wallet Balance
    final walletDoc = _getWalletsCollection().doc(walletId);
    // Use FieldValue.increment to ensure atomicity
    final amountDelta = isUtang ? totalAmount : -totalAmount;
    batch.update(walletDoc, {'balance': FieldValue.increment(amountDelta)});

    // 4. Update lastTransactionAt for rate limiting in Security Rules
    final userRef = _firestore.collection('users').doc(currentUserId);
    batch.update(userRef, {'lastTransactionAt': FieldValue.serverTimestamp()});

    // Commit all operations atomically
    await batch.commit();
  }

  // Pay an installment
  Future<void> payInstallment({
    required String currentUserId,
    required String currentUserName,
    required DebtModel targetDebt,
    required double installmentAmount,
    required String paymentWalletId,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    // 1. Update the Debt Model
    final debtDoc = _getUserDebtsCollection(currentUserId).doc(targetDebt.id);
    final newPaidAmount = targetDebt.paidAmount + installmentAmount;
    final newStatus =
        newPaidAmount >= targetDebt.totalAmount ? 'completed' : 'mencicil';
    
    batch.update(debtDoc, {
      'paidAmount': newPaidAmount,
      'status': newStatus,
    });

    // 2. Create the Installment Transaction
    // For Utang (we borrowed money): Repaying means money leaves our wallet (Expense)
    // For Piutang (they borrowed money): Repaying means money enters our wallet (Income)
    final transactionId = TransactionModel.generateId();
    final transactionDoc =
        _getTransactionsCollection().doc(transactionId);
    
    final isUtang = targetDebt.isUtang;
    final txType = isUtang ? 'expense' : 'income';
    
    final transaction = TransactionModel(
      id: transactionId,
      walletId: paymentWalletId,
      amount: installmentAmount,
      type: txType,
      category: 'Cicilan',
      note: 'Pembayaran cicilan untuk ${targetDebt.title}',
      createdBy: currentUserId,
      createdByName: currentUserName,
      date: now,
      debtId: targetDebt.id,
    );
    batch.set(transactionDoc, transaction.toJson());

    // 3. Update the Payment Wallet Balance
    final walletDoc = _getWalletsCollection().doc(paymentWalletId);
    final amountDelta = isUtang ? -installmentAmount : installmentAmount;
    batch.update(walletDoc, {'balance': FieldValue.increment(amountDelta)});

    // 4. Update lastTransactionAt for rate limiting in Security Rules
    final userRef = _firestore.collection('users').doc(currentUserId);
    batch.update(userRef, {'lastTransactionAt': FieldValue.serverTimestamp()});

    // Commit all operations atomically
    await batch.commit();
  }

  // Stream user debts
  Stream<List<DebtModel>> getUserDebts(String userId) {
    return _getUserDebtsCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DebtModel.fromJson(doc.data() as Map<String, dynamic>,
            docId: doc.id);
      }).toList();
    });
  }

  // Delete a debt and all its associated transactions with balance reconciliation
  Future<void> deleteDebt(String userId, String debtId) async {
    // 1. Get the debt details first to know which wallet to reconcile
    final debtDocRef = _getUserDebtsCollection(userId).doc(debtId);
    final debtDoc = await debtDocRef.get();
    
    if (!debtDoc.exists) return;
    final debt = DebtModel.fromJson(debtDoc.data() as Map<String, dynamic>, docId: debtId);
    
    final batch = _firestore.batch();
    
    // 2. Find all transactions associated with this debt
    final querySnapshot = await _getTransactionsCollection()
        .where('debtId', isEqualTo: debtId)
        .get();

    for (var txDoc in querySnapshot.docs) {
      final txData = txDoc.data() as Map<String, dynamic>;
      final String txWalletId = txData['walletId'];
      final double txAmount = (txData['amount'] as num).toDouble();
      final String txType = txData['type']; // 'income' or 'expense'
      
      // 3. Reverse the effect on the wallet balance
      final walletDoc = _getWalletsCollection().doc(txWalletId);
      final isIncome = txType == 'income';
      
      // If it was income (we received money), we subtract it. 
      // If it was expense (we gave money), we add it back.
      final reverseAmount = isIncome ? -txAmount : txAmount;
      batch.update(walletDoc, {'balance': FieldValue.increment(reverseAmount)});
      
      // 4. Delete the transaction
      batch.delete(txDoc.reference);
    }

    // 5. Delete the debt document
    batch.delete(debtDocRef);

    // Commit all operations atomically
    await batch.commit();
  }

  // Update debt details
  Future<void> updateDebt({
    required String userId,
    required String debtId,
    required String title,
    double? newTotalAmount,
    DateTime? dueDate,
  }) async {
    final batch = _firestore.batch();
    final debtDocRef = _getUserDebtsCollection(userId).doc(debtId);
    
    Map<String, dynamic> updates = {
      'title': title,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
    };
    if (newTotalAmount != null) {
      try {
        // 1. Get current debt to find the difference and reconcile balance
        // Handle offline: get from server/cache with timeout
        final debtDoc = await debtDocRef.get().timeout(const Duration(seconds: 5));
        
        if (debtDoc.exists) {
          final debtData = debtDoc.data() as Map<String, dynamic>;
          final double oldTotalAmount = (debtData['totalAmount'] as num?)?.toDouble() ?? 0.0;
          final double paidAmount = (debtData['paidAmount'] as num?)?.toDouble() ?? 0.0;
          final String? walletId = debtData['walletId'] as String?;
          final bool isUtang = debtData['type'] == 'utang';
          
          if (oldTotalAmount != newTotalAmount) {
            final double diff = newTotalAmount - oldTotalAmount;
            
            // 2. Update Debt fields
            updates['totalAmount'] = newTotalAmount;
            updates['status'] = (paidAmount >= newTotalAmount) ? 'completed' : (paidAmount > 0 ? 'mencicil' : 'active');

            // 3. Update Wallet Balance if walletId exists
            if (walletId != null) {
              final walletDocRef = _getWalletsCollection().doc(walletId);
              final balanceDelta = isUtang ? diff : -diff;
              batch.update(walletDocRef, {'balance': FieldValue.increment(balanceDelta)});
            }

            // 4. Update Initial Transaction if possible
            try {
              final txQuery = await _getTransactionsCollection()
                  .where('debtId', isEqualTo: debtId)
                  .get()
                  .timeout(const Duration(seconds: 5));
              
              if (txQuery.docs.isNotEmpty) {
                final targetDoc = txQuery.docs.firstWhere((doc) {
                  final cat = (doc.data() as Map<String, dynamic>)['category'] as String?;
                  return cat == 'Pinjaman' || cat == 'Hutang';
                });
                batch.update(targetDoc.reference, {'amount': newTotalAmount});
              }
            } catch (e) {
              // Silently fail transaction update - main debt doc will sync
            }
          }
        }
      } catch (e) {
        // If we are offline/error, just update totalAmount on the main doc
        updates['totalAmount'] = newTotalAmount;
      }
    }

    batch.update(debtDocRef, updates);
    try {
      await batch.commit().timeout(const Duration(seconds: 10));
    } catch (e) {
      // commit might be queued in Firestore for offline, which is fine
      // we don't want to throw and crash the UI
    }
  }

  // Delete an individual debt transaction and reconcile amounts
  Future<void> deleteDebtTransaction({
    required String userId,
    required TransactionModel transaction,
    required DebtModel debt,
  }) async {
    final batch = _firestore.batch();
    final bool isCicilan = transaction.category == 'Cicilan';
    
    // 1. Update the Debt Model
    final debtDocRef = _getUserDebtsCollection(userId).doc(debt.id);
    
    if (isCicilan) {
      final newPaidAmount = debt.paidAmount - transaction.amount;
      final newStatus = newPaidAmount >= debt.totalAmount ? 'completed' : (newPaidAmount > 0 ? 'mencicil' : 'active');
      batch.update(debtDocRef, {
        'paidAmount': newPaidAmount,
        'status': newStatus,
      });
    } else {
      final newTotalAmount = debt.totalAmount - transaction.amount;
      batch.update(debtDocRef, {
        'totalAmount': newTotalAmount,
        'status': (debt.paidAmount >= newTotalAmount) ? 'completed' : (debt.paidAmount > 0 ? 'mencicil' : 'active'),
      });
    }

    // 2. Reconcile the Wallet Balance
    // Reversing an income (Utang borrow / Piutang repay): subtract from wallet
    // Reversing an expense (Utang repay / Piutang lend): add back to wallet
    final walletDocRef = _getWalletsCollection().doc(transaction.walletId);
    final isIncome = transaction.type == 'income';
    final reverseAmount = isIncome ? -transaction.amount : transaction.amount;
    batch.update(walletDocRef, {'balance': FieldValue.increment(reverseAmount)});

    // 3. Delete the transaction
    final txDocRef = _getTransactionsCollection().doc(transaction.id);
    batch.delete(txDocRef);

    await batch.commit();
  }

  // Update an individual debt transaction nominal and reconcile amounts
  Future<void> updateDebtTransaction({
    required String userId,
    required TransactionModel oldTransaction,
    required DebtModel debt,
    required double newAmount,
  }) async {
    if (newAmount == oldTransaction.amount) return;
    
    final batch = _firestore.batch();
    final double diff = newAmount - oldTransaction.amount;
    final bool isCicilan = oldTransaction.category == 'Cicilan';
    
    // 1. Update the Debt Model
    final debtDocRef = _getUserDebtsCollection(userId).doc(debt.id);
    
    if (isCicilan) {
      // Adjust paidAmount for installments
      final newPaidAmount = debt.paidAmount + diff;
      final newStatus = newPaidAmount >= debt.totalAmount ? 'completed' : (newPaidAmount > 0 ? 'mencicil' : 'active');
      batch.update(debtDocRef, {
        'paidAmount': newPaidAmount,
        'status': newStatus,
      });
    } else {
      // Adjust totalAmount for initial/additional borrowings
      final newTotalAmount = debt.totalAmount + diff;
      // Also update status if now paidAmount >= newTotalAmount
      batch.update(debtDocRef, {
        'totalAmount': newTotalAmount,
        'status': (debt.paidAmount >= newTotalAmount) ? 'completed' : (debt.paidAmount > 0 ? 'mencicil' : 'active'),
      });
    }

    // 2. Reconcile the Wallet Balance
    // For Income transactions (Utang borrow / Piutang repay): + diff means more cash in (increment)
    // For Expense transactions (Utang repay / Piutang lend): + diff means more cash out (decrement)
    final walletDocRef = _getWalletsCollection().doc(oldTransaction.walletId);
    final isIncome = oldTransaction.type == 'income';
    final balanceDelta = isIncome ? diff : -diff;
    batch.update(walletDocRef, {'balance': FieldValue.increment(balanceDelta)});

    // 3. Update the transaction
    final txDocRef = _getTransactionsCollection().doc(oldTransaction.id);
    batch.update(txDocRef, {'amount': newAmount});

    await batch.commit();
  }

  // Increase the total debt/credit amount (borrow/lend more)
  Future<void> increaseDebt({
    required String userId,
    required String userName,
    required DebtModel debt,
    required double additionalAmount,
    required String walletId,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    // 1. Update the Debt Model (increase totalAmount)
    final debtDocRef = _getUserDebtsCollection(userId).doc(debt.id);
    final newTotalAmount = debt.totalAmount + additionalAmount;
    
    batch.update(debtDocRef, {
      'totalAmount': newTotalAmount,
      'status': (debt.paidAmount >= newTotalAmount) ? 'completed' : 'mencicil',
    });

    // 2. Create the Addition Transaction
    final transactionId = TransactionModel.generateId();
    final transactionDoc = _getTransactionsCollection().doc(transactionId);
    
    // If Utang: borrowing more is INCOME to wallet
    // If Piutang: lending more is EXPENSE from wallet
    final isUtang = debt.isUtang;
    final txType = isUtang ? 'income' : 'expense';
    final category = isUtang ? 'Hutang' : 'Pinjaman';
    
    final transaction = TransactionModel(
      id: transactionId,
      walletId: walletId,
      amount: additionalAmount,
      type: txType,
      category: category,
      note: 'Penambahan ${isUtang ? 'Hutang' : 'Piutang'} untuk ${debt.title}',
      createdBy: userId,
      createdByName: userName,
      date: now,
      debtId: debt.id,
    );
    batch.set(transactionDoc, transaction.toJson());

    // 3. Update the Wallet Balance
    final walletDocRef = _getWalletsCollection().doc(walletId);
    final balanceDelta = isUtang ? additionalAmount : -additionalAmount;
    batch.update(walletDocRef, {'balance': FieldValue.increment(balanceDelta)});

    // 4. Update lastTransactionAt
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {'lastTransactionAt': FieldValue.serverTimestamp()});

    await batch.commit();
  }
}

