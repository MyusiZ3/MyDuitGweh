import 'dart:ui' as ui;
import 'package:flutter/material.dart';
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
  bool _isCheckingAi = false;
  String? _aiApiKey;
  String? _aiApiPlatform; // 'gemini' or 'groq'
  List<String> _allApiKeys = []; // Stores combined "key|platform"
  List<String> _currentWalletIds = [];
  List<WalletModel> _allWallets = []; // Store current wallets for AIcontext

  bool _isNotifAccessGranted = false;
  bool _isNotifBannerDismissed = false;

  Future<void> _checkNotifStatus() async {
    final granted = await NotifListenerBridge.isAccessGranted();
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('notif_banner_dismissed') ?? false;
    if (mounted) {
      setState(() {
        _isNotifAccessGranted = granted;
        _isNotifBannerDismissed = dismissed;
      });
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
    return _txnStream!;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tanggal
          Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      '${DateFormat('dd MMM').format(selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange.end)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<WalletModel>>(
              stream: _walletStream,
              builder: (context, walletSnapshot) {
                if (walletSnapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: ShimmerTransactionList());
                }

                final wallets = walletSnapshot.data ?? [];
                if (wallets.isEmpty) {
                  return _buildNoData(
                      'Belum ada dompet', 'Buat dompet dulu yuk!');
                }

                final walletIds = wallets.map((w) => w.id).toList();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    // Update current wallets list for AI context
                    _allWallets = wallets;

                    // Use set comparison to avoid rebuild loop (List != List is always true for new instances)
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
                    if (txnSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: ShimmerTransactionList());
                    }

                    final transactions = txnSnapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return _buildNoData('Belum ada transaksi',
                          'Tidak ada catatan di periode ini.');
                    }

                    double totalIncome = 0;
                    double totalExpense = 0;
                    Map<String, double> categoryTotals = {};

                    for (var txn in transactions) {
                      if (txn.isIncome) {
                        totalIncome += txn.amount;
                      } else {
                        totalExpense += txn.amount;
                        categoryTotals[txn.category] =
                            (categoryTotals[txn.category] ?? 0) + txn.amount;
                      }
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _buildSummaryCard(totalIncome - totalExpense,
                            totalIncome, totalExpense),
                        const SizedBox(height: 24),
                        const SizedBox(height: 24),
                        _buildInsightToggle(),
                        const SizedBox(height: 24),
                        if (_isCategoryMode)
                          if (totalExpense > 0)
                            _buildInteractivePieChart(
                                categoryTotals, totalExpense)
                          else
                            const Center(child: Text('Belum ada pengeluaran'))
                        else
                          _buildWeeklyTrendChart(transactions),
                        const SizedBox(height: 24),
                        if (_isCategoryMode && totalExpense > 0)
                          _buildCategoryList(categoryTotals, totalExpense),
                        const SizedBox(height: 32),
                        _buildNotifSettingsCard(),
                        const SizedBox(height: 100),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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

          if (!isEnabled) {
            UIHelper.showAiMaintenanceDialog(context);
            return;
          }

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
            : const Text('Arch AI',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
        icon: _isCheckingAi
            ? const SizedBox.shrink()
            : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        backgroundColor: AppColors.primary,
        elevation: 4,
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
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
              secondaryContainer: const Color.fromARGB(255, 144, 142, 180)
                  .withOpacity(
                      0.12), // Warna blok rentang (sekarang dipaksa biru muda)
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) setState(() => selectedDateRange = range);
  }

  Widget _buildNotifSettingsCard() {
    return StreamBuilder<bool>(
      stream: NotifListenerBridge.globalConfigStream,
      builder: (context, snapshot) {
        final globalEnabled = snapshot.data ?? false;

        if (!globalEnabled) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Auto-Magic Sync',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 0.8),
                              ),
                              child: Text(
                                'EXPERIMENTAL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 7,
                                  color: AppColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Catat transaksi otomatis dari notifikasi',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isNotifAccessGranted
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color:
                          _isNotifAccessGranted ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isNotifAccessGranted
                            ? 'Izin Akses Aktif'
                            : 'Izin Akses Belum Diberikan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isNotifAccessGranted
                              ? Colors.green[700]
                              : Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await NotifListenerBridge.openSettings();
                  // Re-check after returning from settings
                  Future.delayed(const Duration(seconds: 2), _checkNotifStatus);
                },
                icon: const Icon(Icons.settings_suggest_rounded,
                    color: Colors.white, size: 20),
                label: const Text('Buka Pengaturan Izin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_isNotifBannerDismissed && !_isNotifAccessGranted) ...[
                const SizedBox(height: 8),
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
                  child: const Center(
                    child: Text(
                      'Tampilkan kembali banner di Home',
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        color: AppColors.textHint,
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
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('TOTAL SALDO BERSIH',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.formatCurrency(balance),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildMiniStat('Pemasukan', income,
                      Icons.arrow_downward_rounded, Colors.white),
                ),
                Container(width: 1, height: 24, color: Colors.white24),
                Expanded(
                  child: _buildMiniStat('Pengeluaran', expense,
                      Icons.arrow_upward_rounded, Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String label, double amount, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(CurrencyFormatter.formatCurrency(amount),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildInsightToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleItem('Kategori', _isCategoryMode, () {
              setState(() => _isCategoryMode = true);
            }),
          ),
          Expanded(
            child: _toggleItem('Tren Mingguan', !_isCategoryMode, () {
              setState(() => _isCategoryMode = false);
            }),
          ),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              color: isActive ? AppColors.primary : AppColors.textHint,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractivePieChart(
      Map<String, double> categoryTotals, double total) {
    return StatefulBuilder(
      builder: (context, setChartState) {
        List<PieChartSectionData> sections = [];
        int i = 0;
        final colors = [
          AppColors.primary,
          const Color(0xFF5856D6), // iOS Purple
          AppColors.income,
          const Color(0xFFFF9500), // iOS Orange
          const Color(0xFFFF2D55), // iOS Red
          const Color(0xFF8E8E93), // iOS Gray
        ];

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
                        color: AppColors.textHint),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.formatCurrency(total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
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

    // Sort to get chronological order
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
        } else {
          expenseByDay[dayKey] = (expenseByDay[dayKey] ?? 0) + txn.amount;
        }
      }
    }

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
        showingTooltipIndicators: [],
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
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHint)),
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              );
            },
          ),
        ),
      )),
    );
  }

  Widget _buildCategoryList(Map<String, double> categoryTotals, double total) {
    return Column(
      children: categoryTotals.entries.map((e) {
        final percentage = (e.value / total);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(TransactionCategory.getIconForCategory(e.key),
                    color: AppColors.primary, size: 20),
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
                        backgroundColor: AppColors.background,
                        color: AppColors.primary,
                        minHeight: 4),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(CurrencyFormatter.formatCurrency(e.value),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoData(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined,
              size: 80, color: AppColors.textHint.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: AppColors.textHint)),
        ],
      ),
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

      if (!context.mounted) return;
      Navigator.pop(context); // Tutup loading

      if (txns.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Tidak ada data transaksi di periode ini untuk diekspor.')));
        return;
      }

      final availableCategories = txns.map((t) => t.category).toSet().toList();
      availableCategories.sort();
      List<String> selectedCategories = List.from(availableCategories);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
                top: 12,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                        color: AppColors.textHint.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Pilih Kategori',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(
                    'Tentukan kategori yang ingin kamu masukkan ke dalam laporan.',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                const SizedBox(height: 24),

                // Selection Actions
                Row(
                  children: [
                    _buildQuickAction('Semua',
                        selectedCategories.length == availableCategories.length,
                        () {
                      setSheetState(() =>
                          selectedCategories = List.from(availableCategories));
                    }),
                    const SizedBox(width: 8),
                    _buildQuickAction('Kosongkan', selectedCategories.isEmpty,
                        () {
                      setSheetState(() => selectedCategories.clear());
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // Modern Chip List
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: availableCategories.map((cat) {
                        final isSelected = selectedCategories.contains(cat);
                        return InkWell(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                selectedCategories.remove(cat);
                              } else {
                                selectedCategories.add(cat);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  TransactionCategory.getIconForCategory(cat),
                                  size: 16,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textHint,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Bottom Actions (Ramping & Modern)
                Row(
                  children: [
                    Expanded(
                      child: _buildExportButton(
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_rounded,
                        color: Colors.red,
                        onPressed: selectedCategories.isEmpty
                            ? null
                            : () => _processExport(
                                ctx, txns, selectedCategories, true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildExportButton(
                        label: 'CSV',
                        icon: Icons.table_view_rounded,
                        color: Colors.green,
                        onPressed: selectedCategories.isEmpty
                            ? null
                            : () => _processExport(
                                ctx, txns, selectedCategories, false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyiapkan data: $e')));
    }
  }

  Widget _buildQuickAction(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : AppColors.textHint.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(
      {required String label,
      required IconData icon,
      required Color color,
      VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        disabledBackgroundColor: color.withOpacity(0.3),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2),
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
      } else {
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
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
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
              color: isSelected ? Colors.white : AppColors.textHint,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : AppColors.textPrimary,
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
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                      color: Colors.grey.shade300,
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
                              const Icon(Icons.key_rounded,
                                  color: AppColors.primary),
                              const SizedBox(width: 12),
                              Text(ToneManager.t('dialog_api_title'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: -0.5)),
                              const Spacer(),
                              IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 20)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPlatformToggle(
                                  label: 'Gemini',
                                  isSelected: selectedPlatform == 'gemini',
                                  icon: Icons.auto_awesome_rounded,
                                  onTap: () => setDialogState(
                                      () => selectedPlatform = 'gemini'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPlatformToggle(
                                  label: 'Groq',
                                  isSelected: selectedPlatform == 'groq',
                                  icon: Icons.bolt_rounded,
                                  onTap: () => setDialogState(
                                      () => selectedPlatform = 'groq'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(ToneManager.t('dialog_api_add'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textHint)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Masukkan API Key...',
                              hintStyle: TextStyle(
                                  color: AppColors.textHint.withOpacity(0.5)),
                              filled: true,
                              fillColor:
                                  AppColors.surfaceVariant.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.vpn_key_outlined,
                                  size: 20, color: AppColors.textHint),
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
                                  icon: const Icon(Icons.paste_rounded,
                                      size: 16, color: AppColors.primary),
                                  label: const Text('Paste',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary)),
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.1),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: AppColors.primary
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
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        Color(0xFF8B5CF6)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.primary.withOpacity(0.3),
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
                                        : const Icon(
                                            Icons.add_circle_outline_rounded,
                                            size: 18,
                                            color: Colors.white),
                                    label: Text(
                                        isCheckingKey
                                            ? 'Mengecek...'
                                            : 'Add API',
                                        style: const TextStyle(
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('KUNCI BAWAAN (Shared)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHint,
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
                                color:
                                    AppColors.surfaceVariant.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: isActive
                                        ? AppColors.primary.withOpacity(0.3)
                                        : Colors.transparent,
                                    width: 1),
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
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 16,
                                        color: isActive
                                            ? AppColors.primary
                                            : Colors.grey),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                          'Integrated Keys ($keysCount keys)',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (_localAllApiKeys.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text('SAVED KEYS',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHint,
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
                                            ? AppColors.primary
                                                .withOpacity(0.08)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: isActive
                                                ? AppColors.primary
                                                    .withOpacity(0.2)
                                                : AppColors.surfaceVariant,
                                            width: 1.5),
                                        boxShadow: isActive
                                            ? [
                                                BoxShadow(
                                                    color: AppColors.primary
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
                                                    ? AppColors.primary
                                                    : AppColors.surfaceVariant
                                                        .withOpacity(0.5),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isActive
                                                    ? Icons.check_rounded
                                                    : (platform == 'groq'
                                                        ? Icons.bolt_rounded
                                                        : Icons
                                                            .auto_awesome_rounded),
                                                size: 14,
                                                color: isActive
                                                    ? Colors.white
                                                    : AppColors.textHint,
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
                                                            ? AppColors.primary
                                                            : AppColors
                                                                .textPrimary),
                                                  ),
                                                  if (isActive)
                                                    Text(
                                                        ToneManager.t(
                                                            'dialog_api_active'),
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: AppColors
                                                                    .primary,
                                                                letterSpacing:
                                                                    0.5)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_sweep_rounded,
                                                  size: 20,
                                                  color: Colors.grey),
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
                              icon: const Icon(Icons.help_outline_rounded,
                                  size: 14, color: AppColors.textHint),
                              label: const Text(
                                  'Bingung cara dapetin API Key-nya?',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
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
      decoration: const BoxDecoration(
        color: Colors.white,
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
                    color: Colors.grey[300],
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
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20),
                        tooltip: 'Pilih Chat',
                      ),
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(_currentSessionId == null ? 'AI Dashboard' : 'Chat',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5)),
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
                        icon: const Icon(Icons.settings_suggest_rounded,
                            color: AppColors.textHint),
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
                                        color: Colors.white.withOpacity(0.9),
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
                                              child: const Icon(
                                                Icons.warning_amber_rounded,
                                                color: AppColors.expense,
                                                size: 32,
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            const Text('Baca Yaaa!',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.5,
                                                    color:
                                                        AppColors.textPrimary)),
                                            const SizedBox(height: 12),
                                            const Text(
                                                'Ni AI gweh buat untuk manage uang di APP ini, bukan malah buat curhat anjerr, limit coo... *Archen',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
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
                                                  color: Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.25),
                                                        blurRadius: 15,
                                                        offset:
                                                            const Offset(0, 5)),
                                                  ],
                                                ),
                                                child: const Center(
                                                  child: Text('Siap Kak!',
                                                      style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 13)),
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
                        icon: const Icon(Icons.help_outline_rounded,
                            color: AppColors.textHint)),
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
        decoration: const BoxDecoration(
          color: Colors.white,
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
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: Colors.amber),
                    const SizedBox(width: 12),
                    const Text('Tutorial Dapatkan API Key',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(),
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
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'API Key Gemini (Free Tier) gratis untuk penggunaan personal.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.blue),
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
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(step,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.primary.withOpacity(0.2),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
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
          const Icon(Icons.auto_awesome_rounded,
              size: 48, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Pilih Mode AI Advisor',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text(
              'Gunakan asisten keuangan pintar untuk menganalisis data Anda secara instan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 32),

          // Opsi Integrated
          _buildOptionCard(
            title: 'AI Bawaan (Terintegrasi)',
            subtitle: 'Gunakan saldo API aplikasi. Gratis & Langsung.',
            icon: Icons.flash_on_rounded,
            color: AppColors.primary,
            onTap: () {
              setState(() => _localApiKey = "");
              widget.onSaveKey("", "gemini"); // Save to prefs
            },
          ),
          const SizedBox(height: 12),
          const Text('ATAU',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2)),
          const SizedBox(height: 12),

          // Opsi Sendiri
          _buildOptionCard(
            title: 'API Key Sendiri',
            subtitle: 'Atur & pilih dari daftar API Key Kamu.',
            icon: Icons.key_rounded,
            color: Colors.blueGrey,
            onTap: _showManageAPIDialog,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _showAPITutorial,
            icon: const Icon(Icons.help_outline_rounded, size: 14),
            label: const Text('Cara dapetin API Key gratis?',
                style: TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    color: AppColors.textHint)),
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
                    color: AppColors.textHint.withOpacity(0.8))),
            const Spacer(),
            if (_allSessions.isNotEmpty)
              TextButton(
                  onPressed: _showClearAllConfirm,
                  child: const Text('Hapus Semua',
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
              } else {
                expense += txn.amount;
              }
            }
          }

          double score = 100;
          String status = "Sangat Sehat";
          String initialAnalysis =
              "Archen Analytic: Menghitung kesehatan keuanganmu...";

          if (income > 0) {
            double savingsRate = (income - expense) / income;
            score = (savingsRate * 100).clamp(0, 100);

            if (score > 80) {
              status = "Sangat Sehat";
            } else if (score > 50)
              status = "Cukup Sehat";
            else if (score > 20)
              status = "Waspada";
            else
              status = "Kritis";
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
                          Icon(Icons.security_rounded,
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
                    Text(
                        'Update: ${DateFormat('HH:mm').format(DateTime.now())}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(score.toStringAsFixed(0),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2)),
                        Text(status,
                            style: const TextStyle(
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
                            ? Icons.favorite_rounded
                            : Icons.warning_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // REAL AI ANALYSIS TEXT
                FutureBuilder<String>(
                  future: (snapshot.hasData && snapshot.data!.isNotEmpty)
                      ? AIService.getAdvisorAnalysis(
                          transactions: snapshot.data!,
                          wallets: widget.wallets,
                          dateRange: widget.selectedDateRange,
                          score: score,
                          status: status,
                          tone: ToneManager.notifier.value,
                        )
                      : Future.value(initialAnalysis),
                  builder: (context, analysisSnapshot) {
                    String displayStr =
                        analysisSnapshot.data ?? initialAnalysis;
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
                            p: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                            strong: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.4,
                              fontWeight: FontWeight.bold,
                            ),
                            listBullet: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
                                      Icon(Icons.battery_alert_rounded,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isHigh ? Colors.red : AppColors.primary)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded,
                    size: 14, color: isHigh ? Colors.red : AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Text('AI Quota',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHint)),
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
                      color: isHigh ? Colors.red : AppColors.textPrimary)),
              Text('/$_aiLimit',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isHigh ? Colors.red : AppColors.primary),
              minHeight: 4,
            ),
          ),
          if (_nextReset != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reset dlm $_nextReset',
              style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textHint.withOpacity(0.6),
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
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.add_comment_rounded, color: Colors.white, size: 20),
            const SizedBox(height: 12),
            const Text('Tanya Archen',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Mulai chat baru',
                style: TextStyle(color: Colors.white70, fontSize: 10)),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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
          Icon(Icons.chat_bubble_outline_rounded,
              size: 48, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Belum ada riwayat percakapan',
              style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade50),
      ),
      child: ListTile(
        onTap: () => _loadSession(session['id']),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chat_rounded,
              size: 18, color: AppColors.primary),
        ),
        title: Text(session['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
            DateFormat('dd MMM, HH:mm')
                .format(DateTime.parse(session['lastUpdate'])),
            style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              size: 20, color: Colors.grey),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.5)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
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
                        m['isAI'] ? 'Asisten MyDuitGweh' : 'Anda',
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
        const Text('Coba tanya ini:',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textHint)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map((s) => ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _handleQuery(s),
                    backgroundColor: AppColors.surfaceVariant,
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
          color: isAI ? AppColors.surfaceVariant : AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAI ? 0 : 20),
            bottomRight: Radius.circular(isAI ? 20 : 0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sender,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAI ? AppColors.textHint : Colors.white70)),
            const SizedBox(height: 8),
            if (isAI)
              MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.black87),
                  strong: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary),
                  listBullet:
                      const TextStyle(fontSize: 14, color: AppColors.primary),
                ),
              )
            else
              Text(text,
                  style: const TextStyle(height: 1.4, color: Colors.white)),
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
          color: AppColors.surfaceVariant,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                          ? const Color(0xFFFF2D55).withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.1),
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
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _queryController,
                decoration: const InputDecoration(
                    hintText: 'Tanyakan sesuatu...',
                    border: InputBorder.none,
                    filled: false,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                onSubmitted: _handleQuery,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _handleQuery(_queryController.text),
              icon:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
      // 1. Ambil data wallet & transaksi untuk konteks AI
      final wallets =
          await widget.firestoreService.getWalletsStream(widget.uid).first;
      final walletIds = wallets.map((w) => w.id).toList();
      final txns = await widget.firestoreService
          .getFilteredTransactionsStream(
              walletIds: walletIds,
              startDate: widget.selectedDateRange.start,
              endDate: widget.selectedDateRange.end)
          .first;

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
        userQuery: text,
        dateRange: widget.selectedDateRange,
        tone: ToneManager.notifier.value,
        history: history,
      );

      if (mounted) {
        setState(() {
          _messages.add({'text': response, 'isAI': true});
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
                'Waduh, Archen lagi agak pusing (Limit/Error). Coba lagi beberapa saat lagi ya atau cek API di pengaturan.',
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
    } else if (widget.score < 50) durationMs = 400; // Panic heartbeat

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
    return ScaleTransition(
      scale: _animation,
      child: Center(
        child: Icon(
          widget.icon,
          color: Colors.white,
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
