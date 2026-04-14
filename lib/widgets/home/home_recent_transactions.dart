import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/transaction_card.dart';
import '../../utils/tone_dictionary.dart';

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
          return SliverToBoxAdapter(
            child: Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.clock,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.5),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ToneManager.t('home_empty_title'),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.titleLarge?.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ToneManager.t('home_empty_msg'),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final t = txns[index];
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                  left: 24,
                  right: 24,
                ),
                child: TransactionCard(
                  transaction: t,
                  walletId: t.walletId,
                ),
              );
            },
            childCount: txns.length > 5 ? 5 : txns.length, // Limit to 5
          ),
        );
      },
    );
  }
}
