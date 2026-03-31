import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
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
  final _nameController = TextEditingController();

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      UIHelper.showErrorSnackBar(context, 'Harap isi semua kolom! ⚠️');
      return;
    }

    if (password.length < 6) {
      UIHelper.showErrorSnackBar(context, 'Password minimal 6 karakter! 🛡️');
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
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 48),
                        _buildGlassCard(),
                        const SizedBox(height: 32),
                        _buildFooter(),
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
          if (_isLoading) const Center(child: LoadingWidget()),
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
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: const Center(
            child: Icon(Icons.account_balance_wallet_rounded, size: 42, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          _isLogin ? 'Selamat Datang' : 'Buat Akun',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -1),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin ? 'Senang melihat kamu kembali!' : 'Mulai perjalanan finansialmu sekarang!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            children: [
              if (!_isLogin) 
                _buildInput(_nameController, 'Nama Lengkap', Icons.person_outline_rounded, false),
              if (!_isLogin) const SizedBox(height: 16),
              
              _buildInput(_emailController, 'Alamat Email', Icons.email_outlined, false),
              const SizedBox(height: 16),
              
              _buildInput(_passwordController, 'Kata Sandi', Icons.lock_outline_rounded, true),
              
              if (_isLogin) 
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPass,
                    child: const Text('Lupa Sandi?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    _isLogin ? 'Masuk Sekarang' : 'Daftar Yuk!',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon, bool hide) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: hide,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
            Text(_isLogin ? 'Belum member?' : 'Sudah member?', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin ? 'Daftar' : 'Masuk',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('atau', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
            Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: Image.network('https://www.google.com/favicon.ico', height: 18),
            label: const Text('Lanjut dengan Google', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8), // Perfect Safe Area
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
