import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/transaction_card.dart';
import '../../utils/tone_dictionary.dart';
import '../empty_state_widget.dart';
import '../notched_section_card.dart';

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
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: ShimmerTransactionList(),
            ),
          );
        }

        final txns = snapshot.data ?? [];
        final grouped = _groupTransactions(txns);
        if (grouped.isEmpty) {
          return _buildEmptyState(context);
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final group = grouped[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: Text(
                        _getDateLabel(group.date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark
                              ? const Color(0xFF71717A)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    NotchedSectionCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0;
                              i < group.transactions.length;
                              i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 64,
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            TransactionCard(
                              transaction: group.transactions[i],
                              walletId: group.transactions[i].walletId,
                              isFlat: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            childCount: grouped.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SliverToBoxAdapter(
      child: EmptyStateWidget(
        title: ToneManager.t('home_empty_title'),
        subtitle: ToneManager.t('home_empty_msg'),
        icon: CupertinoIcons.square_list_fill,
        paddingVertical: 20,
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
    // Limit to max 7 active transaction dates (dates that actually contain transactions)
    final recent7Dates = sortedDates.take(7);

    return recent7Dates
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
