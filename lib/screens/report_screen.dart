import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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
  int _touchedPieIndex = -1;
  bool _isCategoryMode = true;
  String? _aiApiKey;
  List<String> _allApiKeys = [];

  @override
  void initState() {
    super.initState();
    _walletStream = _firestoreService.getWalletsStream(_uid);
    _loadAIKey();
  }

  Future<void> _loadAIKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _aiApiKey = prefs.getString('gemini_api_key');
      _allApiKeys = prefs.getStringList('gemini_all_api_keys') ?? [];
    });
  }

  Future<void> _saveAIKey(String key) async {
    final trimmedKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', trimmedKey);

    if (trimmedKey.isNotEmpty) {
      if (!_allApiKeys.contains(trimmedKey)) {
        setState(() {
          _allApiKeys = [trimmedKey, ..._allApiKeys];
        });
        await prefs.setStringList('gemini_all_api_keys', _allApiKeys);
      }
    }

    setState(() {
      _aiApiKey = trimmedKey;
    });
  }

  Future<void> _deleteStoredKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    _allApiKeys.remove(key);
    await prefs.setStringList('gemini_all_api_keys', _allApiKeys);

    if (_aiApiKey == key) {
      _aiApiKey = null;
      await prefs.remove('gemini_api_key');
    }
    setState(() {});
  }

  Future<void> _removeAIKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gemini_api_key');
    setState(() => _aiApiKey = null);
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
                if (walletSnapshot.connectionState == ConnectionState.waiting)
                  return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: ShimmerTransactionList());

                final wallets = walletSnapshot.data ?? [];
                if (wallets.isEmpty)
                  return _buildNoData(
                      'Belum ada dompet', 'Buat dompet dulu yuk!');

                final walletIds = wallets.map((w) => w.id).toList();

                return StreamBuilder<List<TransactionModel>>(
                  stream: _firestoreService.getFilteredTransactionsStream(
                    walletIds: walletIds,
                    startDate: selectedDateRange.start,
                    endDate: selectedDateRange.end,
                  ),
                  builder: (context, txnSnapshot) {
                    if (txnSnapshot.connectionState == ConnectionState.waiting)
                      return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: ShimmerTransactionList());

                    final transactions = txnSnapshot.data ?? [];
                    if (transactions.isEmpty)
                      return _buildNoData('Belum ada transaksi',
                          'Tidak ada catatan di periode ini.');

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
                        const SizedBox(height: 80),
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
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _AIAdvisorSheet(
              apiKey: _aiApiKey,
              allApiKeys: _allApiKeys,
              onSaveKey: _saveAIKey,
              onDeleteKey: _deleteStoredKey,
              onRemoveKey: _removeAIKey,
              selectedDateRange: selectedDateRange,
              uid: _uid,
              firestoreService: _firestoreService,
            ),
          );
        },
        label: const Text('Tanya AI',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
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
        if (txn.isIncome)
          incomeByDay[dayKey] = (incomeByDay[dayKey] ?? 0) + txn.amount;
        else
          expenseByDay[dayKey] = (expenseByDay[dayKey] ?? 0) + txn.amount;
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
                              if (isSelected)
                                selectedCategories.remove(cat);
                              else
                                selectedCategories.add(cat);
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
      if (txn.isIncome)
        totalIncome += txn.amount;
      else
        totalExpense += txn.amount;
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
  final List<String> allApiKeys;
  final Function(String) onSaveKey;
  final Function(String) onDeleteKey;
  final VoidCallback onRemoveKey;
  final DateTimeRange selectedDateRange;
  final String uid;
  final FirestoreService firestoreService;

  const _AIAdvisorSheet({
    required this.apiKey,
    required this.allApiKeys,
    required this.onSaveKey,
    required this.onDeleteKey,
    required this.onRemoveKey,
    required this.selectedDateRange,
    required this.uid,
    required this.firestoreService,
  });

  @override
  State<_AIAdvisorSheet> createState() => _AIAdvisorSheetState();
}

class _AIAdvisorSheetState extends State<_AIAdvisorSheet> {
  final TextEditingController _queryController = TextEditingController();
  final AIService _aiService = AIService();
  bool _isLoading = false;
  String? _localApiKey;
  String? _currentSessionId;
  List<String> _localAllApiKeys = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _allSessions = []; // List of session metadata
  final ScrollController _scrollController = ScrollController();
  final _uuid = const Uuid();
  final Map<String, bool?> _apiStatus =
      {}; // key -> isWorking (null=unknown, true=ok, false=limit)

  @override
  void initState() {
    super.initState();
    _localApiKey = widget.apiKey;
    _localAllApiKeys = List.from(widget.allApiKeys);
    _loadSessionsList();
  }

  @override
  void didUpdateWidget(_AIAdvisorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.apiKey != oldWidget.apiKey) {
      setState(() => _localApiKey = widget.apiKey);
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
                                                  .checkQuota(textKey);

                                              if (!context.mounted) return;

                                              if (isValid) {
                                                await widget.onSaveKey(textKey);
                                                setDialogState(() {
                                                  _localApiKey = textKey;
                                                  _localAllApiKeys = List.from(
                                                      widget.allApiKeys);
                                                  _apiStatus[textKey] = true;
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
                                                      "API Key tidak valid atau limit! Silakan gunakan key lain.");
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('KUNCI BAWAAN (Shared)',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHint,
                                      letterSpacing: 1.5)),
                              TextButton.icon(
                                onPressed: () async {
                                  final sharedKeys =
                                      _aiService.getIntegratedKeys();
                                  for (var k in sharedKeys) {
                                    setDialogState(() => _apiStatus[k] = null);
                                    final isOk = await _aiService.checkQuota(k);
                                    if (context.mounted) {
                                      setDialogState(
                                          () => _apiStatus[k] = isOk);
                                    }
                                  }
                                  for (var k in _localAllApiKeys) {
                                    setDialogState(() => _apiStatus[k] = null);
                                    final isOk = await _aiService.checkQuota(k);
                                    if (context.mounted) {
                                      setDialogState(
                                          () => _apiStatus[k] = isOk);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.refresh_rounded,
                                    size: 14, color: AppColors.primary),
                                label: const Text('Cek Semua',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Section for Shared/Integrated Keys
                          Column(
                            children: _aiService.getIntegratedKeys().map((key) {
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
                                    setDialogState(() => _localApiKey = "");
                                    setState(() => _localApiKey = "");
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
                                      const Expanded(
                                        child: Text('Integrated Key (Shared)',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                      ),
                                      _buildStatusIndicator(
                                          key, setDialogState),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
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
                                  children: _localAllApiKeys.map((key) {
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
                                          widget.onSaveKey(key);
                                          setDialogState(
                                              () => _localApiKey = key);
                                          setState(() => _localApiKey = key);
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
                                                    : Icons
                                                        .lock_outline_rounded,
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
                                            _buildStatusIndicator(
                                                key, setDialogState),
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
                                                  if (_localApiKey == key)
                                                    _localApiKey = null;
                                                  _apiStatus.remove(key);
                                                  _localAllApiKeys = List.from(
                                                      widget.allApiKeys);
                                                });
                                                setState(() {
                                                  if (_localApiKey == key)
                                                    _localApiKey = null;
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

  Widget _buildStatusIndicator(String key, StateSetter setDialogState) {
    final status = _apiStatus[key];
    return Container(
      width: 50, // Fixed width to prevent shifting when status changes
      alignment: Alignment.centerRight,
      child: status == null
          ? TextButton(
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () async {
                final isOk = await _aiService.checkQuota(key);
                setDialogState(() {
                  _apiStatus[key] = isOk;
                });
              },
              child: Text(ToneManager.t('dialog_api_check'),
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            )
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: status ? Colors.green : Colors.red,
                boxShadow: [
                  BoxShadow(
                      color:
                          (status ? Colors.green : Colors.red).withOpacity(0.4),
                      blurRadius: 4)
                ],
              ),
            ),
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
                    Text(_currentSessionId == null ? 'AI Advisor' : 'Chat',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
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
                    ],
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              const Divider(),
              if (_localApiKey == null)
                Expanded(child: _buildKeySetup())
              else if (_currentSessionId == null)
                Expanded(child: _buildSessionsList())
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
                          const SizedBox(width: 12),
                          const Expanded(
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 4),
          const Text(
              'Gunakan asisten keuangan pintar untuk menganalisis data Anda secara instan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Opsi Integrated
          _buildOptionCard(
            title: 'AI Bawaan (Terintegrasi)',
            subtitle: 'Gunakan saldo API aplikasi. Gratis & Langsung.',
            icon: Icons.flash_on_rounded,
            color: AppColors.primary,
            onTap: () {
              setState(() => _localApiKey = "");
              widget.onSaveKey(""); // Save to prefs
            },
          ),
          const SizedBox(height: 8),
          const Text('ATAU',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // Opsi Sendiri
          _buildOptionCard(
            title: 'API Key Sendiri',
            subtitle: 'Atur & pilih dari daftar API Key Kamu.',
            icon: Icons.key_rounded,
            color: Colors.blueGrey,
            onTap: _showManageAPIDialog,
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _showAPITutorial,
            icon: const Icon(Icons.help_outline_rounded, size: 16),
            label: const Text('Cara dapetin API Key gratis?',
                style: TextStyle(
                    fontSize: 13, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
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
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildOptionCard(
                title: 'Percakapan Baru',
                subtitle: 'Mulai analisis keuangan baru.',
                icon: Icons.add_comment_rounded,
                color: AppColors.primary,
                onTap: _createNewChat,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text('RIWAYAT PERCAKAPAN',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHint)),
                  const Spacer(),
                  if (_allSessions.isNotEmpty)
                    TextButton(
                        onPressed: () async {
                          final confirm = await UIHelper.showConfirmDialog(
                            context: context,
                            title: ToneManager.t('dialog_del_all_chat_title'),
                            message: ToneManager.t('dialog_del_all_chat_msg'),
                          );
                          if (confirm == true) {
                            final prefs = await SharedPreferences.getInstance();
                            for (var session in _allSessions) {
                              await prefs
                                  .remove('ai_chat_history_${session['id']}');
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
                        },
                        child: const Text('Hapus Semua',
                            style: TextStyle(fontSize: 12, color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _allSessions.isEmpty
              ? const Center(
                  child: Text('Belum ada riwayat',
                      style: TextStyle(color: AppColors.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _allSessions.length,
                  itemBuilder: (ctx, i) {
                    final session = _allSessions[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        onTap: () => _loadSession(session['id']),
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.chat_bubble_outline_rounded,
                              size: 18, color: Colors.white),
                        ),
                        title: Text(session['title'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                            DateFormat('dd MMM, HH:mm')
                                .format(DateTime.parse(session['lastUpdate'])),
                            style: const TextStyle(fontSize: 10)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 20, color: Colors.grey),
                          onPressed: () async {
                            final confirm = await UIHelper.showConfirmDialog(
                              context: context,
                              title: ToneManager.t('dialog_del_chat_title'),
                              message: ToneManager.t('dialog_del_chat_msg'),
                            );
                            if (confirm == true) {
                              _deleteSession(session['id']);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
              return PopupMenuButton<AppTone>(
                initialValue: tone,
                tooltip: 'Pilih Gaya Bicara AI',
                offset: const Offset(0, -250),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onSelected: (AppTone newTone) {
                  ToneManager.setTone(newTone);
                },
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
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: AppTone.pasangan,
                      child: Row(children: const [
                        Text('❤️', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text('GF / BF Mode',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600))
                      ])),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: AppTone.genZ,
                      child: Row(children: const [
                        Text('🤘', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text('Gen Z', style: TextStyle(fontSize: 14))
                      ])),
                  PopupMenuItem(
                      value: AppTone.milenial,
                      child: Row(children: const [
                        Text('☕', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text('Milenial', style: TextStyle(fontSize: 14))
                      ])),
                  PopupMenuItem(
                      value: AppTone.boomer,
                      child: Row(children: const [
                        Text('👴', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text('Boomer', style: TextStyle(fontSize: 14))
                      ])),
                  PopupMenuItem(
                      value: AppTone.normal,
                      child: Row(children: const [
                        Text('🤵', style: TextStyle(fontSize: 16)),
                        SizedBox(width: 8),
                        Text('Normal', style: TextStyle(fontSize: 14))
                      ])),
                ],
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

  Future<void> _handleQuery(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      if (!_messages.any((m) => m['text'] == query && m['isAI'] == false)) {
        _messages.add({'text': query, 'isAI': false});
      }
      _isLoading = true;
      _queryController.clear();
    });

    _scrollToBottom();

    bool success = false;
    int retryCount = 0;
    while (!success &&
        retryCount <
            (widget.allApiKeys.isEmpty ? 1 : widget.allApiKeys.length)) {
      try {
        final wallets =
            await widget.firestoreService.getWalletsStream(widget.uid).first;
        final walletIds = wallets.map((w) => w.id).toList();
        final txns = await widget.firestoreService
            .getFilteredTransactionsStream(
                walletIds: walletIds,
                startDate: widget.selectedDateRange.start,
                endDate: widget.selectedDateRange.end)
            .first;

        final history = _messages.take(_messages.length - 1).map((m) {
          if (m['isAI'] == true) {
            return Content.model([TextPart(m['text'])]);
          } else {
            return Content.text(m['text']);
          }
        }).toList();

        final res = await _aiService.getFinancialAdvice(
            apiKey: _localApiKey,
            transactions: txns,
            userQuery: query,
            dateRange: widget.selectedDateRange,
            tone: ToneManager.notifier.value,
            history: history);

        setState(() {
          _messages.add({'text': res, 'isAI': true});
          _isLoading = false;
        });

        _saveCurrentSession();
        success = true;
      } catch (e) {
        if (e.toString().contains('QUOTA_EXCEEDED')) {
          if (_localApiKey != null) {
            _apiStatus[_localApiKey!] = false;
          }

          // Find next available key
          String? nextKey;
          for (var k in widget.allApiKeys) {
            if (_apiStatus[k] != false && k != _localApiKey) {
              nextKey = k;
              break;
            }
          }

          if (nextKey != null) {
            debugPrint('--- SWITCHING API KEY TO: $nextKey ---');
            _localApiKey = nextKey;
            retryCount++;
            UIHelper.showErrorSnackBar(context,
                "API ini mencapai limit! Kami nyobain API Key kamu yang lain ya...");
            continue; // RETRY with new key
          }

          setState(() {
            _messages.add({
              'text': ToneManager.t('snack_api_limit_detected'),
              'isAI': true,
            });
            _isLoading = false;
          });
          break;
        }

        setState(() {
          _messages.add({
            'text': 'Waduh error: $e',
            'isAI': true,
          });
          _isLoading = false;
        });
        break;
      } finally {
        _scrollToBottom();
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
