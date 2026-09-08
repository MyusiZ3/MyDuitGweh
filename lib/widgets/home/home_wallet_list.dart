import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../models/wallet_model.dart';
import '../../utils/currency_formatter.dart';
import '../../screens/main_nav.dart';

class HomeWalletList extends StatelessWidget {
  final List<WalletModel> wallets;
  final bool isBalanceVisible;

  const HomeWalletList({
    super.key,
    required this.wallets,
    this.isBalanceVisible = true,
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
        height: 136,
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

    final cardBg = isDark ? const Color(0xFF1C1C22) : Colors.white;
    final iconBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
    final iconColor = isDark ? Colors.white : const Color(0xFF18181B);
    final badgeBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
    final badgeTextColor = isDark ? Colors.white70 : const Color(0xFF71717A);

    final subTextColor = isDark ? Colors.white54 : const Color(0xFF71717A);
    final mainTextColor = isDark ? Colors.white : const Color(0xFF18181B);

    final String typeLabel = _getWalletTypeLabel(w);

    return _AnimatedActionCard(
      onTap: () => MainNav.of(context)?.setTab(1),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _buildIconWidget(w.type, iconColor),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: badgeTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  w.walletName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isBalanceVisible
                        ? CurrencyFormatter.formatCurrency(w.balance)
                        : '••••••••',
                    style: TextStyle(
                      color: mainTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: isBalanceVisible ? -0.5 : 2,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C22) : Colors.white;
    final iconBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF71717A);

    return _AnimatedActionCard(
      onTap: () => MainNav.of(context)?.setTab(1),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.add,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'BARU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWalletTypeLabel(WalletModel w) {
    if (w.isColab) return 'Shared';
    if (w.isDebt) return 'Hutang';
    switch (w.type) {
      case 'bank':
        return 'Bank';
      case 'cash':
        return 'Tunai';
      case 'e-wallet':
        return 'E-Wallet';
      default:
        return 'Utama';
    }
  }

  Widget _buildIconWidget(String type, Color iconColor) {
    switch (type) {
      case 'colab':
        return Icon(
          CupertinoIcons.person_2_fill,
          size: 18,
          color: iconColor,
        );
      case 'cash':
        return Icon(
          CupertinoIcons.money_dollar_circle_fill,
          size: 18,
          color: iconColor,
        );
      case 'e-wallet':
        return Icon(
          CupertinoIcons.device_phone_portrait,
          size: 18,
          color: iconColor,
        );
      case 'debt':
        return Icon(
          CupertinoIcons.doc_text_fill,
          size: 18,
          color: iconColor,
        );
      default:
        return CardSlotIcon(
          size: 19,
          color: iconColor,
          strokeWidth: 1.8,
        );
    }
  }
}

class CardSlotIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const CardSlotIcon({
    super.key,
    this.size = 20,
    required this.color,
    this.strokeWidth = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CardSlotIconPainter(
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _CardSlotIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _CardSlotIconPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // 1. Bottom slot line
    final slotY = h * 0.84;
    canvas.drawLine(
      Offset(w * 0.16, slotY),
      Offset(w * 0.84, slotY),
      paint,
    );

    // 2. Tilted card entering slot
    canvas.save();
    canvas.translate(w * 0.5, h * 0.44);
    canvas.rotate(-38 * 3.141592653589793 / 180);

    final cardW = w * 0.58;
    final cardH = h * 0.42;
    final cardRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: cardW, height: cardH),
      Radius.circular(w * 0.09),
    );

    canvas.drawRRect(cardRRect, paint);

    // Magnetic strip line inside card
    final stripY = -cardH * 0.18;
    canvas.drawLine(
      Offset(-cardW * 0.36, stripY),
      Offset(cardW * 0.36, stripY),
      paint,
    );

    // Chip detail line inside card
    final detailY = cardH * 0.18;
    final detailPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cardW * 0.04, detailY),
      Offset(cardW * 0.28, detailY),
      detailPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CardSlotIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
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

