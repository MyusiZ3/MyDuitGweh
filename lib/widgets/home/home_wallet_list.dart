import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../models/wallet_model.dart';
import '../../utils/currency_formatter.dart';
import '../../screens/main_nav.dart';
import '../../utils/app_theme.dart';

class HomeWalletList extends StatelessWidget {
  final List<WalletModel> wallets;

  const HomeWalletList({
    super.key,
    required this.wallets,
  });

  @override
  Widget build(BuildContext context) {
    if (wallets.isEmpty) return const SizedBox.shrink();

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.05, 0.95, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: wallets.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildAddWalletButton(context);
            }

            final w = wallets[index - 1];
            return _buildWalletCard(context, w);
          },
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, WalletModel w) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor;
    Color textColor = Colors.white;
    Color subColor = Colors.white.withOpacity(0.7);

    switch (w.type) {
      case 'bank':
        cardColor = const Color(0xFF007AFF);
        break;
      case 'cash':
        cardColor = const Color(0xFF34C759);
        break;
      case 'e-wallet':
        cardColor = const Color(0xFF5856D6);
        break;
      default:
        cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        if (!isDark) {
          textColor = AppColors.textPrimary;
          subColor = AppColors.textSecondary;
        }
    }

    return _AnimatedActionCard(
      onTap: () => MainNav.of(context)?.setTab(1),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          gradient: cardColor == Colors.white
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cardColor.withOpacity(0.9),
                    cardColor,
                  ],
                ),
          borderRadius: BorderRadius.circular(22),
          border: cardColor == Colors.white
              ? Border.all(color: Colors.black.withOpacity(0.05))
              : null,
          boxShadow: [
            BoxShadow(
              color: cardColor == Colors.white
                  ? Colors.black.withOpacity(0.03)
                  : cardColor.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _getWalletIcon(w.type),
                  size: 18,
                  color: cardColor == Colors.white
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.9),
                ),
                if (w.type == 'colab') ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SHARED',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.walletName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  child: Text(
                    CurrencyFormatter.formatCurrency(w.balance),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddWalletButton(BuildContext context) {
    return _AnimatedActionCard(
      onTap: () => MainNav.of(context)?.setTab(1),
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.plus,
                color: Theme.of(context).hintColor,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                'BARU',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).hintColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getWalletIcon(String type) {
    switch (type) {
      case 'colab':
        return CupertinoIcons.person_2_fill;
      default:
        return CupertinoIcons.creditcard_fill;
    }
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedActionCard({
    required this.child,
    required this.onTap,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
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
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
