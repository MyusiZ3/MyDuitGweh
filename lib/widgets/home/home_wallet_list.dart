import 'package:flutter/material.dart';
import '../../models/wallet_model.dart';
import '../../utils/currency_formatter.dart';
import '../../screens/main_nav.dart';

class HomeWalletList extends StatelessWidget {
  final List<WalletModel> wallets;

  const HomeWalletList({
    super.key,
    required this.wallets,
  });

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: wallets.length,
        itemBuilder: (context, index) {
          final w = wallets[index];
          return GestureDetector(
            onTap: () => MainNav.of(context)?.setTab(1),
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    w.walletName,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    child: Text(
                      CurrencyFormatter.formatCurrency(w.balance),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
