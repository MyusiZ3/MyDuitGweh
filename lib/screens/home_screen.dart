import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/notification_service.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/connection_badge.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import 'main_nav.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'admin/admin_tools_screen.dart';
import '../widgets/bottom_sheets/experience_survey_sheet.dart';
import '../models/survey_config_model.dart';

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
  final Set<String> _dismissedBroadcasts = {};
  final Set<String> _seenBroadcasts = {};
  double _monthlyBudget = 0.0;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  StreamSubscription? _notifListener;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  late Stream<List<WalletModel>> _walletsStream;
  StreamSubscription? _broadcastSub;
  int _unreadBroadcasts = 0;
  List<Map<String, dynamic>> _currentActiveBroadcasts = [];

  @override
  void initState() {
    super.initState();
    _notificationService.init(); // Inisiasi & Minta Izin Notifikasi awal
    _loadSettings();
    _checkAppLock();
    _initNotificationListener();
    _checkAdminRole();
    _walletsStream = _firestoreService.getWalletsStream(_uid);
    _initSurveyListener();
    
    // Auto-trigger survey check after minor delay
    Future.delayed(const Duration(seconds: 5), () => _checkAndShowSurvey(autoTrigger: true));
  }

  StreamSubscription? _surveyConfigSub;
  SurveyConfigModel? _currentSurveyConfig;

  void _initSurveyListener() {
    _surveyConfigSub = _firestoreService.getSurveyConfigStream().listen((config) {
      if (!mounted) return;
      
      // If status changed from inactive to active, and we are not in admin mode
      if (_currentSurveyConfig != null && 
          !_currentSurveyConfig!.isAvailable && 
          config.isAvailable && 
          !_isAdmin) {
        UIHelper.showSuccessSnackBar(context, '📣 Survei Kepuasan Baru tersedia! Cek di profil ya.');
      }
      
      setState(() => _currentSurveyConfig = config);
    });
  }

  void _initNotificationListener() {
    // 1. Listen for standard user notifications (Personal / Wallet)
    _notifListener = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final docId = change.doc.id;
          final displayCount = data['displayCount'] ?? 0;
          final title = data['title'] ?? '📢 Kabar Baru!';
          final message = data['message'] ?? '';

          // Show Instant Notification (System/Tray)
          _notificationService.showInstant(
            id: docId.hashCode,
            title: title,
            body: message.replaceAll('*', '').replaceAll('_', ''),
          );

          // Premium In-App Dialog
          if (displayCount < 2) {
            _showPremiumBroadcast(docId, title, message,
                currentCount: displayCount);
          }
        }
      }
    });

    // 2. Listen for GLOBAL announcements (Systemwide)
    _broadcastSub = _firestoreService
        .getBroadcastsStream(includePast: false)
        .listen((broadcasts) async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final lastNotifiedId =
          prefs.getString('last_notified_broadcast_id') ?? '';

      // Track active broadcasts for marking as seen later
      final activeBroadcasts =
          broadcasts.where((b) => b['status'] == 'ongoing').toList();
      _currentActiveBroadcasts = activeBroadcasts;

      // Unread = active + not yet SEEN by user (not dismissed)
      final unseenCount = activeBroadcasts
          .where((b) => !_seenBroadcasts.contains(b['id']))
          .length;

      setState(() => _unreadBroadcasts = unseenCount);

      if (activeBroadcasts.isNotEmpty) {
        final latest = activeBroadcasts.first;
        final latestId = latest['id'] as String;

        // Show System Notification IF we haven't notified for this specific ID before
        if (latestId != lastNotifiedId) {
          _notificationService.showInstant(
            id: latestId.hashCode,
            title: '📣 PENGUMUMAN BARU',
            body: latest['title'] ?? '',
          );
          await prefs.setString('last_notified_broadcast_id', latestId);

          // Premium In-App Dialog for Broadcast
          if (mounted) {
            _showPremiumBroadcast(
                null, latest['title'] ?? 'PENGUMUMAN', latest['message'] ?? '');
          }
        }
      }
    });
  }

  void _showPremiumBroadcast(String? docId, String title, String message,
      {int? currentCount}) {
    if (!mounted) return;

    if (docId != null && currentCount != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('notifications')
          .doc(docId)
          .update({'displayCount': currentCount + 1});
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 15)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 24),
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.primary, size: 32),
                    const SizedBox(height: 16),
                    Text(title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppColors.primary,
                            decoration: TextDecoration.none)),
                    const SizedBox(height: 12),
                    Material(
                        color: Colors.transparent,
                        child: _renderMarkdown(message)),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(
                          child: Text('OK, UNDERSTOOD',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  fontSize: 13,
                                  decoration: TextDecoration.none)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  Widget _renderMarkdown(String text) {
    // Parser Sederhana untuk Bold (**) dan Italic (*)
    List<TextSpan> spans = [];
    final regExp = RegExp(r'(\*\*.*?\*\*|\*.*?\*)');
    int lastMatchEnd = 0;

    for (var match in regExp.allMatches(text)) {
      // Teks sebelum match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      String found = match.group(0)!;
      if (found.startsWith('**')) {
        spans.add(TextSpan(
            text: found.substring(2, found.length - 2),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)));
      } else {
        spans.add(TextSpan(
            text: found.substring(1, found.length - 1),
            style: const TextStyle(
                fontStyle: FontStyle.italic, color: AppColors.textPrimary)));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
            fontSize: 15, color: AppColors.textSecondary, height: 1.5),
        children: spans,
      ),
    );
  }

  @override
  void dispose() {
    _notifListener?.cancel();
    _broadcastSub?.cancel();
    _surveyConfigSub?.cancel();
    super.dispose();
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
      final dismissedList = prefs.getStringList('dismissed_broadcasts') ?? [];
      _dismissedBroadcasts.clear();
      _dismissedBroadcasts.addAll(dismissedList);
      final seenList = prefs.getStringList('seen_broadcasts') ?? [];
      _seenBroadcasts.clear();
      _seenBroadcasts.addAll(seenList);

      final savedHour = prefs.getInt('reminder_hour') ?? 20;
      final savedMinute = prefs.getInt('reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: savedHour, minute: savedMinute);
    });
  }

  Future<void> _saveDismissedBroadcast(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _dismissedBroadcasts.add(id));
    await prefs.setStringList(
        'dismissed_broadcasts', _dismissedBroadcasts.toList());
  }

  Future<void> _checkAdminRole() async {
    // Pengecekan pertama (Langsung & Force Refresh)
    bool isAdmin = await _authService.isAdmin(uid: _uid, forceRefresh: true);
    bool isSuper =
        await _authService.isSuperAdmin(uid: _uid, forceRefresh: true);

    // Jika gagal, coba lagi sekali setelah 1.5 detik
    // (Beri napas buat Firestore sinkron data session/role)
    if (!isAdmin) {
      await Future.delayed(const Duration(milliseconds: 1500));
      isAdmin = await _authService.isAdmin(uid: _uid, forceRefresh: true);
      isSuper = await _authService.isSuperAdmin(uid: _uid, forceRefresh: true);
    }

    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isSuperAdmin = isSuper;
      });
    }
  }

  Future<void> _handleRefresh() async {
    // Karena menggunakan StreamBuilder, data otomatis terupdate.
    // Kita berikan delay kecil untuk estetika UX (memberi rasa 'loading').
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await _loadSettings();
      UIHelper.showSuccessSnackBar(context, 'Data berhasil diperbarui! ✨');
    }
  }

  String _getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final totalMinutes = hour * 60 + minute;

    // Pagi: 03:00 - 11:30
    if (totalMinutes >= 180 && totalMinutes <= 690) {
      return ToneManager.t('greeting_pagi');
    }
    // Siang: 11:31 - 14:30
    if (totalMinutes >= 691 && totalMinutes <= 870) {
      return ToneManager.t('greeting_siang');
    }
    // Sore: 14:31 - 17:59
    if (totalMinutes >= 871 && totalMinutes <= 1079) {
      return ToneManager.t('greeting_sore');
    }
    // Malam: 18:00 - 02:59
    return ToneManager.t('greeting_malam');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ValueListenableBuilder<AppTone>(
      valueListenable: ToneManager.notifier,
      builder: (context, activeTone, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: StreamBuilder<List<WalletModel>>(
            stream: _walletsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ShimmerHomeScreen();
              }
              if (!snapshot.hasData)
                return const Center(child: Text('Tidak ada data'));

              final wallets = snapshot.data!;
              final totalBalance =
                  wallets.fold<double>(0, (sum, w) => sum + w.balance);
              final walletIds = wallets.map((w) => w.id).toList();

              return RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppColors.primary,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
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
                              Row(
                                children: [
                                  Text(user?.displayName ?? 'Pengguna',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.5)),
                                  if (_isAdmin) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: _isSuperAdmin
                                              ? [
                                                  const Color(0xFFFFD700),
                                                  const Color(0xFFFFA500)
                                                ]
                                              : [
                                                  const Color(0xFF2196F3),
                                                  const Color(0xFF1976D2)
                                                ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (_isSuperAdmin
                                                    ? const Color(0xFFFFD700)
                                                    : Colors.blue)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                              _isSuperAdmin
                                                  ? Icons
                                                      .workspace_premium_rounded
                                                  : Icons.shield_rounded,
                                              color: Colors.white,
                                              size: 10),
                                          const SizedBox(width: 4),
                                          Text(
                                              _isSuperAdmin ? 'OWNER' : 'ADMIN',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(_uid)
                                .collection('notifications')
                                .where('isRead', isEqualTo: false)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final unreadCount = (snapshot.hasData
                                      ? snapshot.data!.docs.length
                                      : 0) +
                                  _unreadBroadcasts;
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      // Mark all current broadcasts as SEEN
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      for (var b in _currentActiveBroadcasts) {
                                        _seenBroadcasts.add(b['id'] as String);
                                      }
                                      await prefs.setStringList(
                                          'seen_broadcasts',
                                          _seenBroadcasts.toList());
                                      setState(() => _unreadBroadcasts = 0);

                                      if (!mounted) return;
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const NotificationsScreen()));
                                      // Reload dismissed list (user might have swiped some)
                                      _loadSettings();
                                    },
                                    icon: const Icon(
                                        Icons.notifications_none_rounded,
                                        color: AppColors.textPrimary,
                                        size: 26),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                            color: AppColors.expense,
                                            shape: BoxShape.circle),
                                        child: Text(
                                          unreadCount > 9
                                              ? '9+'
                                              : '$unreadCount',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: _showProfileMenu,
                            child: ConnectionBadge(
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color:
                                          AppColors.primary.withOpacity(0.15),
                                      width: 1.5),
                                ),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 19,
                                      backgroundColor:
                                          AppColors.primary.withOpacity(0.1),
                                      backgroundImage: user?.photoURL != null
                                          ? NetworkImage(user!.photoURL!)
                                          : null,
                                      child: user?.photoURL == null
                                          ? const Icon(Icons.person_rounded,
                                              size: 22,
                                              color: AppColors.primary)
                                          : null,
                                    ),
                                    if (_isAdmin)
                                      // Admin Badge (Top Left)
                                      Positioned(
                                        top: -3,
                                        left: -3,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.verified_rounded,
                                            color: AppColors.primary,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 1. BROADCAST & MAINTENANCE BANNERS
                    SliverToBoxAdapter(
                        child: _buildBroadcastAndMaintenanceBanners()),

                    // 2. MAIN BALANCE CARD
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark
                              ],
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(ToneManager.t('home_balance'),
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isBalanceVisible = !_isBalanceVisible;
                                      });
                                      // Simpan ke background biar gak ganggu UI thread
                                      SharedPreferences.getInstance()
                                          .then((prefs) {
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
                                      ? CurrencyFormatter.formatCurrency(
                                          totalBalance)
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
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _balanceAction(
                                              Icons
                                                  .account_balance_wallet_rounded,
                                              ToneManager.t('nav_wallet'), () {
                                            MainNav.of(context)?.setTab(1);
                                          }),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _balanceAction(
                                              Icons.insights_rounded,
                                              ToneManager.t('nav_report'), () {
                                            MainNav.of(context)?.setTab(4);
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
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
                        padding: const EdgeInsets.only(
                            top: 16, bottom: 12, left: 24),
                        child: Text('Daftar Dompet',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: wallets.isEmpty
                          ? Container(
                              height: 120,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color:
                                        AppColors.surfaceVariant.withAlpha(50)),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined,
                                      color:
                                          AppColors.textHint.withOpacity(0.3),
                                      size: 32),
                                  const SizedBox(height: 8),
                                  const Text('Belum ada dompet nih!',
                                      style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  const Text('Buat dompet pertamamu yuk!',
                                      style: TextStyle(
                                          color: AppColors.textHint,
                                          fontSize: 11)),
                                ],
                              ),
                            )
                          : SizedBox(
                              height: 100,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                                CurrencyFormatter
                                                    .formatCurrency(w.balance),
                                                style: const TextStyle(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w800)),
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
                            Text(ToneManager.t('home_recent'),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                            TextButton(
                              onPressed: () => MainNav.of(context)?.setTab(4),
                              child: const Text('Semua',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildRecentTransactions(walletIds),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
                  ],
                ),
              );
            },
          ),
        );
      },
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
          mainAxisSize: MainAxisSize.min, // CRITICAL: Wrap tightly
          mainAxisAlignment: MainAxisAlignment.center, // Bikin tengah
          children: [
            Icon(icon, color: Colors.white, size: 16), // Slightly bigger
            const SizedBox(width: 8), // More breathing room
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
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
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                      'Sisa: ${CurrencyFormatter.formatCurrency(_monthlyBudget - expense)}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                      'Dari ${CurrencyFormatter.formatCurrency(_monthlyBudget)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ),
              ),
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
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: ShimmerTransactionList()));
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
                  const Icon(Icons.history_toggle_off_rounded,
                      color: AppColors.textHint, size: 40),
                  const SizedBox(height: 12),
                  Text(ToneManager.t('home_empty_title'),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(ToneManager.t('home_empty_msg'),
                      style: const TextStyle(
                          color: AppColors.textHint, fontSize: 12)),
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
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.35),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(t.amount)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isIncome
                                      ? AppColors.income
                                      : AppColors.expense,
                                  fontSize: 15)),
                        ),
                      ),
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
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(user?.displayName ?? 'User',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isSuperAdmin
                            ? Colors.amber.withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _isSuperAdmin ? Colors.amber : AppColors.primary,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSuperAdmin
                                ? Icons.stars_rounded
                                : Icons.verified_user_rounded,
                            size: 10,
                            color: _isSuperAdmin
                                ? Colors.amber[900]
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isSuperAdmin ? 'OWNER' : 'ADMIN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: _isSuperAdmin
                                  ? Colors.amber[900]
                                  : AppColors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
              if (_isAdmin)
                _buildProfileMenuItem(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Admin Control Tools',
                  subtitle: 'Maintenance & Broadcast',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminToolsScreen()));
                  },
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppColors.primary),
                ),
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
                icon: Icons.language_rounded,
                label: ToneManager.t('profile_tone'),
                onTap: () {
                  Navigator.pop(context);
                  _showToneSelector();
                },
                trailing: Text(ToneManager.notifier.value.name.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
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
                icon: Icons.rate_review_outlined,
                label: 'Survei Kepuasan',
                onTap: () {
                  Navigator.pop(context);
                  _checkAndShowSurvey();
                },
              ),
              _buildProfileMenuItem(
                  icon: Icons.logout,
                  label: ToneManager.t('profile_logout'),
                  iconColor: AppColors.expense,
                  textColor: AppColors.expense,
                  onTap: () async {
                    final confirm = await UIHelper.showConfirmDialog(
                      context: context,
                      title: ToneManager.t('dialog_logout_title'),
                      message: ToneManager.t('dialog_logout_msg'),
                      confirmText: ToneManager.t('dialog_yes'),
                      cancelText: ToneManager.t('dialog_no'),
                      isDangerous: false, // Logout isn't scary like a deletion
                    );
                    if (confirm == true) {
                      Navigator.pop(context);
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
            ],
          ),
        ),
      ),
    );
  }

  void _showToneSelector() {
    UIHelper.showToneSelector(context);
  }

  Future<void> _checkAndShowSurvey({bool autoTrigger = false}) async {
    // 1. Get current config (use cached if available)
    final config = _currentSurveyConfig ?? await FirebaseFirestore.instance
        .collection('app_config')
        .doc('survey')
        .get()
        .then((doc) => doc.exists 
            ? SurveyConfigModel.fromJson(doc.data()!) 
            : SurveyConfigModel(isAvailable: true, minTransactions: 0, minAccountAgeDays: 0));

    if (config == null || !config.isAvailable) {
      if (!autoTrigger && mounted) {
        UIHelper.showInfoDialog(
          context, 
          'Survei Ditutup', 
          'Maaf banget, survei saat ini sedang ditutup oleh Archen. Ditunggu jadwal berikutnya ya! 🙏'
        );
      }
      return;
    }

    // 2. Extra checks for Auto-Trigger
    if (autoTrigger) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final bool alreadyDone = userData['surveyDone'] ?? false;
      if (alreadyDone) return;

      final createdAt = (userData['createdAt'] as Timestamp).toDate();
      final accountAgeDays = DateTime.now().difference(createdAt).inDays;
      
      if (accountAgeDays < (config.minAccountAgeDays ?? 0)) return;

      // Check transaction count
      final txCount = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('transactions')
          .count()
          .get()
          .then((v) => v.count);

      if ((txCount ?? 0) < (config.minTransactions ?? 0)) return;
    }

    if (mounted) _showSurveySheet();
  }

  void _showSurveySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExperienceSurveySheet(),
    );
  }

  void _showBudgetDialog() {
    final controller = TextEditingController(
        text: _monthlyBudget == 0 ? '' : _monthlyBudget.toStringAsFixed(0));
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 10))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.track_changes_rounded,
                              color: AppColors.primary, size: 32),
                        ),
                        const SizedBox(height: 20),
                        const Text('Target Budget',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text('Atur batas pengeluaran bulananmu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black54),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              hintText: '0',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.pop(ctx),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: const Center(
                                    child: Text('Batal',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final budget = double.tryParse(controller.text) ?? 0.0;
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setDouble('monthly_budget', budget);
                                  setState(() => _monthlyBudget = budget);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppColors.primary.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4))
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text('Simpan',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
    Color textColor = Colors.black87,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildBroadcastAndMaintenanceBanners() {
    return Column(
      children: [
        // 1. Maintenance Stream
        StreamBuilder<DocumentSnapshot>(
          stream: _firestoreService.getMaintenanceConfigStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists)
              return const SizedBox();
            final config = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final isMaintenance = config['isMaintenance'] ?? false;
            final startTime =
                (config['maintenanceStartTime'] as Timestamp?)?.toDate();
            final msg = config['message'] ?? 'Maintenance mode aktif.';

            final now = DateTime.now();
            final isRelevant = isMaintenance ||
                (startTime != null && startTime.difference(now).inHours < 24);

            if (!isRelevant) return const SizedBox();

            return Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isMaintenance ? Colors.red[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: (isMaintenance
                        ? Colors.red[100]
                        : Colors.orange[100])!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isMaintenance ? Colors.red : Colors.orange)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMaintenance
                          ? Icons.construction_rounded
                          : Icons.pending_actions_rounded,
                      color: isMaintenance ? Colors.red : Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMaintenance
                              ? 'SISTEM SEDANG DIPERBAIKI'
                              : 'JADWAL PEMELIHARAAN',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: isMaintenance
                                  ? Colors.red[900]
                                  : Colors.orange[900]),
                        ),
                        Text(msg,
                            style: TextStyle(
                                fontSize: 10,
                                color: isMaintenance
                                    ? Colors.red[700]
                                    : Colors.orange[700],
                                height: 1.3)),
                        if (!isMaintenance && startTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                'Direncanakan: ${DateFormat('HH:mm, dd MMM').format(startTime)}',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.orange[800])),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 2. Broadcast Stream
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreService.getBroadcastsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty)
              return const SizedBox();

            // Filter: Ongoing broadcasts only, and not dismissed yet
            final activeBroadcasts = snapshot.data!.where((b) {
              final id = b['id'] as String;
              final String status = b['status'] ?? 'ONGOING';
              return status == 'ONGOING' && !_dismissedBroadcasts.contains(id);
            }).toList();

            if (activeBroadcasts.isEmpty) return const SizedBox();

            final latest = activeBroadcasts.first;
            final id = latest['id'] as String;
            final type = latest['type'] ?? 'info';
            final title = latest['title'] ?? '📢 Kabar Baru!';
            final message = latest['message'] ?? '';

            // PRIORITY: Urgent/Alert/News/Reminder trigger PREMIUM POPUP
            if (type == 'urgent' ||
                type == 'alert' ||
                type == 'news' ||
                type == 'reminder') {
              Future.delayed(const Duration(milliseconds: 800), () {
                if (mounted && !_dismissedBroadcasts.contains(id)) {
                  _showPremiumBroadcastPopup(latest);
                }
              });
              return const SizedBox(); // Hide banner if it's a popup type
            }

            // DEFAULT: Info shows as banner
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_rounded,
                        color: Colors.blue, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(message,
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _saveDismissedBroadcast(id),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showPremiumBroadcastPopup(Map<String, dynamic> broadcast) {
    if (!mounted) return;
    final id = broadcast['id'] as String;
    final type = broadcast['type'] ?? 'info';
    IconData displayIcon = Icons.notifications_active_rounded;
    Color displayColor = Colors.blue;

    if (type == 'urgent') {
      displayIcon = Icons.warning_rounded;
      displayColor = Colors.red;
    } else if (type == 'news') {
      displayIcon = Icons.auto_awesome_rounded;
      displayColor = Colors.purple;
    } else if (type == 'reminder') {
      displayIcon = Icons.alarm_on_rounded;
      displayColor = Colors.teal;
    }

    final title = broadcast['title'] ?? 'Broadcast';
    final message = broadcast['message'] ?? '';
    final isUrgent = type == 'urgent' || type == 'alert';

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (ctx, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                  color: (isUrgent ? Colors.red : AppColors.primary)
                      .withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 20)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: displayColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        displayIcon,
                        color: displayColor,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(type.toUpperCase().replaceAll('_', ' '),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: displayColor,
                            decoration: TextDecoration.none)),
                    const SizedBox(height: 12),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            decoration: TextDecoration.none,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.6,
                            fontWeight: FontWeight.normal,
                            decoration: TextDecoration.none)),
                    const SizedBox(height: 32),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          _saveDismissedBroadcast(id);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Center(
                            child: Text('UNDERSTOOD',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );
  }
}
