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
        title: const Text('Laporan'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.download_rounded, color: AppColors.primary),
            tooltip: 'Export Laporan',
          ),
        ],
      ),
      body: StreamBuilder<List<WalletModel>>(
        stream: _firestoreService.getWalletsStream(_uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: LoadingWidget());
          }

          final walletIds = snapshot.data!.map((w) => w.id).toList();

          return StreamBuilder<List<TransactionModel>>(
            stream: _firestoreService.getFilteredTransactionsStream(
              walletIds: walletIds,
              startDate: selectedDateRange.start,
              endDate: selectedDateRange.end,
            ),
            builder: (context, txnSnapshot) {
              if (txnSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: LoadingWidget());
              }

              final transactions = txnSnapshot.data ?? [];
              
              double totalIncome = 0;
              double totalExpense = 0;
              Map<String, double> categoryTotals = {};

              for (var txn in transactions) {
                if (txn.isIncome) {
                  totalIncome += txn.amount;
                } else {
                  totalExpense += txn.amount;
                  categoryTotals[txn.category] = (categoryTotals[txn.category] ?? 0) + txn.amount;
                }
              }

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildDateSelector(),
                  const SizedBox(height: 24),
                  _buildSummaryCards(totalIncome - totalExpense, totalIncome, totalExpense),
                  const SizedBox(height: 24),
                  _buildCharts(totalIncome, totalExpense, categoryTotals),
                  const SizedBox(height: 24),
                  _buildCategoryBreakdown(categoryTotals),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: selectedDateRange,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() => selectedDateRange = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Periode Laporan', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                Text(
                  '${DateFormat('dd MMM').format(selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange.end)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double balance, double income, double expense) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Saldo', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                CurrencyFormatter.formatCurrency(balance),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMiniCard('Pemasukan', income, AppColors.income, Icons.arrow_upward_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildMiniCard('Pengeluaran', expense, AppColors.expense, Icons.arrow_downward_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatCurrency(amount),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCharts(double income, double expense, Map<String, double> categoryTotals) {
    if (income == 0 && expense == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Column(
        children: [
          const Text('Alokasi Dana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  if (income > 0)
                    PieChartSectionData(
                      color: AppColors.income,
                      value: income,
                      title: 'IN',
                      radius: 25,
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (expense > 0)
                    PieChartSectionData(
                      color: AppColors.expense,
                      value: expense,
                      title: 'OUT',
                      radius: 25,
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chartLegend('Pemasukan', AppColors.income),
              const SizedBox(width: 24),
              _chartLegend('Pengeluaran', AppColors.expense),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildCategoryBreakdown(Map<String, double> categoryTotals) {
    if (categoryTotals.isEmpty) return const SizedBox.shrink();

    final sorted = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (sum, e) => sum + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Breakdown Pengeluaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...sorted.map((e) {
          final percent = (e.value / total) * 100;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(CurrencyFormatter.formatCurrency(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    backgroundColor: AppColors.expense.withOpacity(0.1),
                    color: AppColors.expense,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showExportDialog() {
    List<String> allCategories = ['All', ...TransactionCategory.incomeCategories, ...TransactionCategory.expenseCategories].toSet().toList();
    List<String> selectedCategories = ['All'];
    bool isExporting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Laporan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text('Pilih Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCategories.map((cat) {
                  final isSelected = selectedCategories.contains(cat);
                  return FilterChip(
                    label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    onSelected: (selected) {
                      setModalState(() {
                        if (cat == 'All') {
                          if (selected) selectedCategories = ['All'];
                        } else {
                          selectedCategories.remove('All');
                          if (selected) selectedCategories.add(cat);
                          else {
                            selectedCategories.remove(cat);
                            if (selectedCategories.isEmpty) selectedCategories.add('All');
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: isExporting ? null : () async {
                    setModalState(() => isExporting = true);
                    final wallets = await _firestoreService.getWalletsStream(_uid).first;
                    final walletIds = wallets.map((w) => w.id).toList();
                    final txns = await _firestoreService.getFilteredTransactions(
                      walletIds: walletIds, startDate: selectedDateRange.start,
                      endDate: selectedDateRange.end, categories: selectedCategories,
                    );
                    
                    double inc = 0, exp = 0;
                    for (var t in txns) { if (t.isIncome) inc += t.amount; else exp += t.amount; }

                    await PdfService.generateAndPrintReport(
                      transactions: txns, startDate: selectedDateRange.start,
                      endDate: selectedDateRange.end, selectedCategories: selectedCategories,
                      totalIncome: inc, totalExpense: exp,
                    );
                    setModalState(() => isExporting = false);
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Download PDF'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: isExporting ? null : () async {
                    setModalState(() => isExporting = true);
                    final wallets = await _firestoreService.getWalletsStream(_uid).first;
                    final walletIds = wallets.map((w) => w.id).toList();
                    final txns = await _firestoreService.getFilteredTransactions(
                      walletIds: walletIds, startDate: selectedDateRange.start,
                      endDate: selectedDateRange.end, categories: selectedCategories,
                    );
                    await PdfService.generateAndExportCSV(
                      transactions: txns, startDate: selectedDateRange.start, endDate: selectedDateRange.end,
                    );
                    setModalState(() => isExporting = false);
                  },
                  icon: const Icon(Icons.table_view_rounded, color: Colors.green),
                  label: const Text('Download CSV (Excel)', style: TextStyle(color: Colors.green)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
