import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/tone_dictionary.dart';
import '../bottom_sheets/create_wallet_sheet.dart';


import '../../utils/app_theme.dart';

class HomeBalanceCard extends StatelessWidget {
  final double totalBalance;
  final double netWorth;
  final double todayExpense;
  final bool isBalanceVisible;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onAddWallet;

  const HomeBalanceCard({
    super.key,
    required this.totalBalance,
    required this.netWorth,
    required this.todayExpense,
    required this.isBalanceVisible,
    required this.onToggleVisibility,
    this.onAddWallet,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      height: 235,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Backing Stacked Card Peek (Warm Soft Pastel Peach/Sand)
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFFE09F56) : const Color(0xFFFFC069),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF18181B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B).withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '•••• •••• 2585',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFF18181B)
                          : const Color(0xFF18181B),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Main Front Credit Card (Soft Desaturated Periwinkle Lavender with Notched Corner)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Custom Paint for Notched Card Shadow and Solid Fill
                Positioned.fill(
                  child: CustomPaint(
                    painter: NotchedCardPainter(
                      color: isDark
                          ? const Color(0xFF6B64DB)
                          : AppColors.primary,
                      shadowColor: (isDark
                              ? const Color(0xFF6B64DB)
                              : AppColors.primary)
                          .withOpacity(isDark ? 0.4 : 0.3),
                      radius: 28,
                      notchWidth: 140,
                      notchHeight: 52,
                      sCurveRadius: 26,
                    ),
                    child: ClipPath(
                      clipper: NotchedCardClipper(
                        radius: 28,
                        notchWidth: 140,
                        notchHeight: 52,
                        sCurveRadius: 26,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Header Row inside Card
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.wallet_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'MyDuit Card',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '•••• •••• 7845',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Balance Label & Toggle
                            Row(
                              children: [
                                Text(
                                  ToneManager.t('home_balance'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: onToggleVisibility,
                                  child: Icon(
                                    isBalanceVisible
                                        ? CupertinoIcons.eye_fill
                                        : CupertinoIcons.eye_slash_fill,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Large Balance Display
                            FittedBox(
                              child: Text(
                                isBalanceVisible
                                    ? CurrencyFormatter.formatCurrency(
                                        totalBalance)
                                    : 'Rp ••••••••',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.0,
                                ),
                              ),
                            ),
                            const Spacer(),

                            // Bottom Info: Today's Expense
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ToneManager.t('date_today'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  todayExpense > 0
                                      ? '- ${CurrencyFormatter.formatCurrency(todayExpense)}'
                                      : CurrencyFormatter.formatCurrency(0),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Overlapping Action Pill Button inside Notched Corner (+ Add Wallet)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      if (onAddWallet != null) {
                        onAddWallet!();
                      } else {
                        showCreateWalletSheet(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.14) : Colors.transparent,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.4 : 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF4F4F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.add,
                              color: Color(0xFF18181B),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ToneManager.t('add_wallet'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for Credit Card with Notched Corner Shadow and Fill
class NotchedCardPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;
  final double radius;
  final double notchWidth;
  final double notchHeight;
  final double sCurveRadius;

  NotchedCardPainter({
    required this.color,
    required this.shadowColor,
    this.radius = 28,
    this.notchWidth = 154,
    this.notchHeight = 52,
    this.sCurveRadius = 26,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getSteppedCardPath(
      size,
      radius: radius,
      notchWidth: notchWidth,
      notchHeight: notchHeight,
      sCurveRadius: sCurveRadius,
    );

    // Draw elevation drop shadow following exact notched contour
    canvas.drawShadow(path, shadowColor, 12, false);

    // Fill card body
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NotchedCardPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shadowColor != shadowColor;
}

/// Custom Clipper for Credit Card with Inverted Notch Cutout at Bottom-Right
class NotchedCardClipper extends CustomClipper<Path> {
  final double radius;
  final double notchWidth;
  final double notchHeight;
  final double sCurveRadius;

  NotchedCardClipper({
    this.radius = 28,
    this.notchWidth = 154,
    this.notchHeight = 52,
    this.sCurveRadius = 26,
  });

  @override
  Path getClip(Size size) {
    return _getSteppedCardPath(
      size,
      radius: radius,
      notchWidth: notchWidth,
      notchHeight: notchHeight,
      sCurveRadius: sCurveRadius,
    );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Helper function to build the stepped card path with straight right edge and single S-curve bottom transition
Path _getSteppedCardPath(
  Size size, {
  double radius = 28,
  double notchWidth = 154,
  double notchHeight = 52,
  double sCurveRadius = 26,
}) {
  final w = size.width;
  final h = size.height;
  final path = Path();

  final r = radius.clamp(0.0, h / 2);
  final rS = sCurveRadius.clamp(0.0, notchHeight / 2);

  // 1. Start top-left
  path.moveTo(r, 0);

  // 2. Top edge
  path.lineTo(w - r, 0);

  // 3. Top-right corner (convex)
  path.arcToPoint(
    Offset(w, r),
    radius: Radius.circular(r),
    clockwise: true,
  );

  // 4. Right edge going straight down to the shorter bottom-right corner
  path.lineTo(w, h - notchHeight - r);

  // 5. Shorter Bottom-Right corner (convex) turning left above + Add Wallet
  path.arcToPoint(
    Offset(w - r, h - notchHeight),
    radius: Radius.circular(r),
    clockwise: true,
  );

  // 6. Horizontal line going left across the top of + Add Wallet
  final sCurveX = w - notchWidth;
  path.lineTo(sCurveX + rS, h - notchHeight);

  // 7. S-Curve top transition: concave curve turning down
  path.arcToPoint(
    Offset(sCurveX, h - notchHeight + rS),
    radius: Radius.circular(rS),
    clockwise: false,
  );

  // 8. Continuous S-Curve bottom transition: convex curve turning left to bottom edge
  path.arcToPoint(
    Offset(sCurveX - rS, h),
    radius: Radius.circular(rS),
    clockwise: true,
  );

  // 9. Bottom edge going left to bottom-left corner
  path.lineTo(r, h);

  // 10. Bottom-left corner (convex)
  path.arcToPoint(
    Offset(0, h - r),
    radius: Radius.circular(r),
    clockwise: true,
  );

  // 11. Left edge going up
  path.lineTo(0, r);

  // 12. Top-left corner (convex)
  path.arcToPoint(
    Offset(r, 0),
    radius: Radius.circular(r),
    clockwise: true,
  );

  path.close();
  return path;
}
