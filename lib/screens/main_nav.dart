import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import '../utils/app_theme.dart';
import '../services/receipt_ocr_service.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';
import 'add_transaction_screen.dart';
import 'colab_screen.dart';
import 'report_screen.dart';
import 'receipt_scanner_screen.dart';
import '../utils/ui_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/notification_permission_floating_card.dart';
import '../utils/tone_dictionary.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  static _MainNavState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainNavState>();

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  // Keys to communicate with Screens
  final GlobalKey<WalletScreenState> _walletKey =
      GlobalKey<WalletScreenState>();
  final GlobalKey<ColabScreenState> _colabKey = GlobalKey<ColabScreenState>();

  void startOCRScan() {
    _startOCRScan();
  }

  void setTab(int index) {
    if (index == 2) {
      _showAddTransaction();
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  final Set<int> _activatedIndices = {0, 1, 2, 3};

  late final List<WidgetBuilder> _screenBuilders = [
    (ctx) => const HomeScreen(),
    (ctx) => WalletScreen(key: _walletKey),
    (ctx) => const ReportScreen(),
    (ctx) => ColabScreen(key: _colabKey),
  ];

  void _onTabTapped(int index) {
    if (index < 0 || index >= _screenBuilders.length) return;

    // Reset screen search if we are leaving them
    if (_currentIndex == 1 && index != 1) {
      _walletKey.currentState?.resetSearch();
    }
    if (_currentIndex == 3 && index != 3) {
      _colabKey.currentState?.resetSearch();
    }

    setState(() {
      _activatedIndices.add(index);
      _currentIndex = index;
    });
  }

  void _showAddTransaction() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddTransactionScreen(),
    );
  }

  static const List<_NavItemData> _navItems = [
    _NavItemData(
      label: 'Home',
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_rounded,
    ),
    _NavItemData(
      label: 'Wallet',
      activeIcon: Icons.wallet_rounded,
      inactiveIcon: Icons.wallet_outlined,
    ),
    _NavItemData(
      label: 'Report',
      activeIcon: Icons.bar_chart_rounded,
      inactiveIcon: Icons.bar_chart_rounded,
    ),
    _NavItemData(
      label: 'Collab',
      activeIcon: CupertinoIcons.person_2_fill,
      inactiveIcon: CupertinoIcons.person_2_fill,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Stack(
      children: [
        Scaffold(
          resizeToAvoidBottomInset: false,
          extendBody: true, // Content flows behind the floating navbar
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: List.generate(
                  _screenBuilders.length,
                  (index) => _activatedIndices.contains(index)
                      ? _screenBuilders[index](context)
                      : const SizedBox.shrink(),
                ),
              ),

              // Bottom Gradient Fade (Modern Polish)
              if (!isKeyboardOpen)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 150,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context)
                                .scaffoldBackgroundColor
                                .withOpacity(0.0),
                            Theme.of(context)
                                .scaffoldBackgroundColor
                                .withOpacity(0.8),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: isKeyboardOpen
              ? const SizedBox.shrink()
              : SafeArea(
                  bottom: true,
                  child: RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 58,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xF218181B), // 0.95 opacity solid
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: const Color(0x1FFFFFFF), // 0.12 opacity white
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x59000000), // 0.35 opacity black
                          blurRadius: 10,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _navItems.length,
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildNavItem(index),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Overlays everything including BottomNavigationBar
        const NotificationPermissionFloatingCard(),
      ],
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isActive = _currentIndex == index;
    final iconColor = isActive ? const Color(0xFF09090B) : const Color(0xFFA1A1AA);

    Widget iconWidget;
    if (index == 0) {
      iconWidget = CustomHomeIcon(
        size: 22,
        color: iconColor,
      );
    } else {
      iconWidget = Icon(
        isActive ? item.activeIcon : item.inactiveIcon,
        size: 22,
        color: iconColor,
      );
    }

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        width: isActive ? 106 : 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              iconWidget,
              if (isActive) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF09090B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddTransaction,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF7C75D9), // Soft desaturated periwinkle pastel
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x597C75D9), // 0.35 opacity
              blurRadius: 10,
              spreadRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.add,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Future<void> _startOCRScan() async {
    // Navigate to our custom scanner lens
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );

    if (result == null) return;

    XFile? imageFile;
    bool useAi = true;

    if (result is Map) {
      imageFile = result['image'] as XFile?;
      useAi = result['useAi'] ?? true;
    } else if (result is XFile) {
      imageFile = result;
    }

    if (imageFile == null) return;

    // Show a loading dialog/overlay while processing
    if (!mounted) return;

    // Load AI Config
    final prefs = await SharedPreferences.getInstance();
    final String? customApiKey = prefs.getString('user_ai_api_key');
    final String? apiPlatform = prefs.getString('user_ai_api_platform');

    // We can reuse the AddTransactionScreen logic or call OCR here
    // Let's show a loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Material(
          // Ensure styles from the theme carry through
          color: Colors.transparent,
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.4
                          : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  ToneManager.t('scan_loading_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ToneManager.t('scan_loading_msg'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final ocrService = ReceiptOCRService();
      final data = await ocrService.scanReceiptFromFile(
        imageFile,
        useAi: useAi,
        customApiKey: customApiKey,
        apiPlatform: apiPlatform,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loader

      if (data == null || data.amount == null) {
        UIHelper.showInfoDialog(
          context,
          'Struk Tidak Terdeteksi',
          'Waduh, sistem gagal mendeteksi struk atau nominal harga pada foto ini. Pastikan foto struk terlihat jelas dan terang ya!',
        );
        return;
      }

      // Open AddTransactionScreen with prefilled data
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddTransactionScreen(
          initialAmount: data.amount,
          initialNote: data.merchant,
          initialCategory: data.category,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loader
      UIHelper.showErrorSnackBar(context, 'Error: $e');
    }
  }
}

class _NavItemData {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavItemData({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}

class CustomHomeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CustomHomeIcon({
    super.key,
    this.size = 22,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HomeIconPainter(color: color),
      ),
    );
  }
}

class _HomeIconPainter extends CustomPainter {
  final Color color;

  _HomeIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    final path = Path();
    // Rounded top roof peak
    path.moveTo(w * 0.40, h * 0.13);
    path.quadraticBezierTo(w * 0.50, h * 0.04, w * 0.60, h * 0.13);

    // Right roof slope & rounded eave
    path.lineTo(w * 0.90, h * 0.38);
    path.quadraticBezierTo(w * 0.96, h * 0.43, w * 0.96, h * 0.50);

    // Right wall & rounded bottom right corner
    path.lineTo(w * 0.96, h * 0.88);
    path.quadraticBezierTo(w * 0.96, h * 0.95, w * 0.88, h * 0.95);

    // Bottom right to door
    path.lineTo(w * 0.63, h * 0.95);

    // Shorter door cutout
    path.lineTo(w * 0.63, h * 0.65);
    path.arcToPoint(
      Offset(w * 0.37, h * 0.65),
      radius: Radius.circular(w * 0.13),
      clockwise: false,
    );
    path.lineTo(w * 0.37, h * 0.95);

    // Bottom left corner & wall
    path.lineTo(w * 0.12, h * 0.95);
    path.quadraticBezierTo(w * 0.04, h * 0.95, w * 0.04, h * 0.88);

    // Left wall & rounded left eave
    path.lineTo(w * 0.04, h * 0.50);
    path.quadraticBezierTo(w * 0.04, h * 0.43, w * 0.10, h * 0.38);

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HomeIconPainter oldDelegate) =>
      oldDelegate.color != color;
}


