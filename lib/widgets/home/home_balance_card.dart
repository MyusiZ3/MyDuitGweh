import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/tone_dictionary.dart';
import '../../screens/main_nav.dart';

class HomeBalanceCard extends StatelessWidget {
  final double totalBalance;
  final double netWorth;
  final bool isBalanceVisible;
  final VoidCallback onToggleVisibility;

  const HomeBalanceCard({
    super.key,
    required this.totalBalance,
    required this.netWorth,
    required this.isBalanceVisible,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                ToneManager.t('home_balance'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: onToggleVisibility,
                child: Icon(
                  isBalanceVisible ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              isBalanceVisible
                  ? CurrencyFormatter.formatCurrency(totalBalance)
                  : 'Rp ••••••••',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
          ),
          if (netWorth != totalBalance && isBalanceVisible) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Kekayaan Bersih ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCurrency(netWorth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _balanceAction(
                        context,
                        Icons.account_balance_wallet_rounded,
                        ToneManager.t('nav_wallet'),
                        () => MainNav.of(context)?.setTab(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _balanceAction(
                        context,
                        CupertinoIcons.graph_circle,
                        ToneManager.t('nav_report'),
                        () => MainNav.of(context)?.setTab(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceAction(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
