import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/pdf_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../widgets/loading_widget.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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
              stream: _firestoreService.getWalletsStream(_uid),
              builder: (context, walletSnapshot) {
                if (walletSnapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: LoadingWidget());

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
                      return const Center(child: LoadingWidget());

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
                        if (totalExpense > 0) ...[
                          const Text('Analisa Pengeluaran',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildChart(categoryTotals, totalExpense),
                          const SizedBox(height: 24),
                          _buildCategoryList(categoryTotals, totalExpense),
                        ] else
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                      'Belum ada pengeluaran untuk dianalisa'))),
                        const SizedBox(height: 40),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
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
          Text(
            CurrencyFormatter.formatCurrency(balance),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5),
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
                _buildMiniStat('Pemasukan', income,
                    Icons.arrow_downward_rounded, Colors.white),
                Container(width: 1, height: 24, color: Colors.white24),
                _buildMiniStat('Pengeluaran', expense,
                    Icons.arrow_upward_rounded, Colors.white),
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
        Text(CurrencyFormatter.formatCurrency(amount),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildChart(Map<String, double> categoryTotals, double total) {
    List<PieChartSectionData> sections = [];
    int i = 0;
    final colors = [
      AppColors.primary,
      AppColors.deepBlue,
      AppColors.income,
      Colors.orange,
      Colors.purple,
      Colors.teal
    ];

    categoryTotals.forEach((cat, amount) {
      final percentage = (amount / total) * 100;
      sections.add(PieChartSectionData(
        color: colors[i % colors.length],
        value: amount,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
      i++;
    });

    return SizedBox(
      height: 200,
      child: PieChart(PieChartData(
          sections: sections, centerSpaceRadius: 40, sectionsSpace: 2)),
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
              const SizedBox(width: 16),
              Text(CurrencyFormatter.formatCurrency(e.value),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
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
