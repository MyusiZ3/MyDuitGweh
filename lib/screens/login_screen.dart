import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import '../widgets/loading_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _isLogin = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && (name.isEmpty || confirmPassword.isEmpty))) {
      UIHelper.showErrorSnackBar(context, ToneManager.t('snack_login_err'));
      return;
    }

    if (password.length < 6) {
      UIHelper.showErrorSnackBar(context, 'Password minimal 6 karakter! 🛡️');
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
        if (mounted) UIHelper.showSuccessSnackBar(context, 'Berhasil Masuk! 🚀');
      } else {
        await _authService.signUpWithEmail(email, password, name);
        if (mounted) UIHelper.showSuccessSnackBar(context, 'Akun berhasil dibuat! 🎉✨');
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
        UIHelper.showSuccessSnackBar(context, 'Login Google Berhasil! 🌐🚀');
      }
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, 'Gagal terhubung ke Google ⚠️');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Ultra light slate
      body: Stack(
        children: [
          _buildVisualDecoration(),
          const Positioned.fill(child: SingleChildScrollView(child: _DummyContent())), // Just to handle keyboard
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildGlassCard(),
                        const SizedBox(height: 36),
                        _buildFooter(),
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
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
        Positioned(
          top: -100,
          right: -50,
          child: _buildBlob(300, AppColors.primary.withOpacity(0.08)),
        ),
        Positioned(
          bottom: -150,
          left: -100,
          child: _buildBlob(400, const Color(0xFF6366F1).withOpacity(0.06)),
        ),
      ],
    );
  }

  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Left-Aligned Modern Approach
      children: [
        Text(
          _isLogin ? 'Welcome Back!' : 'Gas Bikin Akun',
          style: const TextStyle(
            fontSize: 38, 
            fontWeight: FontWeight.w800, 
            color: Color(0xFF1C1C1E), 
            letterSpacing: -1.5,
            height: 1.1,
          ), 
        ),
        const SizedBox(height: 10),
        Text(
          _isLogin ? 'Udah siap nyatet duit lu hari ini? 💸' : 'Biar dompet lu ga boncos di akhir bulan. 📉',
          style: const TextStyle(
            color: Color(0xFF8E8E93), 
            fontSize: 16, 
            fontWeight: FontWeight.w500, 
            letterSpacing: -0.2
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), // Heavy iOS frost
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              )
            ],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            child: Column(
              children: [
                if (!_isLogin) 
                  _buildInput(_nameController, 'Nama Lengkap (Bebas cuy)', Icons.person_outline_rounded, false),
                if (!_isLogin) const SizedBox(height: 16),
                
                _buildInput(_emailController, 'Alamat Email Aktif', Icons.email_outlined, false),
                const SizedBox(height: 16),
                
                _buildInput(
                  _passwordController, 
                  'Kata Sandi Unik', 
                  Icons.lock_outline_rounded, 
                  true,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword)
                ),
                
                if (!_isLogin) ...[
                  const SizedBox(height: 16),
                  _buildInput(
                    _confirmPasswordController, 
                    'Ulangi Kata Sandi', 
                    Icons.lock_reset_rounded, 
                    true,
                    obscureText: _obscureConfirmPassword,
                    onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)
                  ),
                ],
                
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isLogin ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        onPressed: _showForgotPass,
                        child: const Text('Lupa Sandi?', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                  ),
                  secondChild: const SizedBox(height: 16, width: double.infinity),
                ),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF), // iOS default tint
                      foregroundColor: Colors.white,
                      elevation: 0, // Flat iOS style
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _isLogin ? 'Login Sekarang 🚀' : 'Gas Daftar! 🔥',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon, bool isPassword, {bool? obscureText, VoidCallback? onToggleVisibility}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7), // iOS native grouped background
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2), 
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText ?? false,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Color(0xFF1C1C1E)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 16, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: const Color(0xFF8E8E93), size: 22),
          suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(
                    obscureText! ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: const Color(0xFF8E8E93),
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isPassword ? 14 : 16),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isLogin ? 'Belum punya circlenya?' : 'Udah punya akun brok?', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 15, fontWeight: FontWeight.w500)),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin ? 'Daftar Sini' : 'Login Aja',
                style: const TextStyle(color: Color(0xFF007AFF), fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFE5E5EA))),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('atau', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14))),
            Expanded(child: Divider(color: Color(0xFFE5E5EA))),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: Image.network('https://www.google.com/favicon.ico', height: 18),
            label: const Text('Gaskeun Pake Google 😎', style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC7C7CC), width: 1.5), // iOS pale border
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8), 
      ],
    );
  }

  void _showForgotPass() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      UIHelper.showErrorSnackBar(context, 'Tulis email dulu ya! 📧');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) UIHelper.showSuccessSnackBar(context, 'Cek e-mail kamu untuk reset sandi! 📧✨');
    } catch (e) {
      if (mounted) UIHelper.showErrorSnackBar(context, e.toString());
    }
  }
}

class _DummyContent extends StatelessWidget {
  const _DummyContent();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 1);
}
