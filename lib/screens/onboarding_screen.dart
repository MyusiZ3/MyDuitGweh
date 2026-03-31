import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Solusi Cerdas\nAtur Keuanganmu',
      subtitle: 'Semua transaksi harian tercatat otomatis\ndan rapi dalam satu genggaman.',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: AppColors.primary,
    ),
    OnboardingData(
      title: 'Pantau Bersama\ndengan Kolaborasi',
      subtitle: 'Bikin dompet bareng teman atau pasangan,\nbiar makin transparan dan seru!',
      icon: Icons.groups_rounded,
      iconColor: Colors.orangeAccent,
    ),
    OnboardingData(
      title: 'Export Laporan\nSecepat Kilat',
      subtitle: 'Download laporan bulanan dalam format PDF\nyang rapi, siap untuk dicetak kapan saja.',
      icon: Icons.picture_as_pdf_rounded,
      iconColor: Colors.redAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFF), // Soft background like Gojek
      body: Column(
        children: [
          // Onboarding Content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _buildPage(_pages[index]);
              },
            ),
          ),
          
          // Bottom area - Actions
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minimalist Dots Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: _currentPage == index ? 24 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                            ? AppColors.primary 
                            : AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Gojek Style Login/Start Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _pages.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.fastOutSlowIn,
                          );
                        } else {
                          _navigateToLogin();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28), // Very rounded like Gopay
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Mulai Sekarang' : 'Lanjut',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  
                  // Skip / Login link
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _navigateToLogin,
                    child: RichText(
                      text: TextSpan(
                        text: 'Tiba-tiba sudah punya akun? ',
                        style: const TextStyle(color: AppColors.textHint, fontSize: 13),
                        children: [
                          const TextSpan(
                            text: 'Masuk',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim, secondAnim) => const LoginScreen(),
          transitionsBuilder: (context, anim, secondAnim, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    }
  }

  Widget _buildPage(OnboardingData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      child: Column(
        children: [
          // Illustration Box ala Gojek
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: data.iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(data.icon, size: 80, color: data.iconColor),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1.2,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  OnboardingData({
    required this.title, 
    required this.subtitle, 
    required this.icon,
    required this.iconColor,
  });
}
