import 'package:flutter/material.dart';
import '../../utils/tone_dictionary.dart';
import '../../screens/main_nav.dart';

class HomeRecentTransactionsHeader extends StatelessWidget {
  const HomeRecentTransactionsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 32, bottom: 4),
      sliver: SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                ToneManager.t('home_recent'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              GestureDetector(
                onTap: () => MainNav.of(context)?.setTab(2),
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF4F46E5),
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
