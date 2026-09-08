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
    // Brand identity pastel sky blue accent
    final accentColor = const Color(0xFF38BDF8); 

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
                  return _buildPage(pages[index], isDark);
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
  Widget _buildPage(OnboardingData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          // Center Graphic Vector Illustration
          Center(
            child: SizedBox(
              height: 270,
              width: 280,
              child: _buildHeroWidget(data.type, isDark),
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

  Widget _buildHeroWidget(OnboardingType type, bool isDark) {
    switch (type) {
      case OnboardingType.balance:
        return _buildArtisticLedgerIllustration(isDark, const Color(0xFF38BDF8)); // Pastel Sky Blue
      case OnboardingType.shared:
        return _buildArtisticDoorwayIllustration(isDark, const Color(0xFFA78BFA)); // Pastel Lavender
      case OnboardingType.report:
        return _buildArtisticReportIllustration(isDark, const Color(0xFF34D399)); // Pastel Mint
    }
  }

  // --- ARTISTIC VECTOR 1: Isometric Ledger & Magnifying Glass ---
  Widget _buildArtisticLedgerIllustration(bool isDark, Color slideAccent) {
    final outlineColor = isDark ? Colors.white : const Color(0xFF18181B);
    final bookBg = isDark ? const Color(0xFF27272A) : const Color(0xFFFFFFFF);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Background Floating Accent Circle
        Positioned(
          top: 35,
          left: 20,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: slideAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slideAccent.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
        // Secondary Floating Grey Sphere
        Positioned(
          top: 25,
          right: 35,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Main Isometric Open Book
        Positioned(
          top: 60,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateZ(-0.18)
              ..rotateX(0.2),
            child: Container(
              width: 170,
              height: 140,
              decoration: BoxDecoration(
                color: bookBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Book spine line
                  Center(
                    child: Container(
                      width: 2,
                      height: double.infinity,
                      color: outlineColor.withOpacity(0.3),
                    ),
                  ),
                  // Page lines left
                  Positioned(
                    top: 24,
                    left: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 45, height: 4, decoration: BoxDecoration(color: outlineColor, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 8),
                        Container(width: 35, height: 4, decoration: BoxDecoration(color: outlineColor.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 8),
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: outlineColor.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                  // Page lines right
                  Positioned(
                    top: 24,
                    right: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(width: 40, height: 4, decoration: BoxDecoration(color: outlineColor.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 8),
                        Container(width: 48, height: 4, decoration: BoxDecoration(color: outlineColor, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 8),
                        Container(width: 30, height: 4, decoration: BoxDecoration(color: outlineColor.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Leaning Wooden/White Ladder Vector Graphic
        Positioned(
          left: 45,
          bottom: 25,
          child: Transform.rotate(
            angle: -0.15,
            child: SizedBox(
              width: 36,
              height: 110,
              child: CustomPaint(
                painter: _LadderPainter(color: isDark ? Colors.white70 : const Color(0xFF27272A)),
              ),
            ),
          ),
        ),
        // Floating Magnifying Glass
        Positioned(
          right: 45,
          bottom: 40,
          child: Transform.rotate(
            angle: 0.35,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: outlineColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  CupertinoIcons.search,
                  size: 24,
                  color: outlineColor,
                ),
              ),
            ),
          ),
        ),
        // Small Floating Sphere
        Positioned(
          bottom: 15,
          left: 110,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF52525B) : const Color(0xFF3F3F46),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  // --- ARTISTIC VECTOR 2: Doorway Portal & Winding Path ---
  Widget _buildArtisticDoorwayIllustration(bool isDark, Color slideAccent) {
    final outlineColor = isDark ? Colors.white : const Color(0xFF18181B);
    final doorBg = isDark ? const Color(0xFF27272A) : const Color(0xFF18181B);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Floating Pastel Circle
        Positioned(
          top: 25,
          right: 25,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: slideAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slideAccent.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
        // Winding Pathway Painter
        Positioned(
          bottom: 10,
          child: SizedBox(
            width: 220,
            height: 130,
            child: CustomPaint(
              painter: _WindingPathPainter(
                pathColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
                dashColor: outlineColor,
              ),
            ),
          ),
        ),
        // Main Portal Door (Book Portal Silhouette)
        Positioned(
          top: 35,
          child: Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: doorBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: outlineColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 44,
                height: 70,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121214) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border.all(color: outlineColor, width: 2),
                ),
              ),
            ),
          ),
        ),
        // Leaf Plant Silhouettes framing the door
        Positioned(
          left: 55,
          bottom: 75,
          child: Icon(
            CupertinoIcons.leaf_arrow_circlepath,
            size: 32,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B),
          ),
        ),
        Positioned(
          right: 55,
          bottom: 75,
          child: Icon(
            CupertinoIcons.sparkles,
            size: 28,
            color: slideAccent,
          ),
        ),
      ],
    );
  }

  // --- ARTISTIC VECTOR 3: Open Notebook & Floating PDF/File Tags ---
  Widget _buildArtisticReportIllustration(bool isDark, Color slideAccent) {
    final outlineColor = isDark ? Colors.white : const Color(0xFF18181B);
    final binderBg = isDark ? const Color(0xFF27272A) : const Color(0xFFFFFFFF);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Floating Pastel Mint Circle
        Positioned(
          top: 40,
          left: 20,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: slideAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slideAccent.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
        // Main Open Binder/Notebook
        Positioned(
          top: 50,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateZ(0.12)
              ..rotateX(-0.15),
            child: Container(
              width: 170,
              height: 150,
              decoration: BoxDecoration(
                color: binderBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: outlineColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Pastel Ribbon Bookmark
                  Positioned(
                    top: 0,
                    right: 35,
                    child: Container(
                      width: 16,
                      height: 45,
                      decoration: BoxDecoration(
                        color: slideAccent,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                      ),
                    ),
                  ),
                  // Binder Center Ring Line
                  Center(
                    child: Container(
                      width: 2,
                      height: double.infinity,
                      color: outlineColor.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating Document Badges (PDF, CSV, XLS)
        Positioned(
          top: 85,
          left: 50,
          child: Transform.rotate(
            angle: -0.15,
            child: _buildFileBadge('PDF', isDark, outlineColor),
          ),
        ),
        Positioned(
          bottom: 45,
          left: 70,
          child: Transform.rotate(
            angle: 0.1,
            child: _buildFileBadge('XLS', isDark, outlineColor),
          ),
        ),
        Positioned(
          bottom: 35,
          right: 50,
          child: Transform.rotate(
            angle: -0.2,
            child: _buildFileBadge('CSV', isDark, outlineColor),
          ),
        ),
        // Floating Spheres
        Positioned(
          bottom: 20,
          right: 25,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildFileBadge(String label, bool isDark, Color outlineColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: outlineColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : const Color(0xFF18181B),
          letterSpacing: 0.5,
        ),
      ),
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

// --- CUSTOM VECTOR PAINTERS ---

class _LadderPainter extends CustomPainter {
  final Color color;
  _LadderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Side poles
    canvas.drawLine(const Offset(4, 0), Offset(4, size.height), paint);
    canvas.drawLine(Offset(size.width - 4, 0), Offset(size.width - 4, size.height), paint);

    // Rungs
    final stepCount = 4;
    final stepGap = size.height / (stepCount + 1);
    for (int i = 1; i <= stepCount; i++) {
      final y = stepGap * i;
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WindingPathPainter extends CustomPainter {
  final Color pathColor;
  final Color dashColor;
  _WindingPathPainter({required this.pathColor, required this.dashColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height);
    path.cubicTo(
      size.width * 0.3, size.height * 0.6,
      size.width * 0.7, size.height * 0.4,
      size.width * 0.5, 0,
    );
    path.lineTo(size.width * 0.58, 0);
    path.cubicTo(
      size.width * 0.8, size.height * 0.4,
      size.width * 0.4, size.height * 0.7,
      size.width * 0.8, size.height,
    );
    path.close();

    canvas.drawPath(path, fillPaint);

    // Dashed center line
    final dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final dashPath = Path();
    dashPath.moveTo(size.width * 0.5, size.height);
    dashPath.cubicTo(
      size.width * 0.52, size.height * 0.6,
      size.width * 0.72, size.height * 0.3,
      size.width * 0.54, 0,
    );

    canvas.drawPath(dashPath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
