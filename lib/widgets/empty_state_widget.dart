import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double paddingVertical;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = CupertinoIcons.tray,
    this.actionLabel,
    this.onAction,
    this.paddingVertical = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentPastel = const Color(0xFF6366F1); // Brand Periwinkle Blue

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: paddingVertical),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Outer Glowing Circle
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06),
                  width: 1.2,
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
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentPastel.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: accentPastel,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF18181B),
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              // Subtitle
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              // Action Button
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentPastel,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: accentPastel.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
