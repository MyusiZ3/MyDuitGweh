import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import '../widgets/loading_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isLogin = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        (!_isLogin && (name.isEmpty || confirmPassword.isEmpty))) {
      UIHelper.showErrorSnackBar(context, ToneManager.t('snack_login_err'));
      return;
    }

    if (password.length < 6) {
      UIHelper.showErrorSnackBar(context, 'Password minimal 6 karakter!');
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      UIHelper.showErrorSnackBar(context, 'Password gak cocok bro! 🧐');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.signInWithEmail(email, password);
        if (mounted) {
          UIHelper.showSuccessSnackBar(context, 'Berhasil Masuk!');
          // AuthGate mendengar authStateChanges dan otomatis navigasi ke Home
        }
      } else {
        await _authService.signUpWithEmail(email, password, name);
        if (mounted) {
          UIHelper.showSuccessSnackBar(context, 'Akun berhasil dibuat!');
          // AuthGate mendengar authStateChanges dan otomatis navigasi ke Home
        }
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        UIHelper.showSuccessSnackBar(context, 'Login Google Berhasil!');
        // AuthGate mendengar authStateChanges dan otomatis navigasi ke Home
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showErrorSnackBar(context, 'Gagal terhubung ke Google ⚠️');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS system grouped bg
      body: Stack(
        children: [
          // Gradient background blobs
          _buildVisualDecoration(),
          // Main content
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildFormCard(),
                          const SizedBox(height: 20),
                          _buildDividerRow(),
                          const SizedBox(height: 20),
                          _buildGoogleButton(),
                          const SizedBox(height: 24),
                          _buildSwitchRow(),
                          SizedBox(
                              height:
                                  MediaQuery.of(context).padding.bottom + 8),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.white.withOpacity(0.6),
                  child: const Center(child: LoadingWidget()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualDecoration() {
    return Stack(
      children: [
        // Top-right gradient blob
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF007AFF).withOpacity(0.12),
                  const Color(0xFF007AFF).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Bottom-left gradient blob
        Positioned(
          bottom: -120,
          left: -80,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF5856D6).withOpacity(0.08),
                  const Color(0xFF5856D6).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF007AFF).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo_app.png',
                width: 36,
                height: 36,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            _isLogin ? 'Selamat Datang' : 'Buat Akun Baru',
            key: ValueKey(_isLogin ? 'login_title' : 'register_title'),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1E),
              letterSpacing: -1.2,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _isLogin
                ? 'Masuk ke akun MyDuitGweh kamu'
                : 'Daftar dan mulai kelola keuanganmu',
            key: ValueKey(_isLogin ? 'login_sub' : 'register_sub'),
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
        child: Column(
          children: [
            // Name field (register only)
            if (!_isLogin) ...[
              _buildInput(
                controller: _nameController,
                hint: 'Nama',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
            ],
            // Email
            _buildInput(
              controller: _emailController,
              hint: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            // Password
            _buildInput(
              controller: _passwordController,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleVisibility: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            // Confirm password (register only)
            if (!_isLogin) ...[
              const SizedBox(height: 12),
              _buildInput(
                controller: _confirmPasswordController,
                hint: 'Ulangi Password',
                icon: Icons.lock_reset_rounded,
                isPassword: true,
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ],
            // Forgot password link
            if (_isLogin) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _showForgotPass,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Lupa Password?',
                      style: TextStyle(
                          color: Color(0xFF007AFF),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _isLogin ? 'Masuk' : 'Daftar',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText ?? false,
        keyboardType: keyboardType,
        style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Color(0xFF1C1C1E)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              color: Color(0xFFC7C7CC),
              fontSize: 16,
              fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, color: const Color(0xFF8E8E93), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText!
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: const Color(0xFFC7C7CC),
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildDividerRow() {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE5E5EA), thickness: 0.5)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('atau',
              style: TextStyle(
                  color: Color(0xFFC7C7CC),
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(child: Divider(color: Color(0xFFE5E5EA), thickness: 0.5)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE5E5EA), width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network('https://www.google.com/favicon.ico', height: 18),
            const SizedBox(width: 10),
            const Text('Masuk dengan Google',
                style: TextStyle(
                    color: Color(0xFF1C1C1E),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'Belum punya akun?' : 'Sudah punya akun?',
          style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
        TextButton(
          onPressed: () => setState(() => _isLogin = !_isLogin),
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(
            _isLogin ? 'Daftar' : 'Masuk',
            style: const TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  void _showForgotPass() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      UIHelper.showErrorSnackBar(context, 'Tulis email dulu ya!');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        UIHelper.showSuccessSnackBar(
            context, 'Cek e-mail kamu untuk reset password!');
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, e.toString());
    }
  }
}
