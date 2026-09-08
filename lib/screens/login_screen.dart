import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
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
      UIHelper.showErrorSnackBar(context, 'Konfirmasi password tidak sesuai.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await _authService.signInWithEmail(email, password);
        if (mounted) {
          // ignore: use_build_context_synchronously
          UIHelper.showSuccessSnackBar(context, 'Berhasil Masuk!');
        }
      } else {
        await _authService.signUpWithEmail(email, password, name);
        if (mounted) {
          // ignore: use_build_context_synchronously
          UIHelper.showSuccessSnackBar(context, 'Akun berhasil dibuat!');
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
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showErrorSnackBar(context, 'Gagal terhubung ke Google');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA);
    final accentPastel = const Color(0xFF6366F1); // Brand Periwinkle Blue color

    return Scaffold(
      backgroundColor: primaryBg,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(isDark, accentPastel),
                          const SizedBox(height: 32),
                          _buildFormCard(isDark, accentPastel),
                          const SizedBox(height: 24),
                          _buildDividerRow(isDark),
                          const SizedBox(height: 20),
                          _buildGoogleButton(isDark),
                          const SizedBox(height: 28),
                          _buildSwitchRow(isDark, accentPastel),
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
          // Clean Loading Overlay
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.6)
                      : Colors.white.withOpacity(0.6),
                  child: const Center(child: LoadingWidget()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color accentPastel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        // Minimalist App Logo Badge
        Container(
          width: 68,
          height: 68,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF27272A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo_app.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              CupertinoIcons.creditcard_fill,
              size: 32,
              color: accentPastel,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            _isLogin ? 'Selamat Datang Kembali' : 'Buat Akun Baru',
            key: ValueKey(_isLogin ? 'login_title' : 'register_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF18181B),
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _isLogin
                ? 'Masuk ke akun MyDuitGweh untuk lanjut'
                : 'Daftar sekarang dan mulai kelola keuanganmu',
            key: ValueKey(_isLogin ? 'login_sub' : 'register_sub'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(bool isDark, Color accentPastel) {
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field (register only)
            if (!_isLogin) ...[
              _buildInputLabel('Nama Lengkap', isDark),
              const SizedBox(height: 6),
              _buildInput(
                controller: _nameController,
                hint: 'Masukkan nama lengkap',
                icon: CupertinoIcons.person,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
            ],
            // Email field
            _buildInputLabel('Email', isDark),
            const SizedBox(height: 6),
            _buildInput(
              controller: _emailController,
              hint: 'nama@email.com',
              icon: CupertinoIcons.mail,
              keyboardType: TextInputType.emailAddress,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            // Password field
            _buildInputLabel('Password', isDark),
            const SizedBox(height: 6),
            _buildInput(
              controller: _passwordController,
              hint: '••••••••',
              icon: CupertinoIcons.lock,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleVisibility: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              isDark: isDark,
            ),
            // Confirm password field (register only)
            if (!_isLogin) ...[
              const SizedBox(height: 16),
              _buildInputLabel('Konfirmasi Password', isDark),
              const SizedBox(height: 6),
              _buildInput(
                controller: _confirmPasswordController,
                hint: '••••••••',
                icon: CupertinoIcons.lock_shield,
                isPassword: true,
                obscureText: _obscureConfirmPassword,
                onToggleVisibility: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                isDark: isDark,
              ),
            ],
            // Forgot password link
            if (_isLogin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _showForgotPass,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Lupa Password?',
                      style: TextStyle(
                        color: accentPastel,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Submit primary button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPastel,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isLogin ? 'Masuk' : 'Daftar Akun',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF3F3F46),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    final inputBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText ?? false,
        keyboardType: keyboardType,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF18181B),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            size: 18,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText!
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.eye,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    size: 18,
                  ),
                  onPressed: onToggleVisibility,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDividerRow(bool isDark) {
    final lineDividerColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);

    return Row(
      children: [
        Expanded(child: Divider(color: lineDividerColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'atau masuk dengan',
            style: TextStyle(
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: lineDividerColor, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    final btnBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: btnBg,
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.google.com/favicon.ico',
              height: 18,
              errorBuilder: (context, error, stackTrace) => Icon(
                CupertinoIcons.globe,
                size: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Lanjutkan dengan Google',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF18181B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(bool isDark, Color accentPastel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'Belum punya akun?' : 'Sudah punya akun?',
          style: TextStyle(
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isLogin = !_isLogin);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              _isLogin ? 'Daftar' : 'Masuk',
              style: TextStyle(
                color: accentPastel,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPass() {
    final emailController =
        TextEditingController(text: _emailController.text.trim());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentPastel = const Color(0xFF6366F1); // Brand Periwinkle Blue

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
        final safeBottom = MediaQuery.of(context).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            viewInsetsBottom + (viewInsetsBottom > 0 ? 16 : (safeBottom > 0 ? safeBottom + 16 : 24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag indicator handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header Row with Icon Badge
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentPastel.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.lock_shield_fill,
                      color: accentPastel,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF18181B),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Kirim tautan pemulihan ke email kamu',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Email Akun',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF3F3F46),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF18181B),
                  ),
                  decoration: InputDecoration(
                    hintText: 'nama@email.com',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      CupertinoIcons.mail,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentPastel,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final targetEmail = emailController.text.trim();
                    if (targetEmail.isEmpty) {
                      UIHelper.showErrorSnackBar(context, 'Masukkan alamat email Anda.');
                      return;
                    }
                    final nav = Navigator.of(context);
                    nav.pop();

                    if (!mounted) return;
                    setState(() => _isLoading = true);
                    try {
                      await _authService.sendPasswordResetEmail(targetEmail);
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      UIHelper.showSuccessSnackBar(
                          context, 'Tautan reset password dikirim ke $targetEmail');
                    } catch (e) {
                      if (!mounted) return;
                      // ignore: use_build_context_synchronously
                      UIHelper.showErrorSnackBar(context, e.toString());
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text(
                    'Kirim Link Reset Password',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
