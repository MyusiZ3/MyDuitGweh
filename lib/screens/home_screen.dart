import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../widgets/loading_widget.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/ui_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import 'main_nav.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final SecurityService _securityService = SecurityService();
  final NotificationService _notificationService = NotificationService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _isBiometricEnabled = false;
  bool _isNotificationEnabled = false;
  bool _isBalanceVisible = true;
  double _monthlyBudget = 0.0;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAppLock();
  }

  Future<void> _checkAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool('use_biometrics') ?? false;
    if (isLocked) {
      await _securityService.authenticate();
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBiometricEnabled = prefs.getBool('use_biometrics') ?? false;
      _isNotificationEnabled = prefs.getBool('use_notifications') ?? false;
      _isBalanceVisible = prefs.getBool('show_balance') ?? true;
      _monthlyBudget = prefs.getDouble('monthly_budget') ?? 0.0;

      final savedHour = prefs.getInt('reminder_hour') ?? 20;
      final savedMinute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: savedHour, minute: savedMinute);
    });
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<List<WalletModel>>(
        stream: _firestoreService.getWalletsStream(_uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: LoadingWidget());

          final wallets = snapshot.data!;
          final totalBalance =
              wallets.fold<double>(0, (sum, w) => sum + w.balance);
          final walletIds = wallets.map((w) => w.id).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. STICKY APP BAR & GREETING
              SliverAppBar(
                pinned: true,
                floating: true,
                elevation: 0,
                backgroundColor: AppColors.background,
                expandedHeight: 90,
                toolbarHeight: 80,
                centerTitle: false,
                automaticallyImplyLeading: false,
                titleSpacing: 24,
                title: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_getGreeting(),
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w500)),
                        Text(user?.displayName ?? 'Pengguna',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _showProfileMenu,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.15),
                              width: 1.5),
                        ),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? const Icon(Icons.person_rounded,
                                  size: 22, color: AppColors.primary)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. MAIN BALANCE CARD
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Saldo Seluruh Dompet',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            GestureDetector(
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                setState(() {
                                  _isBalanceVisible = !_isBalanceVisible;
                                  prefs.setBool(
                                      'show_balance', _isBalanceVisible);
                                });
                              },
                              child: Icon(
                                _isBalanceVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          child: Text(
                            _isBalanceVisible
                                ? CurrencyFormatter.formatCurrency(totalBalance)
                                : 'Rp ••••••••',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            _balanceAction(
                                Icons.account_balance_wallet_rounded, 'Dompet',
                                () {
                              MainNav.of(context)?.setTab(1);
                            }),
                            const SizedBox(width: 12),
                            _balanceAction(Icons.insights_rounded, 'Laporan',
                                () {
                              MainNav.of(context)?.setTab(4);
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. BUDGET TRACKER (IF SET)
              if (_monthlyBudget > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: _buildBudgetTracker(totalBalance),
                  ),
                ),

              // 4. WALLET SUMMARY (SMALL CARDS)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 12, left: 24),
                  child: Text('Daftar Dompet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ),
              SliverToBoxAdapter(
                child: wallets.isEmpty
                    ? Container(
                        height: 120,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppColors.surfaceVariant.withAlpha(50)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                color: AppColors.textHint.withOpacity(0.3),
                                size: 32),
                            const SizedBox(height: 8),
                            const Text('Belum ada dompet nih!',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            const Text('Buat dompet pertamamu yuk!',
                                style: TextStyle(
                                    color: AppColors.textHint, fontSize: 11)),
                          ],
                        ),
                      )
                    : SizedBox(
                        height: 100,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: wallets.length,
                          itemBuilder: (context, index) {
                            final w = wallets[index];
                            return GestureDetector(
                              onTap: () => MainNav.of(context)?.setTab(1),
                              child: Container(
                                width: 170,
                                margin: const EdgeInsets.only(right: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: AppColors.surfaceVariant
                                          .withOpacity(0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(w.walletName,
                                        style: const TextStyle(
                                            color: AppColors.textHint,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      child: Text(
                                          CurrencyFormatter.formatCurrency(
                                              w.balance),
                                          style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),

              // 5. RECENT TRANSACTIONS
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 32, bottom: 16, left: 24, right: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transaksi Terakhir',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w800, fontSize: 18)),
                      TextButton(
                        onPressed: () => MainNav.of(context)?.setTab(4),
                        child: const Text('Semua',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              _buildRecentTransactions(walletIds),
              const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
            ],
          );
        },
      ),
    );
  }

  Widget _balanceAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white12, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetTracker(double expense) {
    final percent = (expense / _monthlyBudget).clamp(0.0, 1.0);
    final isWarning = percent > 0.8;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surfaceVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Target Budget Bulanan',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Text('${(percent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color:
                          isWarning ? AppColors.expense : AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              color: isWarning ? AppColors.expense : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'Sisa: ${CurrencyFormatter.formatCurrency(_monthlyBudget - expense)}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600)),
              Text('Dari ${CurrencyFormatter.formatCurrency(_monthlyBudget)}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(List<String> walletIds) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _firestoreService.getAllTransactionsStream(walletIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(32), child: LoadingWidget())));
        final txns = snapshot.data!;
        if (txns.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: AppColors.surfaceVariant.withAlpha(50)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      color: AppColors.textHint.withOpacity(0.3), size: 32),
                  const SizedBox(height: 12),
                  const Text('Satu catatan, satu perubahan!',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const Text('Belum ada transaksi di bulan ini uuu.',
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 11)),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final t = txns[index];
              final isIncome = t.isIncome;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.015),
                          blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: (isIncome
                                    ? AppColors.income
                                    : AppColors.expense)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14)),
                        child: Icon(
                            TransactionCategory.getIconForCategory(t.category),
                            color:
                                isIncome ? AppColors.income : AppColors.expense,
                            size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                                t.note.isEmpty
                                    ? DateFormat('dd MMM yyyy').format(t.date)
                                    : t.note,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      Text(
                          '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(t.amount)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isIncome
                                  ? AppColors.income
                                  : AppColors.expense,
                              fontSize: 15)),
                    ],
                  ),
                ),
              );
            },
            childCount: txns.length > 5 ? 5 : txns.length,
          ),
        );
      },
    );
  }

  void _showProfileMenu() {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 24),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 40,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(user?.displayName ?? 'User',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              _buildProfileMenuItem(
                icon: Icons.shield_outlined,
                label: 'Kunci Sidik Jari/Wajah',
                onTap: () async {
                  final newVal = !_isBiometricEnabled;
                  final canAuth = await _securityService.isBiometricAvailable();
                  if (!canAuth) return;
                  final authSuccess = await _securityService.authenticate();
                  if (authSuccess) {
                    await _securityService.setBiometricEnabled(newVal);
                    setModalState(() => _isBiometricEnabled = newVal);
                    setState(() => _isBiometricEnabled = newVal);
                  }
                },
                trailing: Switch(
                  value: _isBiometricEnabled,
                  onChanged: (val) async {
                    final canAuth =
                        await _securityService.isBiometricAvailable();
                    if (!canAuth) return;
                    final authSuccess = await _securityService.authenticate();
                    if (authSuccess) {
                      await _securityService.setBiometricEnabled(val);
                      setModalState(() => _isBiometricEnabled = val);
                      setState(() => _isBiometricEnabled = val);
                    }
                  },
                  activeColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withOpacity(0.4),
                ),
              ),
              _buildProfileMenuItem(
                icon: Icons.track_changes_rounded,
                label: 'Target Budget Bulanan',
                onTap: () {
                  Navigator.pop(context);
                  _showBudgetDialog();
                },
                trailing: Text(
                    _monthlyBudget > 0
                        ? CurrencyFormatter.formatCurrency(_monthlyBudget)
                        : 'Atur',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              _buildProfileMenuItem(
                icon: Icons.notifications_none_rounded,
                label: 'Pengingat Jurnal Harian',
                subtitle: _isNotificationEnabled
                    ? 'Ingatkan setiap pukul ${_reminderTime.format(context)}'
                    : 'Ketuk untuk aktifkan',
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  if (!_isNotificationEnabled) {
                    final pickedTime = await showTimePicker(
                        context: context, initialTime: _reminderTime);
                    if (pickedTime != null) {
                      await prefs.setBool('use_notifications', true);
                      await prefs.setInt('reminder_hour', pickedTime.hour);
                      await prefs.setInt('reminder_minute', pickedTime.minute);

                      try {
                        await _notificationService.init();
                        await _notificationService.scheduleDailyReminder(
                            hour: pickedTime.hour, minute: pickedTime.minute);
                        setModalState(() {
                          _isNotificationEnabled = true;
                          _reminderTime = pickedTime;
                        });
                        setState(() {
                          _isNotificationEnabled = true;
                          _reminderTime = pickedTime;
                        });
                      } catch (e) {
                        debugPrint('Notification fail: $e');
                      }
                    }
                  } else {
                    await prefs.setBool('use_notifications', false);
                    await _notificationService.cancelAll();
                    setModalState(() => _isNotificationEnabled = false);
                    setState(() => _isNotificationEnabled = false);
                  }
                },
                trailing: Switch(
                  value: _isNotificationEnabled,
                  onChanged: (val) async {
                    // This will trigger the same logic as onTap
                    if (val && !_isNotificationEnabled) {
                      final pickedTime = await showTimePicker(
                          context: context, initialTime: _reminderTime);
                      if (pickedTime != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('use_notifications', true);
                        await prefs.setInt('reminder_hour', pickedTime.hour);
                        await prefs.setInt(
                            'reminder_minute', pickedTime.minute);
                        await _notificationService.init();
                        await _notificationService.scheduleDailyReminder(
                            hour: pickedTime.hour, minute: pickedTime.minute);
                        setModalState(() {
                          _isNotificationEnabled = true;
                          _reminderTime = pickedTime;
                        });
                        setState(() {
                          _isNotificationEnabled = true;
                          _reminderTime = pickedTime;
                        });
                      }
                    } else if (!val && _isNotificationEnabled) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('use_notifications', false);
                      await _notificationService.cancelAll();
                      setModalState(() => _isNotificationEnabled = false);
                      setState(() => _isNotificationEnabled = false);
                    }
                  },
                  activeColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
              const Divider(),
              _buildProfileMenuItem(
                  icon: Icons.person_outline,
                  label: 'Edit Profil',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileScreen()))),
              _buildProfileMenuItem(
                  icon: Icons.help_outline,
                  label: 'Bantuan',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HelpScreen()))),
              _buildProfileMenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'Tentang Aplikasi',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()))),
              _buildProfileMenuItem(
                  icon: Icons.logout,
                  label: 'Keluar',
                  iconColor: AppColors.expense,
                  textColor: AppColors.expense,
                  onTap: () async {
                    final confirm = await UIHelper.showConfirmDialog(
                      context: context,
                      title: 'Keluar Akun?',
                      message:
                          'Pastikan kamu sudah mencatat semua transaksi hari ini ya!',
                    );
                    if (confirm == true) {
                      await _authService.signOut();
                      if (mounted)
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (r) => false);
                    }
                  }),
            ],
          ),
        ),
      ),
    );
  }

  void _showBudgetDialog() {
    final controller = TextEditingController(
        text: _monthlyBudget == 0 ? '' : _monthlyBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Target Budget'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: 'Rp ')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final budget = double.tryParse(controller.text) ?? 0.0;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setDouble('monthly_budget', budget);
              setState(() => _monthlyBudget = budget);
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.black87,
    Color textColor = Colors.black87,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textHint))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
