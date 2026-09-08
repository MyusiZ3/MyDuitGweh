import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../widgets/shimmer_loading.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../services/ai_service.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import '../services/notif_listener_bridge.dart';
import '../services/debt_service.dart';
import '../widgets/empty_state_widget.dart';
// import '../models/debt_model.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  DateTimeRange selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  late Stream<List<WalletModel>> _walletStream;
  Stream<List<TransactionModel>>? _txnStream;
  List<String>? _lastWalletIds;
  DateTimeRange? _lastDateRange;

  int _touchedPieIndex = -1;
  bool _isCategoryMode = true;
  bool _showLineChart = false;
  bool _isCheckingAi = false;
  String? _aiApiKey;
  String? _aiApiPlatform; // 'gemini' or 'groq'
  List<String> _allApiKeys = []; // Stores combined "key|platform"
  List<String> _currentWalletIds = [];
  List<WalletModel> _allWallets = []; // Store current wallets for AIcontext

  bool _isNotifAccessGranted = false;
  bool _isNotifBannerDismissed = false;

  // Added for new features
  double _monthlyBudget = 0.0;
  double _prevIncome = 0.0;
  double _prevExpense = 0.0;
  bool _isLoadingPrev = false;
  String _activePreset = '30 Hari';
  List<TransactionModel>? _cachedTransactions;

  Future<void> _checkNotifStatus() async {
    final granted = await NotifListenerBridge.isAccessGranted();
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('notif_banner_dismissed') ?? false;
    final budget = prefs.getDouble('monthly_budget') ?? 0.0;

    if (mounted) {
      setState(() {
        _isNotifAccessGranted = granted;
        _isNotifBannerDismissed = dismissed;
        _monthlyBudget = budget;
      });
      _calculatePreviousPeriodData();
    }
  }

  @override
  void initState() {
    super.initState();
    _walletStream = _firestoreService.getWalletsStream(_uid);
    _loadAIKey();
    _checkNotifStatus();
  }

  Stream<List<TransactionModel>> _getTxnStream(List<String> walletIds) {
    // Cache the stream based on parameters to prevent rebuild flickering
    final walletKey = walletIds.map((id) => id).toList().join(',');
    final lastWalletKey = _lastWalletIds?.join(',');

    if (_txnStream != null &&
        walletKey == lastWalletKey &&
        _lastDateRange == selectedDateRange) {
      return _txnStream!;
    }

    _lastWalletIds = List.from(walletIds);
    _lastDateRange = selectedDateRange;
    _txnStream = _firestoreService.getFilteredTransactionsStream(
      walletIds: walletIds,
      startDate: selectedDateRange.start,
      endDate: selectedDateRange.end,
    );
    _calculatePreviousPeriodData();
    return _txnStream!;
  }

  Future<void> _calculatePreviousPeriodData() async {
    if (_currentWalletIds.isEmpty) return;

    final duration = selectedDateRange.duration;
    final prevStart = selectedDateRange.start.subtract(duration);
    final prevEnd =
        selectedDateRange.start.subtract(const Duration(seconds: 1));

    if (mounted) setState(() => _isLoadingPrev = true);

    try {
      final prevTxns = await _firestoreService.getFilteredTransactions(
        walletIds: _currentWalletIds,
        startDate: prevStart,
        endDate: prevEnd,
      );

      double inc = 0;
      double exp = 0;
      for (var t in prevTxns) {
        if (t.isIncome) {
          inc += t.amount;
        } else if (t.isExpense) {
          exp += t.amount;
        }
      }

      if (mounted) {
        setState(() {
          _prevIncome = inc;
          _prevExpense = exp;
          _isLoadingPrev = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPrev = false);
    }
  }

  void _applyPreset(String preset) {
    setState(() {
      _activePreset = preset;
      final now = DateTime.now();
      switch (preset) {
        case 'Hari Ini':
          selectedDateRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: now,
          );
          break;
        case 'Minggu Ini':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          selectedDateRange = DateTimeRange(
            start:
                DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
            end: now,
          );
          break;
        case 'Bulan Ini':
          selectedDateRange = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
          break;
        case '30 Hari':
          selectedDateRange = DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
          break;
        case 'Tahun Ini':
          selectedDateRange = DateTimeRange(
            start: DateTime(now.year, 1, 1),
            end: now,
          );
          break;
      }
    });
    _calculatePreviousPeriodData();
  }

  Future<void> _loadAIKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _aiApiKey = prefs.getString('user_ai_api_key');
      _aiApiPlatform = prefs.getString('user_ai_api_platform') ?? 'gemini';
      _allApiKeys = prefs.getStringList('user_all_api_keys_v2') ?? [];

      // Robust Migration / Synchronization
      // 1. Check for REALLY old key name
      final oldKeyName = prefs.getString('gemini_api_key');
      if (oldKeyName != null && _aiApiKey == null) {
        _aiApiKey = oldKeyName;
        _aiApiPlatform = 'gemini';
        prefs.setString('user_ai_api_key', oldKeyName);
        prefs.setString('user_ai_api_platform', 'gemini');
        prefs.remove('gemini_api_key');
      }

      // 2. Ensure current key is in the list
      if (_aiApiKey != null && _aiApiKey!.isNotEmpty) {
        final entry = '$_aiApiKey|$_aiApiPlatform';
        if (!_allApiKeys.contains(entry)) {
          _allApiKeys.add(entry);
          prefs.setStringList('user_all_api_keys_v2', _allApiKeys);
        }
      }
    });
  }

  Future<void> _saveAIKey(String key, String platform) async {
    final trimmedKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_ai_api_key', trimmedKey);
    await prefs.setString('user_ai_api_platform', platform);

    if (trimmedKey.isNotEmpty) {
      final entry = '$trimmedKey|$platform';
      if (!_allApiKeys.contains(entry)) {
        if (mounted) {
          setState(() {
            _allApiKeys = [entry, ..._allApiKeys];
          });
        }
        await prefs.setStringList('user_all_api_keys_v2', _allApiKeys);
      }
    }

    if (mounted) {
      setState(() {
        _aiApiKey = trimmedKey;
        _aiApiPlatform = platform;
      });
    }
  }

  Future<void> _deleteStoredKey(String entry) async {
    final prefs = await SharedPreferences.getInstance();
    _allApiKeys.remove(entry);
    await prefs.setStringList('user_all_api_keys_v2', _allApiKeys);

    final parts = entry.split('|');
    final key = parts[0];

    if (_aiApiKey == key) {
      _aiApiKey = null;
      _aiApiPlatform = null;
      await prefs.remove('user_ai_api_key');
      await prefs.remove('user_ai_api_platform');
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _removeAIKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_ai_api_key');
    await prefs.remove('user_ai_api_platform');
    if (mounted) {
      setState(() {
        _aiApiKey = null;
        _aiApiPlatform = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final headerColor = isDark
              ? Colors.black.withOpacity(0.7)
              : Colors.white.withOpacity(0.7);

          return [
            SliverAppBar(
              pinned: true,
              stretch: true,
              centerTitle: false,
              expandedHeight: 140,
              collapsedHeight: 70,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: _showExportDialog,
                    icon: Icon(
                      CupertinoIcons.share,
                      size: 22,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.blurBackground,
                      StretchMode.zoomBackground,
                    ],
                    titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                    centerTitle: false,
                    title: Text(
                      ToneManager.t('report_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: -1.0,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    background: Container(color: headerColor),
                  ),
                ),
              ),
            ),
          ];
        },
        body: StreamBuilder<List<WalletModel>>(
          stream: _walletStream,
          builder: (context, walletSnapshot) {
            if (walletSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: ShimmerTransactionList());
            }

            final wallets = walletSnapshot.data ?? [];
            if (wallets.isEmpty) {
              return _buildNoData(ToneManager.t('wallet_empty_title'),
                  ToneManager.t('wallet_empty_msg'));
            }

            final walletIds = wallets.map((w) => w.id).toList();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _allWallets = wallets;
                final set1 = _currentWalletIds.toSet();
                final set2 = walletIds.toSet();
                if (set1.length != set2.length || !set1.containsAll(set2)) {
                  setState(() => _currentWalletIds = walletIds);
                }
              }
            });

            return StreamBuilder<List<TransactionModel>>(
              stream: _getTxnStream(walletIds),
              builder: (context, txnSnapshot) {
                final transactions = txnSnapshot.data;
                if (transactions != null) {
                  _cachedTransactions = transactions;
                }

                final displayTransactions = transactions ?? _cachedTransactions;
                final isLoading =
                    txnSnapshot.connectionState == ConnectionState.waiting;

                if (isLoading &&
                    (displayTransactions == null ||
                        displayTransactions.isEmpty)) {
                  return const Padding(
                      padding: EdgeInsets.fromLTRB(24, 100, 24, 0),
                      child: ShimmerTransactionList());
                }

                final data = displayTransactions ?? [];
                if (data.isEmpty) {
                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    children: [
                      _buildQuickPresets(),
                      const SizedBox(height: 16),
                      _buildDateFilter(),
                      const SizedBox(height: 40),
                      _buildNoData(ToneManager.t('home_empty_title'),
                          ToneManager.t('home_empty_msg')),
                    ],
                  );
                }

                double totalIncome = 0;
                double totalExpense = 0;
                Map<String, double> categoryTotals = {};

                for (var txn in data) {
                  if (txn.isIncome) {
                    totalIncome += txn.amount;
                  } else if (txn.isExpense) {
                    totalExpense += txn.amount;
                    categoryTotals[txn.category] =
                        (categoryTotals[txn.category] ?? 0) + txn.amount;
                  }
                }

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, top: 20, bottom: 140),
                  children: [
                    _buildQuickPresets(),
                    const SizedBox(height: 16),
                    _buildDateFilter(),
                    const SizedBox(height: 20),
                    _buildSummaryCard(
                        totalIncome - totalExpense, totalIncome, totalExpense),
                    const SizedBox(height: 24),
                    if (_monthlyBudget > 0) ...[
                      _buildBudgetRings(totalExpense),
                      const SizedBox(height: 24),
                    ],
                    _buildInsightToggle(),
                    const SizedBox(height: 24),
                    // Grouped Content Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(isDark ? 0.1 : 0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_isCategoryMode)
                            if (totalExpense > 0)
                              _buildInteractivePieChart(
                                  categoryTotals, totalExpense)
                            else
                              const EmptyStateWidget(
                                title: 'Belum Ada Pengeluaran',
                                subtitle: 'Grafik kategori akan tampil setelah kamu mencatat transaksi pengeluaran.',
                                icon: CupertinoIcons.chart_pie_fill,
                                paddingVertical: 24,
                              )
                          else
                            _buildWeeklyTrendChart(data),
                          if (_isCategoryMode && totalExpense > 0) ...[
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 24),
                            _buildCategoryList(categoryTotals, totalExpense),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildActivityHeatmap(data),
                    const SizedBox(height: 32),
                    if (totalExpense > 0) ...[
                      _buildStackedCategoryTimeline(data),
                      const SizedBox(height: 32),
                    ],
                    _buildNotifSettingsCard(),
                    const SizedBox(height: 20),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
            bottom: 150), // Elevated to stay above bottom nav
        child: FloatingActionButton.extended(
          onPressed: () async {
            if (_isCheckingAi) return;

            setState(() {
              _isCheckingAi = true;
            });

            // Check if AI is globally enabled
            final isEnabled = await AIService.isGlobalAiEnabled();

            if (!context.mounted) return;
            setState(() {
              _isCheckingAi = false;
            });

            if (isEnabled) {
              if (context.mounted) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => _AIAdvisorSheet(
                    apiKey: _aiApiKey,
                    apiPlatform: _aiApiPlatform,
                    allApiKeys: _allApiKeys,
                    onSaveKey: _saveAIKey,
                    onDeleteKey: _deleteStoredKey,
                    onRemoveKey: _removeAIKey,
                    selectedDateRange: selectedDateRange,
                    uid: _uid,
                    firestoreService: _firestoreService,
                    walletIds: _currentWalletIds,
                    wallets: _allWallets,
                  ),
                );
              }
            } else {
              if (context.mounted) {
                UIHelper.showAiMaintenanceDialog(context);
              }
            }
          },
          label: _isCheckingAi
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(ToneManager.t('arch_ai_button'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
          icon: _isCheckingAi
              ? const SizedBox.shrink()
              : Icon(CupertinoIcons.sparkles, color: Colors.white),
          backgroundColor: isDark
              ? CupertinoColors.activeBlue
              : Theme.of(context).primaryColor,
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: _selectDateRange,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color:
                Theme.of(context).dividerColor.withOpacity(isDark ? 0.05 : 0.1),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isDark ? Colors.blueAccent : AppColors.primary)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.calendar,
                color: isDark ? Colors.blueAccent : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Periode Laporan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).hintColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd MMM').format(selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange.end)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                color: Theme.of(context).hintColor.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(
                    primary: CupertinoColors.activeBlue,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1C1C1E),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        selectedDateRange = range;
        _activePreset = 'Custom';
      });
      _calculatePreviousPeriodData();
    }
  }

  Widget _buildBudgetRings(double currentExpense) {
    if (_monthlyBudget == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (currentExpense / _monthlyBudget).clamp(0.0, 1.0);
    final isOverBudget = currentExpense > _monthlyBudget;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.05), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 10,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget
                        ? const Color(0xFFFF453A) // iOS Red
                        : (percent > 0.8
                            ? const Color(0xFFFF9F0A)
                            : (isDark
                                ? CupertinoColors.activeBlue
                                : AppColors.primary)),
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${(percent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anggaran Bulanan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${CurrencyFormatter.formatCurrency(currentExpense)} / ${CurrencyFormatter.formatCurrency(_monthlyBudget)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOverBudget
                      ? 'Wah, kamu sudah melebihi anggaran!'
                      : 'Sisa: ${CurrencyFormatter.formatCurrency(_monthlyBudget - currentExpense)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isOverBudget
                        ? const Color(0xFFFF453A)
                        : (isDark ? Colors.white38 : Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedCategoryTimeline(List<TransactionModel> transactions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expenseTransactions =
        transactions.where((t) => t.isExpense).toList();

    if (expenseTransactions.isEmpty) return const SizedBox.shrink();

    // Group by date
    Map<String, Map<String, double>> dailyData = {};
    List<String> categories = [];

    for (var t in expenseTransactions) {
      final dateKey =
          "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}";
      if (!dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = {};
      }
      dailyData[dateKey]![t.category] =
          (dailyData[dateKey]![t.category] ?? 0) + t.amount;

      if (!categories.contains(t.category)) {
        categories.add(t.category);
      }
    }

    // Sort dates
    final sortedDates = dailyData.keys.toList()..sort();
    final colors = _getChartColors(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Timeline Pengeluaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),
            Icon(CupertinoIcons.layers_alt_fill,
                size: 16, color: isDark ? Colors.white38 : Colors.black26),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Distribusi kategori per hari',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black45,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          height: 250,
          padding: const EdgeInsets.only(right: 16, top: 16),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: dailyData.values.isEmpty ? 100 : dailyData.values
                      .map((e) =>
                          e.values.fold(0.0, (prev, curr) => prev + curr))
                      .reduce((a, b) => a > b ? a : b) *
                  1.1,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final date = sortedDates[groupIndex];
                    final total = rod.toY;
                    return BarTooltipItem(
                      '$date\n',
                      TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: CurrencyFormatter.formatCurrency(total),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 &&
                          value.toInt() < sortedDates.length) {
                        final dateStr = sortedDates[value.toInt()];
                        final day = dateStr.split('-').last;
                        // Only show labels occasionally to avoid crowding
                        bool showLabel = true;
                        if (sortedDates.length > 7) {
                          showLabel = value.toInt() % (sortedDates.length ~/ 4 + 1) == 0;
                        }
                        
                        if (!showLabel) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            day,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    reservedSize: 24,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        CurrencyFormatter.formatCompact(value),
                        style: TextStyle(
                          color: isDark ? Colors.white24 : Colors.black26,
                          fontSize: 9,
                        ),
                      );
                    },
                    reservedSize: 32,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: sortedDates.asMap().entries.map((entry) {
                final index = entry.key;
                final dateKey = entry.value;
                final catAmounts = dailyData[dateKey]!;

                double currentY = 0;
                List<BarChartRodStackItem> stackItems = [];
                
                // We need to maintain category order for consistency
                for (int i = 0; i < categories.length; i++) {
                  final cat = categories[i];
                  final amount = catAmounts[cat] ?? 0;
                  if (amount > 0) {
                    stackItems.add(BarChartRodStackItem(
                      currentY,
                      currentY + amount,
                      colors[i % colors.length],
                    ));
                    currentY += amount;
                  }
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: currentY,
                      width: sortedDates.length > 10 ? 8 : 16,
                      borderRadius: BorderRadius.circular(4),
                      rodStackItems: stackItems,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: categories.asMap().entries.map((e) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[e.key % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActivityHeatmap(List<TransactionModel> transactions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<DateTime, int> dailyCounts = {};
    for (var tx in transactions) {
      final dateOnly = DateTime(tx.date.year, tx.date.month, tx.date.day);
      dailyCounts[dateOnly] = (dailyCounts[dateOnly] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.05), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AKTIVITAS TRANSAKSI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white30 : Colors.black38,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '4 Minggu Terakhir',
                style:
                    TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(28, (index) {
                final date = today.subtract(Duration(days: 27 - index));
                final count = dailyCounts[date] ?? 0;

                Color cellColor;
                if (count == 0) {
                  cellColor = isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03);
                } else if (count <= 2) {
                  cellColor =
                      (isDark ? CupertinoColors.activeBlue : AppColors.primary)
                          .withOpacity(0.3);
                } else if (count <= 5) {
                  cellColor =
                      (isDark ? CupertinoColors.activeBlue : AppColors.primary)
                          .withOpacity(0.6);
                } else {
                  cellColor =
                      isDark ? CupertinoColors.activeBlue : AppColors.primary;
                }

                return Container(
                  width: 8,
                  height: 20,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresets() {
    final presets = [
      'Hari Ini',
      'Minggu Ini',
      'Bulan Ini',
      '30 Hari',
      'Tahun Ini'
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: presets.map((preset) {
          final isSelected = _activePreset == preset;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(preset),
              selected: isSelected,
              onSelected: (bool selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  _applyPreset(preset);
                }
              },
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selectedColor:
                  isDark ? CupertinoColors.activeBlue : AppColors.primary,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              elevation: 0,
              pressElevation: 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotifSettingsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? CupertinoColors.activeBlue : AppColors.primary;

    return StreamBuilder<bool>(
      stream: NotifListenerBridge.globalConfigStream,
      builder: (context, snapshot) {
        final globalEnabled = snapshot.data ?? false;

        if (!globalEnabled) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color:
                isDark ? const Color(0xFF1C1C1E) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: isDark
                ? Border.all(color: Colors.white.withOpacity(0.05), width: 1)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      CupertinoIcons.sparkles,
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Magic Sync',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(isDark ? 0.25 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                    accentColor.withOpacity(isDark ? 0.4 : 0.2),
                                width: 0.8),
                          ),
                          child: Text(
                            'EXPERIMENTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 8,
                              color: isDark
                                  ? accentColor.withOpacity(0.9)
                                  : accentColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pencatatan otomatis dari notifikasi keuangan',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : AppColors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isNotifAccessGranted
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.info_circle_fill,
                      color: _isNotifAccessGranted
                          ? (isDark
                              ? CupertinoColors.systemGreen
                              : Colors.green)
                          : (isDark
                              ? CupertinoColors.systemOrange
                              : Colors.orange),
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _isNotifAccessGranted
                            ? 'Izin Akses Aktif'
                            : 'Izin Akses Belum Diberikan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _isNotifAccessGranted
                              ? (isDark
                                  ? Colors.greenAccent
                                  : Colors.green[800])
                              : (isDark
                                  ? Colors.orangeAccent
                                  : Colors.orange[900]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await NotifListenerBridge.openSettings();
                        // Re-check after returning from settings
                        Future.delayed(
                            const Duration(seconds: 2), _checkNotifStatus);
                      },
                      icon: const Icon(CupertinoIcons.settings,
                          color: Colors.white, size: 20),
                      label: const Text('Buka Pengaturan Perizinan',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isNotifBannerDismissed && !_isNotifAccessGranted) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('notif_banner_dismissed');
                    _checkNotifStatus();
                    if (context.mounted) {
                      UIHelper.showSuccessSnackBar(context,
                          'Banner perizinan di-reset! Silakan kembali ke Home.');
                    }
                  },
                  child: Center(
                    child: Text(
                      'Tampilkan kembali banner di Home',
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        color: isDark
                            ? Colors.white38
                            : Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(double balance, double income, double expense) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)]
              : [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppColors.primary).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RINGKASAN BERSIH',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(
                CupertinoIcons.info_circle,
                size: 16,
                color: isDark ? Colors.white24 : Colors.white38,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.formatCurrency(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Pemasukan',
                  income,
                  CupertinoIcons.arrow_down_circle_fill,
                  isDark ? Colors.greenAccent : Colors.white.withOpacity(0.9),
                ),
              ),
              Container(
                height: 30,
                width: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              Expanded(
                child: _buildStatItem(
                  'Pengeluaran',
                  expense,
                  CupertinoIcons.arrow_up_circle_fill,
                  isDark ? Colors.redAccent : Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          if (!_isLoadingPrev) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildComparisonRow(income, _prevIncome, 'Pemasukan',
                      isInverse: false),
                  const SizedBox(height: 12),
                  _buildComparisonRow(expense, _prevExpense, 'Pengeluaran',
                      isInverse: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildComparisonRow(double current, double previous, String label,
      {bool isInverse = false}) {
    if (previous == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final difference = current - previous;
    final percentChange = ((difference / previous) * 100).abs();

    // For expenses (isInverse: true), lower is better. For income, higher is better.
    final isImprovement = isInverse ? difference < 0 : difference > 0;
    final trendColor = isImprovement ? Colors.greenAccent : Colors.orangeAccent;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'vs Periode Sebelumnya',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 9,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: trendColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: trendColor.withOpacity(0.2), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                difference == 0
                    ? CupertinoIcons.minus
                    : (difference > 0
                        ? CupertinoIcons.arrow_up_right
                        : CupertinoIcons.arrow_down_right),
                size: 10,
                color: trendColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${percentChange.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: trendColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildStatItem(
      String label, double amount, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.withOpacity(0.7)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.formatCurrency(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<bool>(
        groupValue: _isCategoryMode,
        backgroundColor:
            isDark ? const Color(0xFF1C1C1E) : Colors.black.withOpacity(0.05),
        thumbColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
        padding: const EdgeInsets.all(4),
        children: {
          true: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Kategori',
              style: TextStyle(
                fontSize: 13,
                fontWeight: _isCategoryMode ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          false: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Tren Mingguan',
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    !_isCategoryMode ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        },
        onValueChanged: (value) {
          if (value != null) {
            HapticFeedback.selectionClick();
            setState(() => _isCategoryMode = value);
          }
        },
      ),
    );
  }

  List<Color> _getChartColors(bool isDark) {
    return isDark
        ? [
            const Color(0xFF0A84FF), // iOS System Blue (Dark)
            const Color(0xFF30D158), // iOS System Green (Dark)
            const Color(0xFF5E5CE6), // iOS System Indigo (Dark)
            const Color(0xFFFF9F0A), // iOS System Orange (Dark)
            const Color(0xFFFF375F), // iOS System Pink (Dark)
            const Color(0xFFBF5AF2), // iOS System Purple (Dark)
            const Color(0xFF64D2FF), // iOS System Teal (Dark)
            const Color(0xFFAC8E68), // iOS System Brown (Dark)
            const Color(0xFF8E8E93), // iOS System Gray (Dark)
          ]
        : [
            const Color(0xFF007AFF), // iOS System Blue (Light)
            const Color(0xFF34C759), // iOS System Green (Light)
            const Color(0xFF5856D6), // iOS System Indigo (Light)
            const Color(0xFFFF9500), // iOS System Orange (Light)
            const Color(0xFFFF2D55), // iOS System Pink (Light)
            const Color(0xFFAF52DE), // iOS System Purple (Light)
            const Color(0xFF5AC8FA), // iOS System Teal (Light)
            const Color(0xFFA2845E), // iOS System Brown (Light)
            const Color(0xFF8E8E93), // iOS System Gray (Light)
          ];
  }

  Widget _buildInteractivePieChart(
      Map<String, double> categoryTotals, double total) {
    return StatefulBuilder(
      builder: (context, setChartState) {
        List<PieChartSectionData> sections = [];
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final colors = _getChartColors(isDark);
        int i = 0;

        categoryTotals.forEach((cat, amount) {
          final isTouched = i == _touchedPieIndex;
          final radius = isTouched ? 65.0 : 55.0;
          final fontSize = isTouched ? 16.0 : 12.0;

          sections.add(PieChartSectionData(
            color: colors[i % colors.length],
            value: amount,
            title: isTouched
                ? cat
                : '${((amount / total) * 100).toStringAsFixed(0)}%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
            ),
          ));
          i++;
        });

        return SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setChartState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedPieIndex = -1;
                        return;
                      }
                      _touchedPieIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: sections,
                centerSpaceRadius: 60,
                sectionsSpace: 3,
                startDegreeOffset: 270,
              )),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatCurrency(total),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildWeeklyTrendChart(List<TransactionModel> transactions) {
    // Group by day for the last 7 days
    Map<String, double> incomeByDay = {};
    Map<String, double> expenseByDay = {};

    final now = DateTime.now();
    final days =
        List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));

    for (var day in days) {
      final key = DateFormat('dd/MM').format(day);
      incomeByDay[key] = 0;
      expenseByDay[key] = 0;
    }

    for (var txn in transactions) {
      final dayKey = DateFormat('dd/MM').format(txn.date);
      if (incomeByDay.containsKey(dayKey)) {
        if (txn.isIncome) {
          incomeByDay[dayKey] = (incomeByDay[dayKey] ?? 0) + txn.amount;
        } else if (txn.isExpense) {
          expenseByDay[dayKey] = (expenseByDay[dayKey] ?? 0) + txn.amount;
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _showLineChart = !_showLineChart),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showLineChart
                          ? CupertinoIcons.graph_square_fill
                          : CupertinoIcons.chart_bar_fill,
                      size: 14,
                      color: isDark
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showLineChart ? 'Tampilan Garis' : 'Tampilan Batang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _showLineChart
            ? _buildLineChart(incomeByDay, expenseByDay)
            : _buildBarChart(incomeByDay, expenseByDay),
      ],
    );
  }

  Widget _buildBarChart(
      Map<String, double> incomeByDay, Map<String, double> expenseByDay) {
    List<BarChartGroupData> groups = [];
    int i = 0;
    incomeByDay.forEach((day, income) {
      final expense = expenseByDay[day] ?? 0;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: income,
            color: AppColors.income,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: expense,
            color: AppColors.expense,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ));
      i++;
    });

    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 20, right: 10, left: 10),
      child: BarChart(BarChartData(
        barGroups: groups,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = incomeByDay.keys.elementAt(value.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(day,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.7))),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final type = rodIndex == 0 ? 'Pemasukan' : 'Pengeluaran';
              return BarTooltipItem(
                '$type\n${CurrencyFormatter.formatCurrency(rod.toY)}',
                const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
      )),
    );
  }

  Widget _buildLineChart(
      Map<String, double> incomeByDay, Map<String, double> expenseByDay) {
    List<FlSpot> incomeSpots = [];
    List<FlSpot> expenseSpots = [];

    int i = 0;
    incomeByDay.forEach((day, value) {
      incomeSpots.add(FlSpot(i.toDouble(), value));
      i++;
    });

    i = 0;
    expenseByDay.forEach((day, value) {
      expenseSpots.add(FlSpot(i.toDouble(), value));
      i++;
    });

    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 20, right: 20, left: 10),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1000000,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= incomeByDay.length)
                    return const SizedBox.shrink();
                  final day = incomeByDay.keys.elementAt(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(day,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.7))),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: incomeSpots,
              isCurved: true,
              color: AppColors.income,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.income.withOpacity(0.1),
              ),
            ),
            LineChartBarData(
              spots: expenseSpots,
              isCurved: true,
              color: AppColors.expense,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.expense.withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final type = spot.barIndex == 0 ? 'Pemasukan' : 'Pengeluaran';
                  return LineTooltipItem(
                    '$type\n${CurrencyFormatter.formatCurrency(spot.y)}',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(Map<String, double> categoryTotals, double total) {
    final categoryEntries = categoryTotals.entries.toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? [
            const Color(0xFF0A84FF), // iOS System Blue (Dark)
            const Color(0xFF30D158), // iOS System Green (Dark)
            const Color(0xFF5E5CE6), // iOS System Indigo (Dark)
            const Color(0xFFFF9F0A), // iOS System Orange (Dark)
            const Color(0xFFFF375F), // iOS System Pink (Dark)
            const Color(0xFFBF5AF2), // iOS System Purple (Dark)
            const Color(0xFF64D2FF), // iOS System Teal (Dark)
          ]
        : [
            const Color(0xFF007AFF), // iOS System Blue (Light)
            const Color(0xFF34C759), // iOS System Green (Light)
            const Color(0xFF5856D6), // iOS System Indigo (Light)
            const Color(0xFFFF9500), // iOS System Orange (Light)
            const Color(0xFFFF2D55), // iOS System Pink (Light)
            const Color(0xFFAF52DE), // iOS System Purple (Light)
            const Color(0xFF5AC8FA), // iOS System Teal (Light)
          ];

    return Column(
      children: List.generate(categoryEntries.length, (i) {
        final e = categoryEntries[i];
        final percentage = (e.value / total);
        final color = colors[i % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Icon(TransactionCategory.getIconForCategory(e.key),
                    color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Theme.of(context).scaffoldBackgroundColor,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(CurrencyFormatter.formatCurrency(e.value),
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoData(String title, String subtitle) {
    return EmptyStateWidget(
      title: title,
      subtitle: subtitle,
      icon: CupertinoIcons.chart_pie_fill,
      paddingVertical: 40,
    );
  }

  void _showExportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final wallets = await _firestoreService.getWalletsStream(_uid).first;
      final walletIds = wallets.map((w) => w.id).toList();
      final txns = await _firestoreService
          .getFilteredTransactionsStream(
              walletIds: walletIds,
              startDate: selectedDateRange.start,
              endDate: selectedDateRange.end)
          .first;

      if (!mounted) return;
      Navigator.of(context).pop(); // Tutup loading

      if (txns.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Tidak ada data transaksi di periode ini untuk diekspor.')));
        return;
      }

      final availableCategories = txns.map((t) => t.category).toSet().toList();
      availableCategories.sort();
      List<String> selectedCategories = List.from(availableCategories);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final accentColor =
              isDark ? CupertinoColors.activeBlue : AppColors.primary;

          return Container(
            decoration: BoxDecoration(
              color: isDark
                  ? CupertinoColors.systemBackground.resolveFrom(context)
                  : CupertinoColors.secondarySystemBackground
                      .resolveFrom(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Kategori',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Text(
                          selectedCategories.length ==
                                  availableCategories.length
                              ? 'Bersihkan'
                              : 'Pilih Semua',
                          style: TextStyle(
                            fontSize: 16,
                            color: accentColor,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setSheetState(() {
                            if (selectedCategories.length ==
                                availableCategories.length) {
                              selectedCategories.clear();
                            } else {
                              selectedCategories =
                                  List.from(availableCategories);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Category List
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: CupertinoListSection.insetGrouped(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      backgroundColor: Colors.transparent,
                      children: availableCategories.map((cat) {
                        final isSelected = selectedCategories.contains(cat);
                        return CupertinoListTile.notched(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setSheetState(() {
                              if (isSelected) {
                                selectedCategories.remove(cat);
                              } else {
                                selectedCategories.add(cat);
                              }
                            });
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withOpacity(0.1)
                                  : (isDark
                                      ? Colors.white10
                                      : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              TransactionCategory.getIconForCategory(cat),
                              size: 20,
                              color: isSelected
                                  ? accentColor
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                          ),
                          title: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 17,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  CupertinoIcons.checkmark_alt,
                                  color: accentColor,
                                  size: 24,
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Export Buttons
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildExportButton(
                          label: 'PDF',
                          icon: CupertinoIcons.doc_text_fill,
                          color: isDark
                              ? CupertinoColors.systemRed.darkColor
                              : CupertinoColors.systemRed,
                          onPressed: selectedCategories.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  _processExport(
                                      ctx, txns, selectedCategories, true);
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExportButton(
                          label: 'CSV',
                          icon: CupertinoIcons.table,
                          color: isDark
                              ? CupertinoColors.systemGreen.darkColor
                              : CupertinoColors.systemGreen,
                          onPressed: selectedCategories.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  _processExport(
                                      ctx, txns, selectedCategories, false);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyiapkan data: $e')));
    }
  }

  Widget _buildExportButton(
      {required String label,
      required IconData icon,
      required Color color,
      VoidCallback? onPressed}) {
    final isEnabled = onPressed != null;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isEnabled ? color : color.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (isEnabled)
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processExport(BuildContext ctx, List<TransactionModel> allTxns,
      List<String> selectedCategories, bool isPdf) {
    Navigator.pop(ctx);

    final filteredTxns =
        allTxns.where((t) => selectedCategories.contains(t.category)).toList();

    double totalIncome = 0;
    double totalExpense = 0;
    for (var txn in filteredTxns) {
      if (txn.isIncome) {
        totalIncome += txn.amount;
      } else if (txn.isExpense) {
        totalExpense += txn.amount;
      }
    }

    if (isPdf) {
      PdfService.generateAndPrintReport(
        transactions: filteredTxns,
        startDate: selectedDateRange.start,
        endDate: selectedDateRange.end,
        selectedCategories: selectedCategories,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
      );
    } else {
      PdfService.generateAndExportCSV(
        transactions: filteredTxns,
        startDate: selectedDateRange.start,
        endDate: selectedDateRange.end,
      );
    }
  }
}

class _AIAdvisorSheet extends StatefulWidget {
  final String? apiKey;
  final String? apiPlatform;
  final List<String> allApiKeys;
  final Function(String, String) onSaveKey;
  final Function(String) onDeleteKey;
  final VoidCallback onRemoveKey;
  final DateTimeRange selectedDateRange;
  final String uid;
  final FirestoreService firestoreService;
  final List<String> walletIds;
  final List<WalletModel> wallets;

  const _AIAdvisorSheet({
    this.apiKey,
    this.apiPlatform,
    required this.allApiKeys,
    required this.onSaveKey,
    required this.onDeleteKey,
    required this.onRemoveKey,
    required this.selectedDateRange,
    required this.uid,
    required this.firestoreService,
    required this.walletIds,
    required this.wallets,
  });

  @override
  State<_AIAdvisorSheet> createState() => _AIAdvisorSheetState();
}

class _AIAdvisorSheetState extends State<_AIAdvisorSheet> {
  final TextEditingController _queryController = TextEditingController();
  final AIService _aiService = AIService();
  bool _isLoading = false;
  String? _localApiKey;
  String? _localApiPlatform;
  String? _currentSessionId;
  List<String> _localAllApiKeys = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _allSessions = []; // List of session metadata
  final ScrollController _scrollController = ScrollController();
  final _uuid = const Uuid();
  final Map<String, String?> _apiStatus =
      {}; // key -> status ('ok', 'limit', 'error')
  int _aiCount = 0;
  int _aiLimit = 10;
  String? _nextReset;

  @override
  void initState() {
    super.initState();
    _localApiKey = widget.apiKey;
    _localApiPlatform = widget.apiPlatform;
    _localAllApiKeys = List.from(widget.allApiKeys);
    _loadSessionsList();

    // Pre-fetch integrated keys from Firestore
    AIService.getIntegratedApiKeysAsync().then((_) {
      AIService.getGroqApiKeysAsync().then((_) {
        if (mounted) setState(() {});
      });
    });
    _refreshQuota();
  }

  Widget _buildPlatformToggle({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.indigoAccent
                  : Theme.of(context).primaryColor)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                    ? Colors.indigoAccent
                    : Theme.of(context).primaryColor)
                : Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Theme.of(context).hintColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshQuota() async {
    final status = await AIService.getUserQuotaStatus();
    if (mounted) {
      setState(() {
        _aiCount = status['count'] ?? 0;
        _aiLimit = status['limit'] ?? 10;
        _nextReset = status['nextReset'];
      });
    }
  }

  @override
  void didUpdateWidget(_AIAdvisorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apiKey != oldWidget.apiKey) {
      setState(() {
        _localApiKey = widget.apiKey;
        _localApiPlatform = widget.apiPlatform;
      });
    }
    if (widget.allApiKeys != oldWidget.allApiKeys) {
      setState(() => _localAllApiKeys = List.from(widget.allApiKeys));
    }
  }

  Future<void> _loadSessionsList() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('ai_chat_sessions');
    if (data != null) {
      setState(() {
        _allSessions = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  Future<void> _saveSessionsList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_chat_sessions', jsonEncode(_allSessions));
  }

  Future<void> _loadSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('ai_chat_history_$sessionId');
    if (data != null) {
      setState(() {
        _currentSessionId = sessionId;
        _messages = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSessionId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'ai_chat_history_$_currentSessionId', jsonEncode(_messages));

    final sessionIndex =
        _allSessions.indexWhere((s) => s['id'] == _currentSessionId);
    final firstUserMsg = _messages.firstWhere((m) => !m['isAI'],
        orElse: () => {'text': 'Chat Baru'})['text'];
    final sessionMeta = {
      'id': _currentSessionId,
      'title': firstUserMsg.toString().length > 30
          ? '${firstUserMsg.toString().substring(0, 30)}...'
          : firstUserMsg,
      'lastUpdate': DateTime.now().toIso8601String(),
    };

    setState(() {
      if (sessionIndex >= 0) {
        _allSessions[sessionIndex] = sessionMeta;
      } else {
        _allSessions.insert(0, sessionMeta);
      }
    });
    _saveSessionsList();
  }

  void _createNewChat() {
    setState(() {
      _currentSessionId = _uuid.v4();
      _messages = [];
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_chat_history_$sessionId');
    setState(() {
      _allSessions.removeWhere((s) => s['id'] == sessionId);
      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
        _messages = [];
      }
    });
    _saveSessionsList();
  }

  void _showManageAPIDialog() {
    final controller = TextEditingController();
    bool isCheckingKey = false;
    String selectedPlatform = 'gemini';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.only(bottom: bottomInset),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              top: false,
              bottom: true,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(CupertinoIcons.lock_fill,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.indigoAccent
                                      : Theme.of(context).primaryColor),
                              const SizedBox(width: 12),
                              Text(ToneManager.t('dialog_api_title'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: -0.5)),
                              const Spacer(),
                              IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(CupertinoIcons.xmark,
                                      size: 20,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPlatformToggle(
                                  label: 'Gemini',
                                  isSelected: selectedPlatform == 'gemini',
                                  icon: CupertinoIcons.sparkles,
                                  onTap: () => setDialogState(
                                      () => selectedPlatform = 'gemini'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPlatformToggle(
                                  label: 'Groq',
                                  isSelected: selectedPlatform == 'groq',
                                  icon: CupertinoIcons.bolt_fill,
                                  onTap: () => setDialogState(
                                      () => selectedPlatform = 'groq'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(ToneManager.t('dialog_api_add'),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).hintColor)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            style: TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Masukkan API Key...',
                              hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .hintColor
                                      .withOpacity(0.5)),
                              filled: true,
                              fillColor: (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.surfaceVariantDark
                                      : AppColors.surfaceVariant)
                                  .withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: Icon(CupertinoIcons.lock,
                                  size: 20, color: Theme.of(context).hintColor),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final clipboardData =
                                        await Clipboard.getData(
                                            Clipboard.kTextPlain);
                                    if (clipboardData != null &&
                                        clipboardData.text != null) {
                                      controller.text = clipboardData.text!;
                                    }
                                  },
                                  icon: Icon(CupertinoIcons.doc_on_clipboard,
                                      size: 16,
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.indigoAccent
                                          : Theme.of(context).primaryColor),
                                  label: Text('Paste',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.indigoAccent
                                              : Theme.of(context)
                                                  .primaryColor)),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: (Theme.of(context)
                                                    .brightness ==
                                                Brightness.dark
                                            ? Colors.indigoAccent
                                            : Theme.of(context).primaryColor)
                                        .withOpacity(0.12),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color:
                                              (Theme.of(context).brightness ==
                                                          Brightness.dark
                                                      ? Colors.indigoAccent
                                                      : Theme.of(context)
                                                          .primaryColor)
                                                  .withOpacity(0.3),
                                          width: 1.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? [
                                              Colors.indigoAccent,
                                              Color(0xFF9333EA)
                                            ]
                                          : [
                                              Theme.of(context).primaryColor,
                                              Color(0xFF8B5CF6)
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: isCheckingKey
                                        ? null
                                        : () async {
                                            final textKey =
                                                controller.text.trim();
                                            if (textKey.isNotEmpty) {
                                              setDialogState(
                                                  () => isCheckingKey = true);

                                              final isValid = await _aiService
                                                  .checkPlatformQuota(textKey,
                                                      selectedPlatform);

                                              if (!context.mounted) return;

                                              if (isValid) {
                                                await widget.onSaveKey(
                                                    textKey, selectedPlatform);
                                                setDialogState(() {
                                                  _localApiKey = textKey;
                                                  _localApiPlatform =
                                                      selectedPlatform;
                                                  final newEntry =
                                                      '$textKey|$selectedPlatform';
                                                  if (!_localAllApiKeys
                                                      .contains(newEntry)) {
                                                    _localAllApiKeys.insert(
                                                        0, newEntry);
                                                  }
                                                  _apiStatus[textKey] = 'ok';
                                                  controller.clear();
                                                  isCheckingKey = false;
                                                });
                                                setState(() {
                                                  _localApiKey = _localApiKey;
                                                });
                                                if (context.mounted) {
                                                  UIHelper.showSuccessSnackBar(
                                                      context,
                                                      ToneManager.t(
                                                          'snack_api_saved'));
                                                }
                                              } else {
                                                setDialogState(() =>
                                                    isCheckingKey = false);
                                                if (context.mounted) {
                                                  UIHelper.showErrorSnackBar(
                                                      context,
                                                      "API Key $selectedPlatform tidak valid atau limit! Silakan gunakan key lain.");
                                                }
                                              }
                                            }
                                          },
                                    icon: isCheckingKey
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : Icon(CupertinoIcons.plus_circle,
                                            size: 18, color: Colors.white),
                                    label: Text(
                                        isCheckingKey
                                            ? 'Mengecek...'
                                            : 'Add API',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('KUNCI BAWAAN (Shared)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).hintColor,
                                      letterSpacing: 1.5)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Consolidated Shared/Integrated Keys
                          StatefulBuilder(builder: (context, innerSetState) {
                            final keysCount =
                                _aiService.getIntegratedKeys().length;
                            final isActive =
                                _localApiKey == null || _localApiKey!.isEmpty;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.indigoAccent
                                            : Theme.of(context).primaryColor)
                                        .withOpacity(0.12)
                                    : (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? AppColors.surfaceVariantDark
                                            : AppColors.surfaceVariant)
                                        .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: isActive
                                        ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.indigoAccent
                                            : Theme.of(context).primaryColor)
                                        : Colors.transparent,
                                    width: 1.5),
                              ),
                              child: InkWell(
                                onTap: () {
                                  widget.onRemoveKey(); // Set null in prefs
                                  setDialogState(() {
                                    _localApiKey = "";
                                    _localApiPlatform = null;
                                  });
                                  setState(() {
                                    _localApiKey = "";
                                    _localApiPlatform = null;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                        isActive
                                            ? CupertinoIcons.circle_fill
                                            : CupertinoIcons.circle,
                                        size: 16,
                                        color: isActive
                                            ? (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.indigoAccent
                                                : Theme.of(context)
                                                    .primaryColor)
                                            : (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white30
                                                : Colors.grey)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                          'Integrated Keys ($keysCount keys)',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.color ??
                                                  Colors.black87)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (_localAllApiKeys.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text('SAVED KEYS',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).hintColor,
                                    letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight:
                                      MediaQuery.of(context).size.height * 0.4),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: _localAllApiKeys.map((entry) {
                                    final parts = entry.split('|');
                                    final key = parts[0];
                                    final platform =
                                        parts.length > 1 ? parts[1] : 'gemini';
                                    final isActive = _localApiKey == key;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.indigoAccent
                                                    .withOpacity(0.15)
                                                : Theme.of(context)
                                                    .primaryColor
                                                    .withOpacity(0.08))
                                            : (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppColors.surfaceVariantDark
                                                    .withOpacity(0.3)
                                                : Theme.of(context).cardColor),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: isActive
                                                ? (Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.indigoAccent
                                                    : Theme.of(context)
                                                        .primaryColor)
                                                : (Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? Colors.white10
                                                    : AppColors.surfaceVariant),
                                            width: 1.5),
                                        boxShadow: isActive
                                            ? [
                                                BoxShadow(
                                                    color: (Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors
                                                                .indigoAccent
                                                            : Theme.of(context)
                                                                .primaryColor)
                                                        .withOpacity(0.1),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4))
                                              ]
                                            : [],
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          widget.onSaveKey(key, platform);
                                          setDialogState(() {
                                            _localApiKey = key;
                                            _localApiPlatform = platform;
                                          });
                                          setState(() {
                                            _localApiKey = key;
                                            _localApiPlatform = platform;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : (Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? AppColors
                                                                .surfaceVariantDark
                                                            : AppColors
                                                                .surfaceVariant)
                                                        .withOpacity(0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isActive
                                                    ? CupertinoIcons.check_mark
                                                    : (platform == 'groq'
                                                        ? CupertinoIcons
                                                            .bolt_fill
                                                        : CupertinoIcons
                                                            .sparkles),
                                                size: 14,
                                                color: isActive
                                                    ? Colors.white
                                                    : (Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.white54
                                                        : Theme.of(context)
                                                            .hintColor),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${key.substring(0, 8)}...${key.substring(key.length - 4)}',
                                                    style: TextStyle(
                                                        fontWeight: isActive
                                                            ? FontWeight.w900
                                                            : FontWeight.w600,
                                                        fontSize: 13,
                                                        color: isActive
                                                            ? (Theme.of(context)
                                                                        .brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? Colors.white
                                                                : Theme.of(
                                                                        context)
                                                                    .primaryColor)
                                                            : (Theme.of(context)
                                                                        .brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? Colors.white70
                                                                : AppColors
                                                                    .textPrimary)),
                                                  ),
                                                  if (isActive)
                                                    Text(
                                                        ToneManager.t(
                                                            'dialog_api_active'),
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Theme.of(context)
                                                                        .brightness ==
                                                                    Brightness
                                                                        .dark
                                                                ? Colors
                                                                    .indigoAccent
                                                                : AppColors
                                                                    .primary,
                                                            letterSpacing:
                                                                0.5)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: Icon(
                                                  CupertinoIcons.trash_fill,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.white38
                                                      : Colors.grey),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () async {
                                                final confirm = await UIHelper
                                                    .showConfirmDialog(
                                                  context: context,
                                                  title: 'Hapus API Key?',
                                                  message:
                                                      'Apakah kamu yakin ingin menghapus API Key ini?',
                                                  confirmText: 'Ya, Hapus',
                                                );
                                                if (confirm != true) return;

                                                await widget.onDeleteKey(key);
                                                setDialogState(() {
                                                  if (_localApiKey == key) {
                                                    _localApiKey = null;
                                                  }
                                                  _apiStatus.remove(key);
                                                  _localAllApiKeys.removeWhere(
                                                      (item) =>
                                                          item
                                                              .split('|')
                                                              .first ==
                                                          key);
                                                });
                                                setState(() {
                                                  if (_localApiKey == key) {
                                                    _localApiKey = null;
                                                  }
                                                });
                                                if (context.mounted) {
                                                  UIHelper.showErrorSnackBar(
                                                      context,
                                                      ToneManager.t(
                                                          'snack_api_deleted'));
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pop(context); // Close dialog first
                                _showAPITutorial();
                              },
                              icon: Icon(CupertinoIcons.question_circle,
                                  size: 14, color: Theme.of(context).hintColor),
                              label: Text('Bingung cara dapetin API Key-nya?',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor,
                                      decoration: TextDecoration.underline)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white12
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    if (_localApiKey != null && _currentSessionId != null)
                      IconButton(
                        onPressed: () =>
                            setState(() => _currentSessionId = null),
                        icon: Icon(CupertinoIcons.chevron_back, size: 20),
                        tooltip: 'Pilih Chat',
                      ),
                    Icon(CupertinoIcons.sparkles,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.indigoAccent
                            : Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Text(_currentSessionId == null ? 'AI Dashboard' : 'Chat',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color)),
                    const Spacer(),
                    const SizedBox(width: 8),
                    if (_localApiKey != null) ...[
                      IconButton(
                        onPressed: () {
                          widget.onRemoveKey(); // Clear from prefs
                          setState(() {
                            _localApiKey = null;
                            _currentSessionId = null;
                          });
                        },
                        icon: Icon(CupertinoIcons.settings,
                            color: Theme.of(context).hintColor),
                        tooltip: 'Ganti Mode AI',
                      ),
                      ValueListenableBuilder<String>(
                        valueListenable: AIService.statusNotifier,
                        builder: (context, status, child) {
                          Color dotColor;
                          String tooltipMsg;

                          if (status == 'exhausted') {
                            dotColor = AppColors.expense; // Red
                            tooltipMsg = 'Semua Kuota API Habis (Total Limit)';
                          } else if (status == 'limit') {
                            dotColor = Colors.orange; // Yellow/Orange
                            tooltipMsg =
                                'API Pribadi Limit, Menggunakan Antrean Cadangan';
                          } else {
                            // status == 'ok'
                            dotColor = _localApiKey!.isEmpty
                                ? Colors.blue
                                : Colors.green;
                            tooltipMsg = _localApiKey!.isEmpty
                                ? 'Internal AI Aktif'
                                : 'Personal API Aktif';
                          }

                          return Tooltip(
                            message: tooltipMsg,
                            child: Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    IconButton(
                        onPressed: () {
                          showGeneralDialog(
                            context: context,
                            barrierDismissible: true,
                            barrierLabel: '',
                            barrierColor: Colors.black.withOpacity(0.5),
                            transitionDuration:
                                const Duration(milliseconds: 300),
                            pageBuilder: (context, anim1, anim2) => Center(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10)),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                        sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      padding: const EdgeInsets.all(32),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.grey[900]?.withOpacity(0.9)
                                            : Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(32),
                                        border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.5),
                                            width: 1),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: AppColors.expense
                                                    .withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                CupertinoIcons
                                                    .exclamationmark_triangle_fill,
                                                color: AppColors.expense,
                                                size: 32,
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            Text('Baca Yaaa!',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.5,
                                                    color: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color ??
                                                        Colors.black87)),
                                            const SizedBox(height: 12),
                                            Text(
                                                'Ni AI gweh buat untuk manage uang di APP ini, bukan malah buat curhat anjerr, limit coo... *Archen',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.color ??
                                                        Colors.grey,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.5)),
                                            const SizedBox(height: 32),
                                            InkWell(
                                              onTap: () =>
                                                  Navigator.pop(context),
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 16),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                              .brightness ==
                                                          Brightness.dark
                                                      ? Colors.indigoAccent
                                                      : Theme.of(context)
                                                          .primaryColor,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.1),
                                                        blurRadius: 10,
                                                        offset:
                                                            const Offset(0, 4)),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text('Siap Kak!',
                                                      style: TextStyle(
                                                          color: Theme.of(context)
                                                                      .brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? Colors.white
                                                              : Colors.white,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 14)),
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
                            ),
                            transitionBuilder: (context, anim1, anim2, child) =>
                                ScaleTransition(
                              scale: CurvedAnimation(
                                  parent: anim1, curve: Curves.easeOutBack),
                              child:
                                  FadeTransition(opacity: anim1, child: child),
                            ),
                          );
                        },
                        icon: Icon(CupertinoIcons.question_circle,
                            color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
              const Divider(),
              if (_localApiKey == null)
                Expanded(child: _buildKeySetup())
              else if (_currentSessionId == null)
                Expanded(child: _buildDashboard())
              else
                Expanded(child: _buildChatInterface()),
            ],
          ),
        ),
      ),
    );
  }

  void _showAPITutorial() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white12
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.lightbulb_fill, color: Colors.amber),
                    const SizedBox(width: 12),
                    Text('Tutorial Dapatkan API Key',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(CupertinoIcons.xmark,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                  ],
                ),
              ),
              Divider(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildStepItem(
                      step: '1',
                      title: 'Buka Google AI Studio',
                      desc: 'Cari atau kunjungi: aistudio.google.com',
                    ),
                    _buildStepItem(
                      step: '2',
                      title: 'Login Akun Google',
                      desc:
                          'Masuk pakai akun Gmail atau Google Workspace kamu.',
                    ),
                    _buildStepItem(
                      step: '3',
                      title: 'Klik "Get API Key"',
                      desc: 'Pilih tombol menu di samping kiri (ikon kunci).',
                    ),
                    _buildStepItem(
                      step: '4',
                      title: 'Buat API Key Baru',
                      desc: 'Klik "Create API key in new project".',
                    ),
                    _buildStepItem(
                      step: '5',
                      title: 'Salin ke MyDuitGweh',
                      desc:
                          'Copy kode kuncinya, lalu pilih "Tambah API Key" di sini.',
                      isLast: true,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (Theme.of(context).brightness == Brightness.dark
                                ? Colors.indigoAccent
                                : Colors.blue)
                            .withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.indigoAccent
                                        : Colors.blue)
                                    .withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.info,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.indigoAccent
                                  : Colors.blue,
                              size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'API Key Gemini (Free Tier) gratis untuk penggunaan personal.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.indigoAccent
                                      : Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required String desc,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(step,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                                  Colors.grey,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeySetup() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.sparkles,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.indigoAccent
                  : Theme.of(context).primaryColor),
          const SizedBox(height: 12),
          Text('Pilih Mode AI Advisor',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
              'Gunakan asisten keuangan pintar untuk menganalisis data Anda secara instan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color ??
                      Colors.grey,
                  fontSize: 13)),
          const SizedBox(height: 32),

          // Opsi Integrated
          _buildOptionCard(
            title: 'AI Bawaan (Terintegrasi)',
            subtitle: 'Gunakan API Key aplikasi Langsung.',
            icon: CupertinoIcons.bolt_fill,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.indigoAccent
                : Theme.of(context).primaryColor,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onTap: () {
              setState(() => _localApiKey = "");
              widget.onSaveKey("", "gemini"); // Save to prefs
            },
          ),
          const SizedBox(height: 12),
          Text('ATAU',
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          const SizedBox(height: 12),

          // Opsi Sendiri
          _buildOptionCard(
            title: 'API Key Sendiri',
            subtitle: 'Atur & pilih dari daftar API Key Kamu.',
            icon: CupertinoIcons.lock_fill,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey
                : Colors.blueGrey,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onTap: _showManageAPIDialog,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _showAPITutorial,
            icon: Icon(CupertinoIcons.question_circle, size: 14),
            label: Text('Cara dapetin API Key gratis?',
                style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    color: Theme.of(context).hintColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        _buildHealthScoreCard(),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildQuotaPreviewCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildNewChatQuickCard()),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('RIWAYAT PERCAKAPAN',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Theme.of(context).hintColor.withOpacity(0.8))),
            const Spacer(),
            if (_allSessions.isNotEmpty)
              TextButton(
                  onPressed: _showClearAllConfirm,
                  child: Text('Hapus Semua',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 8),
        _allSessions.isEmpty
            ? _buildEmptySessions()
            : Column(
                children: _allSessions
                    .map((session) => _buildSessionItem(session))
                    .toList(),
              ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHealthScoreCard() {
    return StreamBuilder<List<TransactionModel>>(
        stream: widget.firestoreService.getFilteredTransactionsStream(
          walletIds: widget.walletIds,
          startDate: widget.selectedDateRange.start,
          endDate: widget.selectedDateRange.end,
        ),
        builder: (context, snapshot) {
          double income = 0;
          double expense = 0;
          if (snapshot.hasData) {
            for (var txn in snapshot.data!) {
              if (txn.isIncome) {
                income += txn.amount;
              } else if (txn.isExpense) {
                expense += txn.amount;
              }
            }
          }

          double score = 100;
          String status = "Sangat Sehat";
          String initialAnalysis =
              "**Archen** ( ˘︹˘ ):  Menghitung kesehatan keuanganmu...";

          if (income > 0) {
            double savingsRate = (income - expense) / income;
            score = (savingsRate * 100).clamp(0, 100);

            if (score > 80) {
              status = "Sangat Sehat";
            } else if (score > 50) {
              status = "Cukup Sehat";
            } else if (score > 20) {
              status = "Waspada";
            } else {
              status = "Kritis";
            }
          } else if (expense > 0) {
            score = 0;
            status = "Kritis";
          }

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: score > 50
                    ? [const Color(0xFF6A11CB), const Color(0xFF2575FC)]
                    : [const Color(0xFFFF416C), const Color(0xFFFF4B2B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: (score > 50
                          ? const Color(0xFF6A11CB)
                          : const Color(0xFFFF416C))
                      .withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(CupertinoIcons.shield_fill,
                              color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text('AI Health Diagnose',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, prefsSnapshot) {
                        String lastUpdateStr = '--:--';
                        if (prefsSnapshot.hasData) {
                          final storedTime = prefsSnapshot.data!
                              .getString('advisor_last_update');
                          if (storedTime != null) {
                            lastUpdateStr = DateFormat('HH:mm')
                                .format(DateTime.parse(storedTime));
                          }
                        }
                        return Text(
                          'Update: $lastUpdateStr',
                          style: TextStyle(color: Colors.white70, fontSize: 10),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(score.toStringAsFixed(0),
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2)),
                        Text(status,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 6),
                      ),
                      child: AnimatedHeartbeat(
                        score: score,
                        icon: score > 50
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.exclamationmark_triangle_fill,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // REAL AI ANALYSIS TEXT
                FutureBuilder<String>(
                  future: (snapshot.hasData && snapshot.data!.isNotEmpty)
                      ? DebtService()
                          .getUserDebts(widget.uid)
                          .first
                          .then((debts) {
                          return AIService.getAdvisorAnalysis(
                            transactions: snapshot.data!,
                            wallets: widget.wallets,
                            debts: debts,
                            dateRange: widget.selectedDateRange,
                            score: score,
                            status: status,
                            tone: ToneManager.notifier.value,
                          );
                        })
                      : Future.value(initialAnalysis),
                  builder: (context, analysisSnapshot) {
                    String cleanedData = (analysisSnapshot.data ?? '').trim();
                    final prefixPattern =
                        RegExp(r'^\**Archen.*?:?\**\s*', caseSensitive: false);
                    cleanedData = cleanedData.replaceFirst(prefixPattern, '');

                    String displayStr = (analysisSnapshot.data != null &&
                            analysisSnapshot.data != initialAnalysis)
                        ? "**Archen** (´･ω･`):  $cleanedData"
                        : initialAnalysis;
                    String? drainingWarning;
                    if (displayStr.contains('(Archen Lagi draining')) {
                      final parts = displayStr.split('(Archen Lagi draining');
                      displayStr = parts[0].trim();
                      if (parts.length > 1) {
                        drainingWarning =
                            'Archen Lagi Draining ${parts[1].replaceAll(')', '').trim()}';
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: displayStr,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                            strong: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w900,
                            ),
                            listBullet: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            code: TextStyle(
                              backgroundColor: Colors.transparent,
                              color: Colors.white,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            horizontalRuleDecoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  width: 0.5,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (drainingWarning != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: InkWell(
                                onTap: () {
                                  UIHelper.showInfoSnackBar(
                                      context, drainingWarning!);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 0.5),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.battery_empty,
                                          color: Colors.amberAccent, size: 16),
                                      SizedBox(width: 8),
                                      Text('Status: Cooldown',
                                          style: TextStyle(
                                              color: Colors.amberAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        });
  }

  Widget _buildQuotaPreviewCard() {
    final int remaining = (_aiLimit - _aiCount).clamp(0, _aiLimit);
    final double progress = (_aiCount / _aiLimit).clamp(0.0, 1.0);
    final bool isHigh = progress > 0.8;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isHigh ? Colors.red : Theme.of(context).primaryColor)
                      .withOpacity(
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.2
                              : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.bolt_fill,
                    size: 16,
                    color: isHigh
                        ? Colors.red
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.amber
                            : Theme.of(context).primaryColor)),
              ),
              const SizedBox(width: 8),
              Text('AI Quota',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).hintColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$remaining',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isHigh
                          ? Colors.red
                          : Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.black87)),
              Text('/$_aiLimit',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).hintColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(isHigh
                  ? Colors.red
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.amber
                      : Theme.of(context).primaryColor)),
              minHeight: 4,
            ),
          ),
          if (_nextReset != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reset dlm $_nextReset',
              style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).hintColor.withOpacity(0.6),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNewChatQuickCard() {
    return InkWell(
      onTap: _createNewChat,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.indigo[900]?.withOpacity(0.8)
              : Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(24),
          border: Theme.of(context).brightness == Brightness.dark
              ? Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.25),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(CupertinoIcons.chat_bubble_text_fill,
                color: Colors.white, size: 20),
            const SizedBox(height: 12),
            Text('Tanya Archen',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text('Mulai chat baru',
                style: TextStyle(color: Colors.white70, fontSize: 10)),
            const Spacer(),
            Icon(CupertinoIcons.arrow_right, color: Colors.white, size: 14),
            const SizedBox(height: 8),
            Text(
              'AI Assist',
              style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySessions() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(CupertinoIcons.chat_bubble,
              size: 48,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Belum ada riwayat percakapan',
              style:
                  TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: () => _loadSession(session['id']),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.1),
            shape: BoxShape.circle,
            border: Theme.of(context).brightness == Brightness.dark
                ? Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    width: 1)
                : null,
          ),
          child: Icon(CupertinoIcons.chat_bubble_fill,
              size: 18,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Theme.of(context).primaryColor),
        ),
        title: Text(session['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
            DateFormat('dd MMM, HH:mm')
                .format(DateTime.parse(session['lastUpdate'])),
            style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
        trailing: IconButton(
          icon: Icon(CupertinoIcons.trash,
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white54
                  : Colors.grey),
          onPressed: () => _showDeleteConfirm(session['id']),
        ),
      ),
    );
  }

  void _showDeleteConfirm(String sessionId) async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: ToneManager.t('dialog_del_chat_title'),
      message: ToneManager.t('dialog_del_chat_msg'),
    );
    if (confirm == true) {
      _deleteSession(sessionId);
    }
  }

  void _showClearAllConfirm() async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: ToneManager.t('dialog_del_all_chat_title'),
      message: ToneManager.t('dialog_del_all_chat_msg'),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      for (var session in _allSessions) {
        await prefs.remove('ai_chat_history_${session['id']}');
      }
      setState(() {
        _allSessions.clear();
        if (_currentSessionId != null) {
          _currentSessionId = null;
          _messages = [];
        }
      });
      _saveSessionsList();
    }
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.5)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                                  Colors.grey)),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_messages.isEmpty && !_isLoading)
                  _buildSuggestions()
                else ...[
                  ..._messages.map((m) => _buildMessageBubble(
                        m['isAI'] ? '✧Archen AI' : 'Anda',
                        m['text'],
                        isAI: m['isAI'],
                      )),
                ],
                if (_isLoading) _buildLoadingBubble(),
              ],
            ),
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      'Berapa pengeluaran kopi saya?',
      'Berikan tips hemat 500rb bulan depan',
      'Analisis pola pengeluaran saya',
      'Masukan investasi yang cocok untuk saya'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coba tanya ini:',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map((s) => ActionChip(
                    label: Text(s,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black)),
                    onPressed: () => _handleQuery(s),
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariant,
                    side: BorderSide.none,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(String sender, String text, {required bool isAI}) {
    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isAI
              ? (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariant)
              : (Theme.of(context).brightness == Brightness.dark
                  ? const ui.Color.fromARGB(255, 61, 61, 61)
                  : Theme.of(context).primaryColor),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAI ? 0 : 20),
            bottomRight: Radius.circular(isAI ? 20 : 0),
          ),
          border: (!isAI && Theme.of(context).brightness == Brightness.dark)
              ? Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color:
                        isAI ? Theme.of(context).hintColor : Colors.white70)),
            const SizedBox(height: 8),
            if (isAI)
              MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.9)
                          : AppColors.textPrimary),
                  strong: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF5AC8FA)
                          : Theme.of(context).primaryColor),
                  listBullet: TextStyle(
                      fontSize: 14, color: Theme.of(context).primaryColor),
                  code: TextStyle(
                    backgroundColor: Colors.transparent,
                    color: Theme.of(context).primaryColor,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
            else
              Text(text, style: TextStyle(height: 1.4, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: Row(
        children: [
          ValueListenableBuilder<AppTone>(
            valueListenable: ToneManager.notifier,
            builder: (context, tone, child) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => UIHelper.showToneSelector(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tone == AppTone.pasangan
                          ? Color(0xFFFF2D55).withOpacity(0.15)
                          : Theme.of(context).primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      tone == AppTone.genZ
                          ? '🤘'
                          : tone == AppTone.boomer
                              ? '👴'
                              : tone == AppTone.milenial
                                  ? '☕'
                                  : tone == AppTone.pasangan
                                      ? '❤️'
                                      : '🤵',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : AppColors.background,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _queryController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                    hintText: 'Tanyakan sesuatu...',
                    hintStyle:
                        TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16)),
                onSubmitted: _handleQuery,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _handleQuery(_queryController.text),
              icon: Icon(CupertinoIcons.paperplane_fill,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleQuery(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isAI': false});
      _isLoading = true;
      _queryController.clear();
    });

    _scrollToBottom();

    try {
      // 1. Ambil data wallet, transaksi & hutang untuk konteks AI
      final wallets =
          await widget.firestoreService.getWalletsStream(widget.uid).first;
      final walletIds = wallets.map((w) => w.id).toList();
      final txns = await widget.firestoreService
          .getFilteredTransactionsStream(
              walletIds: walletIds,
              startDate: widget.selectedDateRange.start,
              endDate: widget.selectedDateRange.end)
          .first;
      final debts = await DebtService().getUserDebts(widget.uid).first;

      // 2. Siapkan history chat
      final history = _messages.take(_messages.length - 1).map((m) {
        if (m['isAI'] == true) {
          return Content.model([TextPart(m['text'])]);
        } else {
          return Content.text(m['text']);
        }
      }).toList();

      // 3. Panggil AI Service
      final response = await _aiService.getFinancialAdvice(
        apiKey: _localApiKey,
        apiPlatform: _localApiPlatform,
        transactions: txns,
        wallets: widget.wallets,
        debts: debts,
        userQuery: text,
        dateRange: widget.selectedDateRange,
        tone: ToneManager.notifier.value,
        history: history,
      );

      if (mounted) {
        setState(() {
          // Clean the response from any prefixes the AI might have added
          String cleanedResponse = response.trim();
          final prefixPattern =
              RegExp(r'^\**Archen.*?:?\**\s*', caseSensitive: false);
          cleanedResponse = cleanedResponse.replaceFirst(prefixPattern, '');

          _messages.add({'text': cleanedResponse, 'isAI': true});
          _isLoading = false;
        });
        _saveCurrentSession();
        _scrollToBottom();

        // 4. Refresh quota setelah berhasil chat
        _refreshQuota();
      }
    } catch (e) {
      debugPrint('AI Query Error: $e');
      if (mounted) {
        setState(() {
          _messages.add({
            'text':
                'Maaf, asisten AI sedang mengalami gangguan atau limit pada layanan. Silakan coba kembali beberapa saat lagi atau periksa konfigurasi kunci API Anda di pengaturan.',
            'isAI': true,
          });
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}


class AnimatedHeartbeat extends StatefulWidget {
  final double score;
  final IconData icon;

  const AnimatedHeartbeat({super.key, required this.score, required this.icon});

  @override
  State<AnimatedHeartbeat> createState() => _AnimatedHeartbeatState();
}

class _AnimatedHeartbeatState extends State<AnimatedHeartbeat>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _updateSpeed();
  }

  @override
  void didUpdateWidget(AnimatedHeartbeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _updateSpeed();
    }
  }

  void _updateSpeed() {
    int durationMs = 800;
    if (widget.score >= 80) {
      durationMs = 1200; // Calm heartbeat
    } else if (widget.score < 50) {
      durationMs = 400; // Panic heartbeat
    }

    _controller.duration = Duration(milliseconds: durationMs);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ScaleTransition(
      scale: _animation,
      child: Center(
        child: Icon(
          widget.icon,
          color: isDark ? Colors.white : Colors.white,
          size: 28,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 10,
            )
          ],
        ),
      ),
    );
  }
}


