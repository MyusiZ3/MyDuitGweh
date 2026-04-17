import 'dart:ui' as ui;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Mesh Gradient Background
            _buildMeshBackground(isDark),

            // Content Overlay
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ToneManager.t('home_balance'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      _buildVisibilityToggle(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      isBalanceVisible
                          ? CurrencyFormatter.formatCurrency(totalBalance)
                          : 'Rp ••••••••',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                  if (netWorth != totalBalance && isBalanceVisible) ...[
                    const SizedBox(height: 6),
                    _buildNetWorthBadge(),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _balanceAction(
                          context,
                          CupertinoIcons.creditcard_fill,
                          ToneManager.t('nav_wallet'),
                          () => MainNav.of(context)?.setTab(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _balanceAction(
                          context,
                          CupertinoIcons.chart_pie_fill,
                          ToneManager.t('nav_report'),
                          () => MainNav.of(context)?.setTab(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBackground(bool isDark) {
    return Stack(
      children: [
        // Solid base
        Container(
          color: isDark ? const Color(0xFF001A33) : AppColors.primary,
        ),
        // Glow 1
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF00C6FF).withOpacity(0.4),
                  const Color(0xFF00C6FF).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        // Glow 2
        Positioned(
          bottom: -40,
          left: -20,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF2D55).withOpacity(0.3),
                  const Color(0xFFFF2D55).withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        // Blur Layer
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Subtle Noise/Texture or Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityToggle() {
    return GestureDetector(
      onTap: onToggleVisibility,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isBalanceVisible ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildNetWorthBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${ToneManager.t('home_net_worth')} ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            CurrencyFormatter.formatCurrency(netWorth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800, // Refined from w900
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceAction(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700, // Refined from w800
                    letterSpacing: -0.2,
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
