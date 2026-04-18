import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/transaction_card.dart';
import '../../utils/tone_dictionary.dart';
import '../../utils/app_theme.dart';

class HomeRecentTransactions extends StatelessWidget {
  final List<String> walletIds;
  final FirestoreService firestoreService;

  const HomeRecentTransactions({
    super.key,
    required this.walletIds,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: firestoreService.getAllTransactionsStream(walletIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: ShimmerTransactionList(),
            ),
          );
        }

        final txns = snapshot.data!;
        if (txns.isEmpty) {
          return _buildEmptyState(context);
        }

        // Grouping logic (limit to first 10 for performance/main home view)
        final limitedTxns = txns.take(10).toList();
        final groups = _groupTransactions(limitedTxns);

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final group = groups[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 0, 10),
                      child: Text(
                        _getDateLabel(group.date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Theme.of(context).hintColor.withOpacity(0.5),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withOpacity(0.05),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: List.generate(group.transactions.length, (i) {
                          final t = group.transactions[i];
                          final isLast = i == group.transactions.length - 1;
                          
                          return Column(
                            children: [
                              TransactionCard(
                                transaction: t,
                                walletId: t.walletId,
                                isFlat: true,
                              ),
                              if (!isLast)
                                Padding(
                                  padding: const EdgeInsets.only(left: 64),
                                  child: Divider(
                                    height: 1,
                                    thickness: 0.5,
                                    color: Theme.of(context).dividerColor.withOpacity(0.08),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
            childCount: groups.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        height: 160,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.05),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.square_list_fill,
                color: AppColors.primary.withOpacity(0.4),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ToneManager.t('home_empty_title'),
              style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ToneManager.t('home_empty_msg'),
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_TransactionGroup> _groupTransactions(List<TransactionModel> txns) {
    final Map<DateTime, List<TransactionModel>> grouped = {};

    for (var tx in txns) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (grouped[date] == null) {
        grouped[date] = [];
      }
      grouped[date]!.add(tx);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return sortedDates
        .map((date) => _TransactionGroup(date, grouped[date]!))
        .toList();
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return ToneManager.t('date_today');
    if (date == yesterday) return ToneManager.t('date_yesterday');

    return DateFormat('dd MMMM yyyy').format(date);
  }
}

class _TransactionGroup {
  final DateTime date;
  final List<TransactionModel> transactions;

  _TransactionGroup(this.date, this.transactions);
}
