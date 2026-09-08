import 'package:flutter/material.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/financial_logic.dart';

class HomeObserverCard extends StatelessWidget {
  final double netWorth;
  final double monthlyIncome;

  const HomeObserverCard({
    super.key,
    required this.netWorth,
    required this.monthlyIncome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zakatAmount = FinancialLogic.calculateZakat(netWorth);
    final taxAmount = FinancialLogic.calculateTax(monthlyIncome);
    final reachesNisab = FinancialLogic.reachesNisab(netWorth);

    final cardBg = isDark ? const Color(0xFF1C1C22) : Colors.white;
    final zakatStatusColor = reachesNisab
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
        : (isDark ? Colors.white38 : const Color(0xFF9CA3AF));

    return Container(
      width: double.infinity,
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
          Text(
            'Kewajiban Finansial',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: isDark ? Colors.white : const Color(0xFF18181B),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  context,
                  title: 'Zakat',
                  amount: zakatAmount,
                  statusText: reachesNisab ? 'Wajib Zakat' : 'Belum Nisab',
                  statusColor: zakatStatusColor,
                ),
              ),
              Container(
                width: 1,
                height: 42,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
              ),
              Expanded(
                child: _buildMetricItem(
                  context,
                  title: 'Pajak',
                  amount: taxAmount,
                  statusText: 'Estimasi PPh',
                  statusColor:
                      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String title,
    required double amount,
    required String statusText,
    required Color statusColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                statusText,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            CurrencyFormatter.formatCurrency(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF18181B),
            ),
          ),
        ),
      ],
    );
  }
}

