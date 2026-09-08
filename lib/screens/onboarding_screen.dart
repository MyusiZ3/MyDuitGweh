import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<OnboardingData> _getPages() {
    return [
      OnboardingData(
        title: 'Kelola Keuangan\nDengan Mudah',
        subtitle:
            'Catat setiap transaksi harian secara rapi, hemat, dan terkontrol dalam satu tempat.',
        type: OnboardingType.balance,
      ),
      OnboardingData(
        title: 'Dompet Kolaborasi\nSirkel & Pasangan',
        subtitle:
            'Pantau anggaran bersama teman atau pasangan secara transparan dan teratur.',
        type: OnboardingType.shared,
      ),
      OnboardingData(
        title: 'Laporan Instant\nSekali Ketuk',
        subtitle:
            'Unduh ringkasan analisis keuangan bulanan dalam format PDF rapi kapan saja.',
        type: OnboardingType.report,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToLogin() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF121214) : const Color(0xFFFAFAFA);
    final accentColor = const Color(0xFFF59E0B); // Warm amber yellow accent matching reference

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = index);
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(pages[index], isDark, accentColor);
                },
              ),
            ),
            _buildFooter(pages, isDark, accentColor),
          ],
        ),
      ),
    );
  }

  // --- HEADER: Top Circular App Badge (Left) & Capsule Skip Button (Right) ---
  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular App Icon Logo
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFF18181B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo_app.png',
                width: 22,
                height: 22,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  CupertinoIcons.text_quote,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          // Capsule "Lewati" Button
          GestureDetector(
            onTap: _navigateToLogin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.12),
                  width: 1.2,
                ),
              ),
              child: Text(
                'Skip',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF3F3F46),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PAGE BODY: Hero Graphic & Left-Aligned Text ---
  Widget _buildPage(OnboardingData data, bool isDark, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          // Center Graphic Illustration
          Center(
            child: SizedBox(
              height: 260,
              child: _buildHeroWidget(data.type, isDark, accentColor),
            ),
          ),
          const Spacer(flex: 1),
          // Left-Aligned Headline & Subtitle
          Text(
            data.title,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF18181B),
              height: 1.2,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeroWidget(OnboardingType type, bool isDark, Color accentColor) {
    switch (type) {
      case OnboardingType.balance:
        return _buildMinimalBalanceHero(isDark, accentColor);
      case OnboardingType.shared:
        return _buildMinimalSharedHero(isDark, accentColor);
      case OnboardingType.report:
        return _buildMinimalReportHero(isDark, accentColor);
    }
  }

  // --- HERO 1: Minimalist Balance Card with Floating Circles ---
  Widget _buildMinimalBalanceHero(bool isDark, Color accentColor) {
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Floating Yellow Accent Circle (Background element like reference)
        Positioned(
          top: 15,
          left: 15,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        // Floating Grey Secondary Circle
        Positioned(
          top: 5,
          right: 25,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Main Card
        Container(
          width: 270,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Saldo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.arrow_up_right, size: 10, color: accentColor),
                        const SizedBox(width: 2),
                        Text(
                          '+12%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Rp 24.500.000',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: isDark ? Colors.white : const Color(0xFF18181B),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 12),
              _buildTransactionRow(
                isDark,
                icon: CupertinoIcons.arrow_down_left,
                iconColor: const Color(0xFF10B981),
                title: 'Gaji Bulanan',
                amount: '+Rp 8.500.000',
              ),
              const SizedBox(height: 8),
              _buildTransactionRow(
                isDark,
                icon: CupertinoIcons.arrow_up_right,
                iconColor: const Color(0xFFEF4444),
                title: 'Belanja Harian',
                amount: '-Rp 125.000',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String amount,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF3F3F46),
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF18181B),
          ),
        ),
      ],
    );
  }

  // --- HERO 2: Minimalist Shared Wallet ---
  Widget _buildMinimalSharedHero(bool isDark, Color accentColor) {
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 10,
          right: 20,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: 270,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.person_3_fill,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF18181B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dompet Liburan ✈️',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF18181B),
                          ),
                        ),
                        Text(
                          '3 Anggota',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Rp 8.500.000',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: isDark ? Colors.white : const Color(0xFF18181B),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    height: 24,
                    child: Stack(
                      children: [
                        _buildAvatarPill('A', const Color(0xFF3B82F6), 0),
                        _buildAvatarPill('B', const Color(0xFF8B5CF6), 16),
                        _buildAvatarPill('C', accentColor, 32),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF3F3F46),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPill(String initial, Color color, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // --- HERO 3: Minimalist PDF Report ---
  Widget _buildMinimalReportHero(bool isDark, Color accentColor) {
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 15,
          left: 20,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: 250,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.doc_text_fill,
                      size: 16,
                      color: isDark ? Colors.white : const Color(0xFF18181B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan_Mei.pdf',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF18181B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Siap diunduh',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sisa Anggaran',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '78% Aman',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF18181B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.checkmark,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- FOOTER: Dots Indicator (Left) & Circular Arrow Navigation (Right) ---
  Widget _buildFooter(List<OnboardingData> pages, bool isDark, Color accentColor) {
    final isLastPage = _currentPage == pages.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots Indicator (Left)
          Row(
            children: List.generate(
              pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.only(right: 6),
                height: 7,
                width: _currentPage == index ? 7 : 7,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? accentColor
                      : (isDark
                          ? const Color(0xFF3F3F46)
                          : const Color(0xFFE4E4E7)),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          // Arrow Controls (Right)
          Row(
            children: [
              // Back Button (shown if page > 0)
              if (_currentPage > 0) ...[
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFF4F4F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.arrow_left,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF18181B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Next / Finish Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (_currentPage < pages.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  } else {
                    _navigateToLogin();
                  }
                },
                child: Container(
                  width: isLastPage ? 110 : 54,
                  height: 54,
                  padding: isLastPage
                      ? const EdgeInsets.symmetric(horizontal: 16)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isLastPage
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Mulai',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.arrow_right,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        )
                      : const Center(
                          child: Icon(
                            CupertinoIcons.arrow_right,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum OnboardingType { balance, shared, report }

class OnboardingData {
  final String title;
  final String subtitle;
  final OnboardingType type;

  OnboardingData({
    required this.title,
    required this.subtitle,
    required this.type,
  });
}
