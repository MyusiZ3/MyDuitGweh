import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (totalExpense / monthlyBudget).clamp(0.0, 1.0);
    final isWarning = percent > 0.8;

    final currentMonth = DateFormat('MMMM', 'id_ID').format(DateTime.now());
    final accentColor = isWarning
        ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
        : (isDark ? const Color(0xFF6B64DB) : const Color(0xFF8B85F6));

    final cardBg = isDark ? const Color(0xFF1C1C22) : Colors.white;

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget $currentMonth',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : const Color(0xFF18181B),
                ),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 5,
              backgroundColor:
                  isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFF4F4F5),
              color: accentColor,
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
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
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
                      fontSize: 12,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
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
