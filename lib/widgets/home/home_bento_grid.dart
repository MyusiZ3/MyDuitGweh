import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'home_budget_tracker.dart';
import 'home_observer_card.dart';

class HomeBentoGrid extends StatelessWidget {
  final String uid;
  final double monthlyBudget;
  final double netWorth;
  final FirestoreService firestoreService;

  const HomeBentoGrid({
    super.key,
    required this.uid,
    required this.monthlyBudget,
    required this.netWorth,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C22) : Colors.white;

    return StreamBuilder<double>(
      stream: firestoreService.getMonthlyExpenseStream(uid),
      builder: (context, monthlySnapshot) {
        final totalMonthlySpent = monthlySnapshot.data ?? 0.0;

        return StreamBuilder<double>(
          stream: firestoreService.getMonthlyIncomeStream(uid),
          builder: (context, incomeSnapshot) {
            final totalMonthlyIncome = incomeSnapshot.data ?? 0.0;
            final hasBudget = monthlyBudget > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasBudget) ...[
                      HomeBudgetTracker(
                        monthlyBudget: monthlyBudget,
                        totalExpense: totalMonthlySpent,
                        isEmbedded: true,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.05),
                      ),
                      const SizedBox(height: 16),
                    ],
                    HomeObserverCard(
                      netWorth: netWorth,
                      monthlyIncome: totalMonthlyIncome,
                      isEmbedded: true,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

