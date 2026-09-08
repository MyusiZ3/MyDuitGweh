import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/transaction_card.dart';
import '../../utils/tone_dictionary.dart';
import '../../utils/app_theme.dart';
import '../empty_state_widget.dart';

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: ShimmerTransactionList(),
            ),
          );
        }

        final txns = snapshot.data ?? [];
        if (txns.isEmpty) {
          return _buildEmptyState(context);
        }

        final grouped = _groupTransactions(txns);

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final group = grouped[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                    ...group.transactions.map((tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TransactionCard(
                            transaction: tx,
                            walletId: tx.walletId,
                          ),
                        )),
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
