import 'dart:ui';
import 'package:flutter/material.dart';
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
import '../widgets/notification_permission_floating_card.dart';


class MainNav extends StatefulWidget {
  const MainNav({super.key});

  static _MainNavState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainNavState>();

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isExpanded = false;
  late AnimationController _fabController;
  late Animation<double> _expandAnimation;

  // Keys to communicate with Screens
  final GlobalKey<WalletScreenState> _walletKey =
      GlobalKey<WalletScreenState>();
  final GlobalKey<ColabScreenState> _colabKey = GlobalKey<ColabScreenState>();

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _expandAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut, // Bouncier, premium feel
      reverseCurve: Curves.easeInBack,
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _toggleFAB() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void setTab(int index) {
    if (index == 2) {
      _toggleFAB();
      return;
    }
    setState(() {
      _currentIndex = index;
      _isExpanded = false;
      _fabController.reverse();
    });
  }

  late final List<Widget> _screens = [
    const HomeScreen(),
    WalletScreen(key: _walletKey),
    const SizedBox(), // placeholder for Add button
    ColabScreen(key: _colabKey),
    const ReportScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == 2) {
      _toggleFAB();
      return;
    }

    // Reset screen search if we are leaving them
    if (_currentIndex == 1 && index != 1) {
      _walletKey.currentState?.resetSearch();
    }
    if (_currentIndex == 3 && index != 3) {
      _colabKey.currentState?.resetSearch();
    }

    setState(() {
      _currentIndex = index;
      _isExpanded = false;
      _fabController.reverse();
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),

              // Action Buttons (Speed Dial Overlay)
              if (_isExpanded) ...[
                _buildSpeedDialBackdrop(),
                _buildSpeedDialMenu(),
              ],
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(Icons.home_rounded, 'Home', 0),
                    _buildNavItem(
                        Icons.account_balance_wallet_outlined, 'Wallet', 1),
                    _buildAddButton(),
                    _buildNavItem(Icons.group_outlined, 'Colab', 3),
                    _buildNavItem(Icons.bar_chart_rounded, 'Report', 4),
                  ],
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDialBackdrop() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleFAB,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedDialMenu() {
    return Positioned(
      bottom: 20, // Lower as requested
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildSpeedDialItem(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan Struk (OCR)',
            color: AppColors.primary,
            onTap: () {
              _toggleFAB();
              _startOCRScan();
            },
            index: 1,
          ),
          const SizedBox(height: 16),
          _buildSpeedDialItem(
            icon: Icons.edit_note_rounded,
            label: 'Input Manual',
            color: AppColors.income,
            onTap: () {
              _toggleFAB();
              _showAddTransaction();
            },
            index: 0,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    final step = 1.0 / 2;
    final start = index * step * 0.2; // Slight delay for staggered effect

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fabController,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    ));

    final opacityAnim = CurvedAnimation(
      parent: _fabController,
      curve: Interval(start, 0.8, curve: Curves.easeIn),
    );

    return FadeTransition(
      opacity: opacityAnim,
      child: SlideTransition(
        position: slideAnim,
        child: ScaleTransition(
          scale: opacityAnim,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _toggleFAB,
      child: AnimatedBuilder(
        animation: _fabController,
        builder: (context, child) {
          return Container(
            width: 58,
            height: 58,
            transform: Matrix4.translationValues(
                0, -8, 0), // Lift slightly above nav bar edge
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.85),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20), // iOS squircle shape
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Transform.scale(
              scale: 1.0 + (_fabController.value * 0.1), // Slight pulse
              child: Transform.rotate(
                angle: _expandAnimation.value *
                    (3.14159 / 4), // Rotate to forms an 'X'
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startOCRScan() async {
    // Navigate to our custom scanner lens
    final XFile? imageFile = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptScannerScreen()),
    );

    if (imageFile == null) return;

    // Show a loading dialog/overlay while processing
    if (!mounted) return;

    // We can reuse the AddTransactionScreen logic or call OCR here
    // Let's show a loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final ocrService = ReceiptOCRService();
      final data = await ocrService.scanReceiptFromFile(imageFile);

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
