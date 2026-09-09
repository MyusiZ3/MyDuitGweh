import 'dart:math';
import 'package:flutter/material.dart';

/// A premium section card with a shallow top-center notch cutout and floating tapered smile-shaped capsule accent.
class NotchedSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double notchWidth;
  final double notchHeight;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final Color? pillColor;
  final double pillWidth;
  final double pillHeight;
  final VoidCallback? onTap;

  const NotchedSectionCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.radius = 24,
    this.notchWidth = 65,
    this.notchHeight = 13,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.pillColor,
    this.pillWidth = 30,
    this.pillHeight = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        backgroundColor ?? (isDark ? const Color(0xFF1C1C22) : Colors.white);
    final border = borderColor ??
        (isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04));
    final shadow =
        shadowColor ?? Colors.black.withOpacity(isDark ? 0.25 : 0.04);

    final pill = pillColor ?? cardBg;

    final effectivePadding =
        padding ?? EdgeInsets.fromLTRB(20, 8 + notchHeight, 20, 18);

    Widget cardWidget = CustomPaint(
      painter: TopNotchedCardPainter(
        color: cardBg,
        borderColor: border,
        shadowColor: shadow,
        radius: radius,
        notchWidth: notchWidth,
        notchHeight: notchHeight,
        pillColor: pill,
        pillWidth: pillWidth,
        pillHeight: pillHeight,
      ),
      child: Padding(
        padding: effectivePadding,
        child: child,
      ),
    );

    if (onTap != null) {
      cardWidget = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: cardWidget,
      );
    }

    if (margin != null) {
      cardWidget = Padding(
        padding: margin!,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

/// Custom Painter for Card with Shallow Top-Center Notch Cutout & Tapered Smile-Shaped Capsule Accent
class TopNotchedCardPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color shadowColor;
  final double radius;
  final double notchWidth;
  final double notchHeight;
  final Color pillColor;
  final double pillWidth;
  final double pillHeight;

  TopNotchedCardPainter({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
    this.radius = 24,
    this.notchWidth = 65,
    this.notchHeight = 13,
    required this.pillColor,
    this.pillWidth = 30,
    this.pillHeight = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final path = getTopNotchedPath(
      size,
      radius: radius,
      notchWidth: notchWidth,
      notchHeight: notchHeight,
    );

    // 1. Draw Drop Shadow following the notched contour
    canvas.drawShadow(path, shadowColor, 10, false);

    // 2. Fill Card
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Draw Border Stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);

    // 4. Draw Floating Tapered Smile Capsule Accent centered in upper notch dip
    final cx = size.width / 2;
    final pillCy = 4.8;

    final pillPath = getSmilePillPath(
      Offset(cx, pillCy),
      pillWidth,
      pillHeight,
    );

    final pillPaint = Paint()
      ..color = pillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(pillPath, pillPaint);
  }

  @override
  bool shouldRepaint(covariant TopNotchedCardPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.pillColor != pillColor ||
        oldDelegate.radius != radius ||
        oldDelegate.notchWidth != notchWidth ||
        oldDelegate.notchHeight != notchHeight ||
        oldDelegate.pillWidth != pillWidth ||
        oldDelegate.pillHeight != pillHeight;
  }
}

/// Helper to generate the tapered smile-shaped capsule path (thin at edges, thick smile in center)
Path getSmilePillPath(Offset center, double width, double height) {
  final path = Path();
  final w = width;
  final h = height;
  final cx = center.dx;
  final topY = center.dy - h * 0.35;
  final bottomY = center.dy + h * 0.65;
  final tipRadius = 2.1; // Thin tapered tip radius at left and right ends

  // 1. Top-left start
  path.moveTo(cx - w / 2 + tipRadius, topY);

  // 2. Top edge (flat across)
  path.lineTo(cx + w / 2 - tipRadius, topY);

  // 3. Right thin tapered tip arc turning down
  path.arcToPoint(
    Offset(cx + w / 2, topY + tipRadius),
    radius: Radius.circular(tipRadius),
    clockwise: true,
  );

  // 4. Smooth tapered U-curve dipping down in the center
  path.cubicTo(
    cx + w * 0.22,
    bottomY + 1.0,
    cx - w * 0.22,
    bottomY + 1.0,
    cx - w / 2,
    topY + tipRadius,
  );

  // 5. Left thin tapered tip arc turning up
  path.arcToPoint(
    Offset(cx - w / 2 + tipRadius, topY),
    radius: Radius.circular(tipRadius),
    clockwise: true,
  );

  path.close();
  return path;
}

/// Helper to generate the top-notched card path with smooth shallow S-curves
Path getTopNotchedPath(
  Size size, {
  double radius = 24,
  double notchWidth = 60,
  double notchHeight = 13,
}) {
  final w = size.width;
  final h = size.height;
  final r = radius.clamp(0.0, min(w / 2, h / 2)).toDouble();
  final nw = notchWidth.clamp(20.0, w - (r * 2)).toDouble();
  final nh = notchHeight.clamp(4.0, h / 3).toDouble();

  final path = Path();
  final cx = w / 2;

  // Start top-left corner
  path.moveTo(r, 0);

  // Line to start of notch
  path.lineTo(cx - nw / 2, 0);

  // Smooth shallow S-curve dip into notch center and out to right
  path.cubicTo(
    cx - nw * 0.28,
    0,
    cx - nw * 0.22,
    nh,
    cx,
    nh,
  );
  path.cubicTo(
    cx + nw * 0.22,
    nh,
    cx + nw * 0.28,
    0,
    cx + nw / 2,
    0,
  );

  // Line to top-right corner
  path.lineTo(w - r, 0);

  // Top-right corner arc
  path.arcToPoint(Offset(w, r), radius: Radius.circular(r), clockwise: true);

  // Right edge
  path.lineTo(w, h - r);

  // Bottom-right corner arc
  path.arcToPoint(Offset(w - r, h),
      radius: Radius.circular(r), clockwise: true);

  // Bottom edge
  path.lineTo(r, h);

  // Bottom-left corner arc
  path.arcToPoint(Offset(0, h - r),
      radius: Radius.circular(r), clockwise: true);

  // Left edge
  path.lineTo(0, r);

  // Top-left corner arc
  path.arcToPoint(Offset(r, 0), radius: Radius.circular(r), clockwise: true);

  path.close();
  return path;
}
