import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../utils/app_theme.dart';
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
    final nisabProgress = FinancialLogic.getNisabProgress(netWorth);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(CupertinoIcons.shield_lefthalf_fill,
                    color: Colors.indigo, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Financial Observer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildObligationItem(
                  context,
                  title: 'Estimasi Zakat',
                  amount: zakatAmount,
                  icon: CupertinoIcons.heart_fill,
                  color: Colors.teal,
                  subtitle: reachesNisab ? 'Wajib Zakat' : 'Belum Nisab',
                  progress: nisabProgress,
                ),
              ),
              Container(
                width: 1,
                height: 60,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Theme.of(context).dividerColor.withOpacity(0.1),
              ),
              Expanded(
                child: _buildObligationItem(
                  context,
                  title: 'Estimasi Pajak',
                  amount: taxAmount,
                  icon: CupertinoIcons.doc_text_fill,
                  color: Colors.orange,
                  subtitle: 'Proyeksi bulanan',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildObligationItem(
    BuildContext context, {
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
    required String subtitle,
    double? progress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.bodySmall?.color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          CurrencyFormatter.formatCurrency(amount),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: amount > 0 
                  ? color.withOpacity(0.8) 
                  : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (progress != null && progress < 1.0) ...[
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.5)),
                    minHeight: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
