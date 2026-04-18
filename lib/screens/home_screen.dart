import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/security_service.dart';
import '../services/notification_service.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/connection_badge.dart';
import '../models/debt_model.dart';
import '../services/debt_service.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import 'main_nav.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'notifications_screen.dart';
import 'admin/admin_tools_screen.dart';
import '../widgets/bottom_sheets/experience_survey_sheet.dart';
import '../models/survey_config_model.dart';
import '../utils/debouncer.dart';
import '../utils/theme_manager.dart';

import '../widgets/home/home_sliver_app_bar.dart';
import '../widgets/home/home_balance_card.dart';
import '../widgets/home/home_budget_tracker.dart';
import '../widgets/home/home_wallet_list.dart';
import '../widgets/home/home_recent_transactions.dart';
import '../widgets/home/home_recent_transactions_header.dart';
import '../widgets/home/home_bento_grid.dart';

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
  final DebtService _debtService = DebtService();
  final RefreshThrottle _refreshThrottle = RefreshThrottle();
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
  int _unreadPersonal = 0;
  List<Map<String, dynamic>> _currentActiveBroadcasts = [];

  bool _isCheckingSurvey = false;
  bool _isSurveyOpen = false;

  @override
  void initState() {
    super.initState();
    // VITAL: Inisialisasi stream SECEPATNYA sebelum build pertama berjalan
    _walletsStream = _firestoreService.getWalletsStream(_uid);
    _handleInit();
  }

  Future<void> _handleInit() async {
    await _notificationService.init(); // Inisiasi & Minta Izin Notifikasi awal
    _loadSettings();
    _checkAppLock();
    _initNotificationListener();
    _checkAdminRole();
    _initSurveyListener();
  }

  StreamSubscription? _surveyConfigSub;
  SurveyConfigModel? _currentSurveyConfig;

  void _initSurveyListener() {
    _surveyConfigSub =
        _firestoreService.getSurveyConfigStream().listen((config) {
      if (!mounted) return;

      // If status changed from inactive to active, and we are not in admin mode
      if (_currentSurveyConfig != null &&
          !_currentSurveyConfig!.isAvailable &&
          config.isAvailable &&
          !_isAdmin) {
        UIHelper.showSuccessSnackBar(
            context, 'Survei Kepuasan Baru tersedia! Cek di profil ya.');
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

      // Update unread count for personal notifications
      setState(() => _unreadPersonal = snapshot.docs.length);

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

      // Local Schedule for Pending Broadcasts
      final pendingBroadcasts =
          broadcasts.where((b) => b['status'] == 'pending').toList();
      for (var b in pendingBroadcasts) {
        final rawId = b['id']?.toString();
        final rawTime = b['scheduledTime'];

        if (rawId != null && rawTime != null && rawTime is Timestamp) {
          try {
            final time = rawTime.toDate();
            _notificationService.scheduleBroadcast(
              id: rawId.hashCode,
              title: b['title']?.toString() ?? 'Pengumuman',
              body: b['message']?.toString() ?? 'Ada info penting nih!',
              scheduledTime: time,
            );
          } catch (e) {
            print('Error scheduling locally: $e');
          }
        }
      }

      // Unread = active + not yet SEEN by user (not dismissed)
      final unseenCount = activeBroadcasts
          .where((b) => b['id'] != null && !_seenBroadcasts.contains(b['id']))
          .length;

      setState(() => _unreadBroadcasts = unseenCount);

      if (activeBroadcasts.isNotEmpty) {
        final latest = activeBroadcasts.first;
        final latestId = latest['id'] as String;

        // Show System Notification IF we haven't notified for this specific ID before
        if (latestId != lastNotifiedId) {
          _notificationService.showInstant(
            id: latestId.hashCode,
            title: latest['title'] ?? '📣 MyDuitGweh Update',
            body: latest['message'] ?? 'Ada info menarik nih buat kamu!',
          );
          await prefs.setString('last_notified_broadcast_id', latestId);

          // Premium In-App Dialog for Broadcast
          if (mounted) {
            _showPremiumBroadcast(
              null,
              latest['title'] ?? 'PENGUMUMAN',
              latest['message'] ?? 'Ada info menarik nih buat kamu!',
            );
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1C1C1E).withOpacity(0.9)
                      : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      width: 1),
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
                    Icon(CupertinoIcons.sparkles,
                        color: AppColors.primary, size: 32),
                    const SizedBox(height: 16),
                    Text(title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text('OK, UNDERSTOOD',
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.black
                                      : Colors.white,
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
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color)));
      } else {
        spans.add(TextSpan(
            text: found.substring(1, found.length - 1),
            style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).textTheme.titleLarge?.color)));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            height: 1.5),
        children: spans,
      ),
    );
  }

  String _getThemeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
      default:
        return 'Sistem';
    }
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(CupertinoIcons.paintbrush,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Tampilan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      Text(
                        'Sesuaikan app dengan seleramu',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeManager.notifier,
              builder: (context, currentMode, _) {
                return Column(
                  children: [
                    _buildThemeOption(
                      title: 'Sesuai Sistem',
                      icon: CupertinoIcons.circle_lefthalf_fill,
                      mode: ThemeMode.system,
                      isSelected: currentMode == ThemeMode.system,
                    ),
                    _buildThemeOption(
                      title: 'Terang',
                      icon: CupertinoIcons.sun_max_fill,
                      mode: ThemeMode.light,
                      isSelected: currentMode == ThemeMode.light,
                    ),
                    _buildThemeOption(
                      title: 'Gelap',
                      icon: CupertinoIcons.moon_fill,
                      mode: ThemeMode.dark,
                      isSelected: currentMode == ThemeMode.dark,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon,
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).iconTheme.color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isSelected
          ? Icon(CupertinoIcons.checkmark_circle_fill, color: AppColors.primary)
          : null,
      onTap: () {
        ThemeManager.setThemeMode(mode);
        Navigator.pop(context);
      },
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
      // Tunggu frame selesai sebelum panggil dialog kustom
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _securityService.authenticate(context);
      });
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

    // Re-schedule notification on startup to ensure latest channel settings are applied
    if (_isNotificationEnabled) {
      try {
        await _notificationService.scheduleDailyReminder(
          hour: _reminderTime.hour,
          minute: _reminderTime.minute,
        );
      } catch (e) {
        debugPrint('Auto-schedule notification failed: $e');
      }
    }
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
    if (!_refreshThrottle.canRefresh) {
      UIHelper.showInfoSnackBar(
          context, 'Tunggu sebentar sebelum refresh lagi!');
      return;
    }

    // Mark as refreshed to start cooldown
    _refreshThrottle.markRefreshed();

    // Karena menggunakan StreamBuilder, data otomatis terupdate.
    // Kita berikan delay kecil untuk estetika UX (memberi rasa 'loading').
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      final isOnline = await ConnectivityService.isOnline();

      if (isOnline) {
        // Source of Truth Repair: Recalculate all balances from transactions
        await _firestoreService.syncAllBalances(_uid);
        await _loadSettings();
        UIHelper.showSuccessSnackBar(
            context, 'Data berhasil disinkronkan & diperbarui!');
      } else {
        await _loadSettings();
        UIHelper.showInfoSnackBar(context, 'Data dimuat dari cache (Offline)');
      }
    }
  }

  void _handleNotificationsTap() async {
    // Mark all current broadcasts as seen
    final prefs = await SharedPreferences.getInstance();
    for (var b in _currentActiveBroadcasts) {
      final id = b['id'] as String?;
      if (id != null) _seenBroadcasts.add(id);
    }
    await prefs.setStringList('seen_broadcasts', _seenBroadcasts.toList());
    setState(() => _unreadBroadcasts = 0);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );

    // Refresh after returning (in case they deleted some personal notifs or seen broadcasts)
    _loadSettings();
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser; // Test edit

    return ValueListenableBuilder<AppTone>(
      valueListenable: ToneManager.notifier,
      builder: (context, activeTone, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: StreamBuilder<List<WalletModel>>(
            stream: _walletsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ShimmerHomeScreen();
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('Tidak ada data'));
              }

              final wallets = snapshot.data!;
              final walletIds = wallets.map((w) => w.id).toList();
              final totalBalance =
                  wallets.fold<double>(0, (acc, w) => acc + w.balance);

              return StreamBuilder<List<DebtModel>>(
                stream: _debtService.getUserDebts(_uid),
                builder: (context, debtSnapshot) {
                  double totalDebt = 0;
                  double totalReceivable = 0;

                  if (debtSnapshot.hasData) {
                    for (var debt in debtSnapshot.data!) {
                      if (debt.status != 'completed') {
                        final remaining = debt.totalAmount - debt.paidAmount;
                        if (debt.type == 'utang') {
                          totalDebt += remaining;
                        } else {
                          totalReceivable += remaining;
                        }
                      }
                    }
                  }

                  final netWorth = totalBalance - totalDebt + totalReceivable;

                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: AppColors.primary,
                    backgroundColor: Colors.white,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      slivers: [
                        // 1. STICKY APP BAR
                        HomeSliverAppBar(
                          user: user,
                          isAdmin: _isAdmin,
                          isSuperAdmin: _isSuperAdmin,
                          unreadBroadcasts: _unreadBroadcasts + _unreadPersonal,
                          uid: _uid,
                          onProfileTap: _showProfileMenu,
                          onNotificationsTap: _handleNotificationsTap,
                        ),

                        // 2. MAIN BALANCE CARD
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          sliver: SliverToBoxAdapter(
                            child: HomeBalanceCard(
                              totalBalance: totalBalance,
                              netWorth: netWorth,
                              isBalanceVisible: _isBalanceVisible,
                              onToggleVisibility: () {
                                setState(() {
                                  _isBalanceVisible = !_isBalanceVisible;
                                });
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setBool(
                                      'show_balance', _isBalanceVisible);
                                });
                              },
                            ),
                          ),
                        ),


                        // 3. BENTO GRID (Budget Tracker, Daily Spend, Insights)
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 16),
                          sliver: SliverToBoxAdapter(
                            child: HomeBentoGrid(
                              uid: _uid,
                              monthlyBudget: _monthlyBudget,
                              firestoreService: _firestoreService,
                            ),
                          ),
                        ),

                        // 4. WALLET SUMMARY
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                            child: Text(
                              'Daftar Dompet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.color,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 8),
                          sliver: SliverToBoxAdapter(
                            child: HomeWalletList(wallets: wallets),
                          ),
                        ),

                        // 5. RECENT TRANSACTIONS
                        const HomeRecentTransactionsHeader(),
                        HomeRecentTransactions(
                          walletIds: walletIds,
                          firestoreService: _firestoreService,
                        ),
                        // Bottom spacer for floating navbar
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 150),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
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
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white24
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 40,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? Icon(CupertinoIcons.person_fill, size: 40)
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(user?.displayName ?? 'User',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.checkmark_shield_fill,
                            size: 10,
                            color: _isSuperAdmin
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.amber[300]
                                    : Colors.amber[900])
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isSuperAdmin ? 'OWNER' : 'ADMIN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: _isSuperAdmin
                                  ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.amber[300]
                                      : Colors.amber[900])
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
                          icon: CupertinoIcons.sparkles,
                          label: 'Admin Control Tools',
                          subtitle: 'Maintenance & Broadcast',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AdminToolsScreen()));
                          },
                          trailing: Icon(CupertinoIcons.chevron_forward,
                              size: 16, color: AppColors.primary),
                        ),
                      _buildProfileMenuItem(
                        icon: CupertinoIcons.shield,
                        label: 'Kunci Sidik Jari/Wajah',
                        onTap: () async {
                          final newVal = !_isBiometricEnabled;
                          final canAuth =
                              await _securityService.isBiometricAvailable();
                          if (!canAuth) return;
                          final authSuccess =
                              await _securityService.authenticate(context);
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
                            final authSuccess =
                                await _securityService.authenticate(context);
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
                        icon: CupertinoIcons.flag,
                        label: 'Target Budget Bulanan',
                        onTap: () {
                          Navigator.pop(context);
                          _showBudgetDialog();
                        },
                        trailing: Text(
                            _monthlyBudget > 0
                                ? CurrencyFormatter.formatCurrency(
                                    _monthlyBudget)
                                : 'Atur',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      _buildProfileMenuItem(
                        icon: CupertinoIcons.bell,
                        label: 'Pengingat Harian',
                        subtitle: _isNotificationEnabled
                            ? 'Ingatkan setiap pukul ${_reminderTime.format(context)}'
                            : 'Ketuk untuk aktifkan',
                        onTap: () => _handleDailyReminderToggle(setModalState),
                        trailing: Switch(
                          value: _isNotificationEnabled,
                          onChanged: (_) =>
                              _handleDailyReminderToggle(setModalState),
                          activeColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      _buildProfileMenuItem(
                        icon: CupertinoIcons.paintbrush,
                        label: 'Tampilan',
                        subtitle:
                            _getThemeModeLabel(ThemeManager.notifier.value),
                        onTap: () {
                          Navigator.pop(context);
                          _showThemeSelector();
                        },
                        trailing: Icon(CupertinoIcons.chevron_forward,
                            size: 16, color: AppColors.primary),
                      ),
                      const Divider(),
                      _buildProfileMenuItem(
                        icon: CupertinoIcons.globe,
                        label: ToneManager.t('profile_tone'),
                        onTap: () {
                          Navigator.pop(context);
                          _showToneSelector();
                        },
                        trailing: Text(
                            ToneManager.notifier.value.name.toUpperCase(),
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      _buildProfileMenuItem(
                          icon: CupertinoIcons.person,
                          label: 'Edit Profil',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen()))),
                      _buildProfileMenuItem(
                          icon: CupertinoIcons.question_circle,
                          label: 'Bantuan',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HelpScreen()))),
                      _buildProfileMenuItem(
                          icon: CupertinoIcons.info,
                          label: 'Tentang Aplikasi',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AboutScreen()))),
                      _buildProfileMenuItem(
                        icon: CupertinoIcons.square_pencil,
                        label: 'Survei Kepuasan',
                        onTap: () {
                          Navigator.pop(context);
                          _checkAndShowSurvey();
                        },
                      ),
                      _buildProfileMenuItem(
                          icon: CupertinoIcons.power,
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
                              isDangerous:
                                  false, // Logout isn't scary like a deletion
                            );
                            if (confirm == true) {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                              debugPrint('LOGOUT: Memulai proses sign out...');
                              await _authService.signOut();
                              debugPrint('LOGOUT: Sign out selesai.');
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

  Future<void> _checkAndShowSurvey() async {
    if (_isCheckingSurvey || _isSurveyOpen) return;

    _isCheckingSurvey = true;

    if (mounted) {
      UIHelper.showLoadingDialog(context, message: 'Memeriksa kriteria...');
    }

    try {
      final results = await Future.wait([
        _currentSurveyConfig != null
            ? Future.value(_currentSurveyConfig)
            : FirebaseFirestore.instance
                .collection('app_config')
                .doc('survey')
                .get()
                .then((doc) => doc.exists
                    ? SurveyConfigModel.fromJson(doc.data()!)
                    : null),
        FirebaseFirestore.instance.collection('users').doc(_uid).get(),
        FirebaseFirestore.instance
            .collection('transactions')
            .where('createdBy', isEqualTo: _uid)
            .count()
            .get(),
      ]);

      final config = results[0] as SurveyConfigModel?;
      final userDoc = results[1] as DocumentSnapshot;
      final txCountResult = results[2] as AggregateQuerySnapshot;

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (config == null || !config.isAvailable) {
        if (mounted) {
          UIHelper.showInfoDialog(context, 'Survei Ditutup',
              'Maaf, survei saat ini sedang ditutup. Ditunggu jadwal berikutnya ya!');
        }
        return;
      }

      if (!userDoc.exists) return;
      final userData = userDoc.data() as Map<String, dynamic>;
      final bool alreadyDone = userData['surveyDone'] ?? false;

      if (alreadyDone) {
        if (mounted) {
          UIHelper.showInfoDialog(context, 'Sudah Berpartisipasi',
              'Anda sudah mengisi survei ini sebelumnya. Terima kasih banyak atas masukannya!');
        }
        return;
      }

      DateTime createdAt = (userData['createdAt'] as Timestamp?)?.toDate() ??
          FirebaseAuth.instance.currentUser?.metadata.creationTime ??
          DateTime.now();
      final accountAgeDays =
          (DateTime.now().difference(createdAt).inHours / 24).ceil();
      final minAge = config.minAccountAgeDays;

      if (accountAgeDays < minAge) {
        if (mounted) {
          UIHelper.showInfoDialog(context, 'Belum Memenuhi Syarat',
              'Maaf, Anda perlu menggunakan aplikasi minimal selama $minAge hari untuk memberikan feedback. (Akun Anda: $accountAgeDays hari)');
        }
        return;
      }

      final txCount = txCountResult.count ?? 0;
      final minTx = config.minTransactions;

      if (txCount < minTx) {
        if (mounted) {
          UIHelper.showInfoDialog(context, 'Belum Memenuhi Syarat',
              'Anda perlu memiliki minimal $minTx transaksi sukses untuk memberikan feedback. (Saat ini: $txCount transaksi)');
        }
        return;
      }

      if (mounted) _showSurveySheet();
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        UIHelper.showErrorSnackBar(context, 'Gagal memuat kriteria: $e');
      }
      debugPrint('SURVEY ERROR: $e');
    } finally {
      _isCheckingSurvey = false;
    }
  }

  Future<void> _handleDailyReminderToggle(StateSetter setModalState) async {
    final prefs = await SharedPreferences.getInstance();

    if (!_isNotificationEnabled) {
      // Step 1: Open time picker
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _reminderTime,
        helpText: 'Pilih Waktu Pengingat',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        // Step 2: Optimistic UI Update
        final oldState = _isNotificationEnabled;
        final oldTime = _reminderTime;

        setModalState(() {
          _isNotificationEnabled = true;
          _reminderTime = pickedTime;
        });
        setState(() {
          _isNotificationEnabled = true;
          _reminderTime = pickedTime;
        });

        try {
          // Step 3: Persistence & Service Init
          await prefs.setBool('use_notifications', true);
          await prefs.setInt('reminder_hour', pickedTime.hour);
          await prefs.setInt('reminder_minute', pickedTime.minute);

          await _notificationService.init();
          await _notificationService.scheduleDailyReminder(
            hour: pickedTime.hour,
            minute: pickedTime.minute,
            showConfirmation: true,
          );
        } catch (e) {
          debugPrint('--- Daily Reminder Fail: $e');
          // Rollback if failure
          setModalState(() {
            _isNotificationEnabled = oldState;
            _reminderTime = oldTime;
          });
          setState(() {
            _isNotificationEnabled = oldState;
            _reminderTime = oldTime;
          });
          if (mounted)
            UIHelper.showErrorSnackBar(context, 'Gagal menjadwalkan: $e');
        }
      }
    } else {
      // Step 2: Optimistic UI Update (Turning OFF)
      setModalState(() => _isNotificationEnabled = false);
      setState(() => _isNotificationEnabled = false);

      try {
        await prefs.setBool('use_notifications', false);
        await _notificationService.cancelAll();
        if (mounted)
          UIHelper.showInfoSnackBar(context, 'Pengingat harian dinonaktifkan.');
      } catch (e) {
        debugPrint('--- Daily Reminder Cancel Fail: $e');
      }
    }
  }

  void _showSurveySheet() {
    if (_isSurveyOpen) return;
    _isSurveyOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExperienceSurveySheet(),
    ).then((_) => _isSurveyOpen = false);
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
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
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
                      color: Theme.of(context).cardColor.withOpacity(0.9),
                      border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.1)),
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
                          child: Icon(CupertinoIcons.flag,
                              color: AppColors.primary, size: 32),
                        ),
                        const SizedBox(height: 20),
                        Text(ToneManager.t('budget_title'),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text(ToneManager.t('budget_subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color)),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2C2C2E)
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800),
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              hintText: '0',
                              hintStyle:
                                  TextStyle(color: Theme.of(context).hintColor),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Theme.of(context).dividerColor),
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
                                  final budget =
                                      double.tryParse(controller.text) ?? 0.0;
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setDouble(
                                      'monthly_budget', budget);
                                  setState(() => _monthlyBudget = budget);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppColors.primary
                                              .withOpacity(0.3),
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
    Color? textColor,
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
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color:
                  textColor ?? Theme.of(context).textTheme.bodyLarge?.color)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.85)
                      : Colors.black.withOpacity(0.6)))
          : null,
      trailing: trailing ??
          Icon(CupertinoIcons.chevron_right,
              size: 16, color: Theme.of(context).iconTheme.color),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? (isMaintenance
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1))
                    : (isMaintenance ? Colors.red[50] : Colors.orange[50]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: (isMaintenance
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.red.withOpacity(0.3)
                            : Colors.red[100])
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.orange[100]))!),
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
                          ? CupertinoIcons.hammer_fill
                          : CupertinoIcons.clock_fill,
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
                                  ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.red[300]
                                      : Colors.red[900])
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.orange[300]
                                      : Colors.orange[900])),
                        ),
                        Text(msg,
                            style: TextStyle(
                                fontSize: 10,
                                color: isMaintenance
                                    ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.red[200]
                                        : Colors.red[700])
                                    : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.orange[200]
                                        : Colors.orange[700]),
                                height: 1.3)),
                        if (!isMaintenance && startTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                'Direncanakan: ${DateFormat('HH:mm, dd MMM').format(startTime)}',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.orange[200]
                                        : Colors.orange[800])),
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.info_circle_fill,
                        color: Colors.blue, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(message,
                              style: TextStyle(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white.withOpacity(0.8)
                                      : Colors.black.withOpacity(0.6),
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _saveDismissedBroadcast(id),
                      icon: Icon(CupertinoIcons.xmark,
                          size: 16, color: Theme.of(context).iconTheme.color),
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
    IconData displayIcon = CupertinoIcons.bell_fill;
    Color displayColor = Colors.blue;

    if (type == 'urgent') {
      displayIcon = CupertinoIcons.exclamationmark_triangle_fill;
      displayColor = Colors.red;
    } else if (type == 'news') {
      displayIcon = CupertinoIcons.sparkles;
      displayColor = Colors.purple;
    } else if (type == 'reminder') {
      displayIcon = CupertinoIcons.alarm_fill;
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1C1C1E).withOpacity(0.9)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                      width: 1.5),
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
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                            decoration: TextDecoration.none,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Center(
                            child: Text(ToneManager.t('understood_button'),
                                style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.black
                                        : Colors.white,
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
