import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';

import '../notched_section_card.dart';

class HomeBudgetTracker extends StatelessWidget {
  final double totalExpense;
  final double monthlyBudget;
  final bool isEmbedded;

  const HomeBudgetTracker({
    super.key,
    required this.totalExpense,
    required this.monthlyBudget,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (monthlyBudget == 0.0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (totalExpense / monthlyBudget).clamp(0.0, 1.0);

    final currentMonth = DateFormat('MMMM', 'id_ID').format(DateTime.now());

    // Dynamic pastel gradient colors and text highlight based on budget percentage threshold
    final List<Color> gradientColors;
    final Color percentTextColor;

    if (percent <= 0.40) {
      percentTextColor = AppColors.income; // 0xFF34D399
      gradientColors = const [
        Color(0xFF34D399),
        Color(0xFF6EE7B7),
      ];
    } else if (percent <= 0.70) {
      percentTextColor = AppColors.warning; // 0xFFFBBF24
      gradientColors = const [
        Color(0xFF34D399),
        Color(0xFFFBBF24),
      ];
    } else {
      percentTextColor = AppColors.expense; // 0xFFF87171
      gradientColors = const [
        Color(0xFFFBBF24),
        Color(0xFFF87171),
      ];
    }

    final remainingBudget = monthlyBudget - totalExpense;

    final content = Column(
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
                color: percentTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Modern Interactive Gradient Progress Bar
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final filledWidth = barWidth * percent;

            return Container(
              height: 8,
              width: barWidth,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  width: filledWidth,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
                  remainingBudget < 0
                      ? 'Overbudget: ${CurrencyFormatter.formatCurrency(remainingBudget.abs())}'
                      : 'Sisa: ${CurrencyFormatter.formatCurrency(remainingBudget)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: remainingBudget < 0
                        ? AppColors.expense
                        : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
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
    );

    if (isEmbedded) return content;

    return NotchedSectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: content,
    );
  }
}
