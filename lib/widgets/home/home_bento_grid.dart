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
    return StreamBuilder<double>(
      stream: firestoreService.getMonthlyExpenseStream(uid),
      builder: (context, monthlySnapshot) {
        final totalMonthlySpent = monthlySnapshot.data ?? 0.0;

        return StreamBuilder<double>(
          stream: firestoreService.getMonthlyIncomeStream(uid),
          builder: (context, incomeSnapshot) {
            final totalMonthlyIncome = incomeSnapshot.data ?? 0.0;

            return Column(
              children: [
                if (monthlyBudget > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: HomeBudgetTracker(
                      monthlyBudget: monthlyBudget,
                      totalExpense: totalMonthlySpent,
                    ),
                  ),
                if (monthlyBudget > 0) const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: HomeObserverCard(
                    netWorth: netWorth,
                    monthlyIncome: totalMonthlyIncome,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

