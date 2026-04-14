import 'package:flutter/material.dart';
import '../../utils/tone_dictionary.dart';
import '../../screens/main_nav.dart';

class HomeRecentTransactionsHeader extends StatelessWidget {
  const HomeRecentTransactionsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 32,
          bottom: 16,
          left: 24,
          right: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ToneManager.t('home_recent'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
            ),
            TextButton(
              onPressed: () => MainNav.of(context)?.setTab(4),
              child: const Text(
                'Semua',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
