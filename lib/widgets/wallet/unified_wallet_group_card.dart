import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../models/wallet_model.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';
import '../notched_section_card.dart';

class UnifiedWalletGroupCard extends StatelessWidget {
  final List<WalletModel> wallets;
  final double totalBalance;
  final bool isColab;
  final Function(WalletModel) onWalletTap;

  const UnifiedWalletGroupCard({
    super.key,
    required this.wallets,
    required this.totalBalance,
    required this.isColab,
    required this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);
    final headerTitleColor = isDark ? Colors.white54 : const Color(0xFF71717A);
    final mainTextColor = isDark ? Colors.white : const Color(0xFF18181B);

    return NotchedSectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isColab ? 'TOTAL DOMPET BERSAMA' : 'TOTAL DOMPET PRIBADI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: headerTitleColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatCurrency(totalBalance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: mainTextColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF27272A)
                        : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${wallets.length} Dompet',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF71717A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: wallets.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              indent: 68,
              endIndent: 16,
              color: dividerColor,
            ),
            itemBuilder: (context, index) {
              final wallet = wallets[index];
              final isLast = index == wallets.length - 1;

              return WalletRowItem(
                wallet: wallet,
                isLast: isLast,
                onTap: () => onWalletTap(wallet),
              );
            },
          ),
        ],
      ),
    );
  }
}

class WalletRowItem extends StatelessWidget {
  final WalletModel wallet;
  final bool isLast;
  final VoidCallback onTap;

  const WalletRowItem({
    super.key,
    required this.wallet,
    required this.isLast,
    required this.onTap,
  });

  Widget _buildIcon(BuildContext context, bool isDark) {
    final iconBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
    final iconColor = isDark ? Colors.white : const Color(0xFF18181B);

    if (wallet.isDebt) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.doc_text_fill,
          color: wallet.debtType == 'payable'
              ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
              : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
          size: 18,
        ),
      );
    }

    if (wallet.isColab) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF27272A)
              : AppColors.primary.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          CupertinoIcons.person_2_fill,
          color: isDark ? Colors.white : AppColors.primary,
          size: 18,
        ),
      );
    }

    switch (wallet.type) {
      case 'cash':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.money_dollar_circle_fill,
            color: iconColor,
            size: 18,
          ),
        );
      case 'e-wallet':
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.device_phone_portrait,
            color: iconColor,
            size: 18,
          ),
        );
      default:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.wallet_rounded,
            color: iconColor,
            size: 19,
          ),
        );
    }
  }

  String? get _subtitle {
    if (wallet.isDebt) {
      final label = wallet.debtType == 'payable' ? 'Hutang' : 'Piutang';
      final name = wallet.debtorName?.isNotEmpty == true
          ? ' · ${wallet.debtorName}'
          : '';
      return '$label$name';
    }
    if (wallet.isColab) return '${wallet.members.length} Anggota';
    switch (wallet.type) {
      case 'bank':
        return 'Bank';
      case 'cash':
        return 'Tunai';
      case 'e-wallet':
        return 'E-Wallet';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mainTextColor = isDark ? Colors.white : const Color(0xFF18181B);
    final subTextColor = isDark ? Colors.white54 : const Color(0xFF71717A);
    final sub = _subtitle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        highlightColor: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        hoverColor: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        focusColor: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
        splashColor: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.vertical(
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _buildIcon(context, isDark),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      wallet.walletName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: mainTextColor,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.formatCurrency(wallet.balance),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: wallet.isDebt && wallet.debtType == 'payable'
                          ? (isDark
                              ? const Color(0xFFF87171)
                              : const Color(0xFFDC2626))
                          : mainTextColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: isDark ? Colors.white24 : Colors.black26,
                    size: 14,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
