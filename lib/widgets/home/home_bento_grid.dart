import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/tone_dictionary.dart';
import '../../services/firestore_service.dart';
import 'home_budget_tracker.dart';
import 'package:flutter/services.dart';

class HomeBentoGrid extends StatelessWidget {
  final String uid;
  final double monthlyBudget;
  final FirestoreService firestoreService;

  const HomeBentoGrid({
    super.key,
    required this.uid,
    required this.monthlyBudget,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: firestoreService.getMonthlyExpenseStream(uid),
      builder: (context, monthlySnapshot) {
        final totalMonthlySpent = monthlySnapshot.data ?? 0.0;

        return StreamBuilder<double>(
          stream: firestoreService.getTodayExpenseStream(uid),
          builder: (context, todaySnapshot) {
            final todaySpent = todaySnapshot.data ?? 0.0;

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
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _BentoCard(
                            title: ToneManager.t('date_today'),
                            value: CurrencyFormatter.formatCurrency(todaySpent),
                            icon: CupertinoIcons.today,
                            color: AppColors.expense.withOpacity(0.1),
                            iconColor: AppColors.expense,
                            subtitle: 'Total hari ini',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ValueListenableBuilder<AppTone>(
                            valueListenable: ToneManager.notifier,
                            builder: (context, tone, _) {
                              final currentTip = ToneManager.getSmartTip(
                                todaySpent: todaySpent,
                                monthlyBudget: monthlyBudget,
                                totalMonthlySpent: totalMonthlySpent,
                              );
                              return _BentoCard(
                                title: 'Tips',
                                value: currentTip,
                                icon: CupertinoIcons.lightbulb_fill,
                                color: Colors.amber.withOpacity(0.1),
                                iconColor: Colors.amber,
                                subtitle: 'Simak rekomendasi',
                                onTap: () =>
                                    _showTipDetail(context, currentTip),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTipDetail(BuildContext context, String tip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TipDetailSheet(tip: tip),
    );
  }
}

class _TipDetailSheet extends StatelessWidget {
  final String tip;

  const _TipDetailSheet({required this.tip});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.lightbulb_fill,
                  color: Colors.amber, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rekomendasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tip,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                borderRadius: BorderRadius.circular(16),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  ToneManager.t('btn_confirm'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BentoCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String subtitle;
  final VoidCallback? onTap;

  const _BentoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.subtitle,
    this.onTap,
  });

  @override
  State<_BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<_BentoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        if (widget.onTap != null) {
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
