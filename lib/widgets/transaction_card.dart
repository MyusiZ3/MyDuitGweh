import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';

class TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final String walletId;
  final bool isFlat;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.walletId,
    this.isFlat = false,
  });

  @override
  Widget build(BuildContext context) {
    bool isTxIncome = transaction.isIncome;
    Color displayColor = isTxIncome ? AppColors.income : AppColors.expense;
    String sign = isTxIncome ? '+' : '-';
    
    if (transaction.isTransfer) {
      if (transaction.walletId == walletId) {
        isTxIncome = false;
        displayColor = AppColors.primary;
        sign = '-';
      } else if (transaction.targetWalletId == walletId) {
        isTxIncome = true;
        displayColor = const Color(0xFF34C759);
        sign = '+';
      } else {
        isTxIncome = false;
        displayColor = AppColors.primary;
        sign = '';
      }
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: isFlat
          ? null
          : BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.015),
                  blurRadius: 10,
                )
              ],
            ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: displayColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              TransactionCategory.getIconForCategory(transaction.category),
              color: displayColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  transaction.note.isEmpty
                      ? DateFormat('dd MMM yyyy').format(transaction.date)
                      : transaction.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.35,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$sign${CurrencyFormatter.formatCurrency(transaction.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: displayColor,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
