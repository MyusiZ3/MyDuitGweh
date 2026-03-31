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
          const Text(
            'TOTAL SALDO BERSIH', 
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatCurrency(balance),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 0.5),
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
                _buildMiniStat('Pemasukan', income, Icons.arrow_downward_rounded, Colors.white),
                Container(width: 1, height: 24, color: Colors.white24),
                _buildMiniStat('Pengeluaran', expense, Icons.arrow_upward_rounded, Colors.white),
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

  void _showExportDialog() {
    // Basic implementation for now
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Laporan'),
        content: const Text('Fitur export ke PDF akan segera hadir!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }
}
