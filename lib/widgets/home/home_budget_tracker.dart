import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';

class HomeBudgetTracker extends StatelessWidget {
  final double totalExpense;
  final double monthlyBudget;

  const HomeBudgetTracker({
    super.key,
    required this.totalExpense,
    required this.monthlyBudget,
  });

  @override
  Widget build(BuildContext context) {
    if (monthlyBudget == 0.0) return const SizedBox.shrink();
    
    final percent = (totalExpense / monthlyBudget).clamp(0.0, 1.0);
    final isWarning = percent > 0.8;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Target Budget Bulanan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isWarning ? AppColors.expense : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              color: isWarning ? AppColors.expense : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sisa: ${CurrencyFormatter.formatCurrency(monthlyBudget - totalExpense)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Dari ${CurrencyFormatter.formatCurrency(monthlyBudget)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
