import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui' as ui;
import '../utils/app_theme.dart';
import '../utils/tone_dictionary.dart';
import '../utils/navigator_key.dart';

class UIHelper {
  static OverlayEntry? _connectivityOverlayEntry;

  static void showSuccessSnackBar(BuildContext context, String message) {
    _showTopToast(context, message, AppColors.income,
        CupertinoIcons.check_mark_circled_solid);
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    _showTopToast(context, message, AppColors.expense, CupertinoIcons.info);
  }

  static void showInfoSnackBar(BuildContext context, String message) {
    _showTopToast(context, message, Colors.blueGrey, CupertinoIcons.info);
  }

  static void showGlobalInfoToast(String message,
      {Color color = Colors.blueGrey,
      IconData icon = CupertinoIcons.shield_fill}) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      _showTopToast(context, message, color, icon);
    } else {
      debugPrint(
          '--- UIHelper: GLOBAL TOAST FAILED - Context is NULL. Message: $message');
    }
  }

  static void _showTopToast(
      BuildContext context, String message, Color color, IconData icon) {
    try {
      final overlay = Overlay.maybeOf(context);
      if (overlay == null) {
        debugPrint(
            '--- UIHelper: Overlay.of(context) is NULL. Cannot show toast: $message');
        return;
      }

      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, -50 * (1 - value)),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xF22C2C2E) // 0.95 opacity
                        : const Color(0xF21C1C1E), // 0.95 opacity
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: const Color(0x26FFFFFF), width: 0.5),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 10,
                          offset: Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(message,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

      overlay.insert(overlayEntry);
      Future.delayed(const Duration(seconds: 3), () {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      });
    } catch (e) {
      debugPrint('--- UIHelper: Error showing toast: $e');
    }
  }

  static void showNoInternetOverlay() {
    final context = navigatorKey.currentContext;
    if (context == null || _connectivityOverlayEntry != null) return;

    final overlay = Overlay.of(context);
    _connectivityOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 100 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xF2D32F2F), // 0.95 opacity red
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0x33FFFFFF), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.wifi_exclamationmark,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ToneManager.t('offline_mode_title'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              ToneManager.t('offline_mode_msg'),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    overlay.insert(_connectivityOverlayEntry!);
  }

  static void hideNoInternetOverlay() {
    if (_connectivityOverlayEntry != null) {
      _connectivityOverlayEntry?.remove();
      _connectivityOverlayEntry = null;

      // Show success toast when back online
      final context = navigatorKey.currentContext;
      if (context != null) {
        showSuccessSnackBar(context, ToneManager.t('online_mode_msg'));
      }
    }
  }

  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDangerous = true,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 6)),
              ],
            ),
            child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isDangerous
                                  ? AppColors.expense
                                  : AppColors.primary)
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDangerous
                              ? CupertinoIcons.trash
                              : CupertinoIcons.info,
                          color: isDangerous
                              ? AppColors.expense
                              : AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      Text(message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).hintColor,
                              fontSize: 14,
                              height: 1.5)),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(context, false),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.2)),
                                ),
                                child: Center(
                                  child: Text(
                                      cancelText ?? ToneManager.t('dialog_no'),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                          fontSize: 13)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.pop(context, true),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isDangerous
                                      ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.redAccent
                                          : Colors.black)
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: (isDangerous
                                                ? Colors.black
                                                : AppColors.primary)
                                            .withOpacity(0.25),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5)),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                      confirmText ??
                                          ToneManager.t('dialog_yes'),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13)),
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
      transitionBuilder: (context, anim1, anim2, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim1, child: child),
      ),
    );
  }

  static Future<T?> showPremiumDialog<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 6)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: child,
            ),
          ),
        ),
      transitionBuilder: (context, anim1, anim2, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim1, child: child),
      ),
    );
  }

  static Future<void> showInfoDialog(
      BuildContext context, String title, String message) {
    return showPremiumDialog(
        context: context,
        child: Builder(builder: (dialogContext) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.doc_text_fill,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 24),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 14,
                      height: 1.5)),
              const SizedBox(height: 32),
              InkWell(
                onTap: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.surfaceVariantDark
                        : Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Center(
                    child: Text(ToneManager.t('info_button'),
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ),
                ),
              ),
            ],
          );
        }));
  }

  static void showLoadingDialog(BuildContext context, {String? message}) {
    final effectiveMessage = message ?? ToneManager.t('loading_msg');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                effectiveMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showAiMaintenanceDialog(BuildContext context) {
    return showPremiumDialog(
        context: context,
        child: Builder(builder: (dialogContext) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.expense.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(CupertinoIcons.hammer_fill,
                      color: AppColors.expense, size: 40),
                ],
              ),
              const SizedBox(height: 24),
              Text(ToneManager.t('ai_maint_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 12),
              Text(ToneManager.t('ai_maint_msg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 32),
              InkWell(
                onTap: () =>
                    Navigator.of(dialogContext, rootNavigator: true).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.expense,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.expense.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Center(
                    child: Text(ToneManager.t('ai_maint_button'),
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                  ),
                ),
              ),
            ],
          );
        }));
  }

  static void showToneSelector(BuildContext context) {
    showPremiumBottomSheet(
      context: context,
      child: ValueListenableBuilder<AppTone>(
        valueListenable: ToneManager.notifier,
        builder: (context, currentTone, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ToneManager.t('tone_selector_title'),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        Material(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(CupertinoIcons.xmark, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ToneManager.t('tone_selector_subtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                  children: AppTone.values.map((t) {
                    final isSelected = currentTone == t;
                    final isMyBini = t == AppTone.pasangan;
                    final activeColor = isMyBini
                        ? const Color(0xFFFF2D55)
                        : (isDark ? Colors.indigoAccent : AppColors.primary);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await ToneManager.setTone(t);
                          if (context.mounted) {
                            Future.delayed(const Duration(milliseconds: 150),
                                () => Navigator.pop(context));
                          }
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? activeColor.withOpacity(isDark ? 0.2 : 0.1)
                                : isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? activeColor.withOpacity(0.5)
                                  : isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.black.withOpacity(0.05),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: activeColor.withOpacity(0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : [],
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? activeColor.withOpacity(0.2)
                                              : isDark
                                                  ? Colors.white.withOpacity(
                                                      0.05)
                                                  : Colors.grey.withOpacity(
                                                      0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          t == AppTone.genZ
                                              ? '🤘'
                                              : t == AppTone.milenial
                                                  ? '☕'
                                                  : t == AppTone.boomer
                                                      ? '👴'
                                                      : t == AppTone.pasangan
                                                          ? '❤️'
                                                          : '👔',
                                          style: const TextStyle(fontSize: 28),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        isMyBini
                                            ? 'PASANGAN'
                                            : t.name.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                          color: isSelected
                                              ? activeColor
                                              : Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getToneDescription(t),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isSelected
                                              ? activeColor.withOpacity(0.8)
                                              : Theme.of(context).hintColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Icon(
                                    CupertinoIcons.checkmark_circle_fill,
                                    color: activeColor,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  static Future<T?> showPremiumBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: isScrollControlled,
      elevation: 0,
      showDragHandle: false,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: SafeArea(
          bottom: false,
          child: Container(
            margin: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(ctx).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Theme.of(ctx).cardColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: Theme.of(ctx).dividerColor.withOpacity(0.1),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  static String _getToneDescription(AppTone tone) {
    switch (tone) {
      case AppTone.genZ:
        return ToneManager.t('tone_desc_genz');
      case AppTone.milenial:
        return ToneManager.t('tone_desc_milenial');
      case AppTone.boomer:
        return ToneManager.t('tone_desc_boomer');
      case AppTone.pasangan:
        return ToneManager.t('tone_desc_pasangan');
      case AppTone.normal:
        return ToneManager.t('tone_desc_normal');
    }
  }
}
