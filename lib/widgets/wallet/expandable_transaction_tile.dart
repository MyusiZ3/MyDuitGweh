import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';

class ExpandableTransactionTile extends StatefulWidget {
  final TransactionModel t;
  final WalletModel wallet;
  final bool isFlat;

  const ExpandableTransactionTile({
    super.key,
    required this.t,
    required this.wallet,
    this.isFlat = false,
  });

  @override
  State<ExpandableTransactionTile> createState() =>
      _ExpandableTransactionTileState();
}

class _ExpandableTransactionTileState
    extends State<ExpandableTransactionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final wallet = widget.wallet;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTransfer = t.type == 'transfer';
    final amountColor = isTransfer
        ? (t.walletId == wallet.id
            ? AppColors.pastelBlue
            : AppColors.income)
        : (t.isIncome
            ? AppColors.income
            : AppColors.expense);
    final amountPrefix = isTransfer
        ? (t.walletId == wallet.id ? '-' : '+')
        : (t.isIncome ? '+' : '-');

    final dateStr = DateFormat('dd MMM yyyy • HH:mm').format(t.date);
    final dateSubtitle =
        wallet.isColab ? '$dateStr • ${t.createdByName}' : dateStr;
    final hasNote = t.note.trim().isNotEmpty;
    final monochromeText =
        isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);

    return GestureDetector(
      onTap: hasNote
          ? () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: widget.isFlat ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(
          horizontal: widget.isFlat ? 16 : 14,
          vertical: 12,
        ),
        decoration: widget.isFlat
            ? null
            : BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isExpanded
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : (isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04)),
                  width: _isExpanded ? 1.5 : 1.0,
                ),
              ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: amountColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    TransactionCategory.getIconForCategory(t.category),
                    color: amountColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.category,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$amountPrefix${CurrencyFormatter.formatCurrency(t.amount)}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                    if (hasNote) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isExpanded ? 'Tutup' : 'Detail',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: monochromeText,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _isExpanded
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            size: 10,
                            color: monochromeText,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (hasNote && _isExpanded) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t.note.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
