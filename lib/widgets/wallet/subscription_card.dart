import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/subscription_model.dart';
import '../../utils/currency_formatter.dart';

class SubscriptionCard extends StatelessWidget {
  final SubscriptionModel subscription;
  final VoidCallback onTap;
  final VoidCallback onPay;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onTap,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check payment status for the current month
    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());
    final isPaid = subscription.isPaidForMonth(currentMonthStr);

    IconData getIcon() {
      switch (subscription.category) {
        case 'Hiburan':
          return CupertinoIcons.play_rectangle_fill;
        case 'Tagihan':
          return CupertinoIcons.doc_text_fill;
        default:
          return CupertinoIcons.arrow_right_arrow_left_square_fill;
      }
    }

    // Off-black (avoid pure #000000) — Apple-style near-black
    const offBlack = Color(0xFF1C1C1E);
    // Icon placeholder
    final iconBg = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF0F0F0);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF3A3A3C);
    // Belum Bayar badge — fully opaque, off-black/dark on light mode
    final unpaidBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEDEDED);
    const unpaidColor = Colors.white;
    const unpaidColorLight = offBlack;
    // Lunas Bulan Ini badge — pastel green fully opaque
    const paidBg = Color(0xFFDCFCE7);          // pastel green light
    const paidBgDark = Color(0xFF166534);      // deep pastel green dark
    const paidColor = Color(0xFF15803D);       // green text light
    const paidColorDark = Color(0xFF86EFAC);   // soft green text dark

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color:
              Theme.of(context).dividerColor.withOpacity(isDark ? 0.05 : 0.08),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        getIcon(),
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscription.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Jatuh tempo: Tanggal ${subscription.dueDay}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatCurrency(subscription.amount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          '/ bulan',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status Badge — fully opaque, no border
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? (isDark ? paidBgDark : paidBg)
                            : unpaidBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPaid
                                ? CupertinoIcons.checkmark_alt_circle_fill
                                : CupertinoIcons.exclamationmark_circle_fill,
                            size: 14,
                            color: isPaid
                                ? (isDark ? paidColorDark : paidColor)
                                : (isDark ? unpaidColor : unpaidColorLight),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaid ? 'Lunas Bulan Ini' : 'Belum Bayar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isPaid
                                  ? (isDark ? paidColorDark : paidColor)
                                  : (isDark ? unpaidColor : unpaidColorLight),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Quick Action button — monochrome
                    if (!isPaid)
                      SizedBox(
                        height: 30,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.2),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            foregroundColor:
                                isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            onPay();
                          },
                          child: Text(
                            'Bayar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
