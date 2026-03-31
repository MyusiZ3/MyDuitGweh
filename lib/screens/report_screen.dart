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

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            onPressed: () => _showExportDialog(context),
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: StreamBuilder<List<WalletModel>>(
        stream: _firestoreService.getWalletsStream(_uid),
        builder: (context, walletSnapshot) {
          if (!walletSnapshot.hasData) {
            return const LoadingWidget();
          }

          if (walletSnapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada data untuk ditampilkan',
                style: TextStyle(color: AppColors.textHint),
              ),
            );
          }

          final wallets = walletSnapshot.data!;
          final walletIds = wallets.map((w) => w.id).toList();

          double totalBalance = 0;
          for (final w in wallets) {
            totalBalance += w.balance;
          }

          return StreamBuilder<List<TransactionModel>>(
            stream: _firestoreService.getLatestTransactions(
                walletIds, limit: 50),
            builder: (context, txnSnapshot) {
              double totalIncome = 0;
              double totalExpense = 0;
              Map<String, double> categoryTotals = {};

              if (txnSnapshot.hasData) {
                for (final txn in txnSnapshot.data!) {
                  if (txn.isIncome) {
                    totalIncome += txn.amount;
                  } else {
                    totalExpense += txn.amount;
                  }
                  categoryTotals[txn.category] =
                      (categoryTotals[txn.category] ?? 0) + txn.amount;
                }
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildSummaryCards(
                        totalBalance, totalIncome, totalExpense),
                    const SizedBox(height: 28),
                    _buildCategoryBreakdown(categoryTotals),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(
      double balance, double income, double expense) {
    return Column(
      children: [
        // Balance card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Saldo',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                CurrencyFormatter.formatCurrency(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Income + Expense row
        Row(
          children: [
            Expanded(
              child: _buildMiniCard(
                'Pemasukan',
                income,
                AppColors.income,
                Icons.arrow_upward_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniCard(
                'Pengeluaran',
                expense,
                AppColors.expense,
                Icons.arrow_downward_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniCard(
      String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatCurrency(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(Map<String, double> categoryTotals) {
    if (categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total =
        sorted.fold<double>(0, (sum, e) => sum + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Breakdown Kategori',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: sorted.map((entry) {
              final percentage =
                  total > 0 ? (entry.value / total * 100) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        TransactionCategory.getIconForCategory(
                            entry.key),
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor:
                                  AppColors.surfaceVariant,
                              valueColor:
                                  const AlwaysStoppedAnimation(
                                      AppColors.primary),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatCurrency(
                              entry.value),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  Future<void> _showExportDialog(BuildContext context) async {
    DateTimeRange selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    
    // Get all unique categories for filter
    List<String> allCategories = [
      'All', 
      ...TransactionCategory.incomeCategories,
      ...TransactionCategory.expenseCategories,
    ].toSet().toList(); // toSet() to remove potential duplicates like 'Lainnya'
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
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export Laporan PDF', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              
              // Date Range Picker
              const Text('Pilih Rentang Waktu', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    initialDateRange: selectedDateRange,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDateRange = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.surfaceVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text('${DateFormat('dd/MM/yy').format(selectedDateRange.start)} - ${DateFormat('dd/MM/yy').format(selectedDateRange.end)}'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Category Multi-select
              const Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      setModalState(() {
                        if (cat == 'All') {
                          selectedCategories = ['All'];
                        } else {
                          selectedCategories.remove('All');
                          if (selected) {
                            selectedCategories.add(cat);
                          } else {
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
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isExporting ? null : () async {
                    setModalState(() => isExporting = true);
                    
                    try {
                      // 1. Get Wallet IDs
                      final wallets = await _firestoreService.getWalletsStream(_uid).first;
                      final walletIds = wallets.map((w) => w.id).toList();
                      
                      if (walletIds.isEmpty) throw 'Kamu tidak memiliki dompet.';

                      // 2. Fetch filtered transactions
                      final txns = await _firestoreService.getFilteredTransactions(
                        walletIds: walletIds,
                        startDate: selectedDateRange.start,
                        endDate: selectedDateRange.end,
                        categories: selectedCategories,
                      );
                      
                      if (txns.isEmpty) {
                        throw 'Tidak ada transaksi ditemukan pada rentang waktu ini.';
                      }

                      // 3. Calc totals
                      double income = 0;
                      double expense = 0;
                      for (var t in txns) {
                        if (t.isIncome) income += t.amount;
                        else expense += t.amount;
                      }

                      // 4. Generate PDF
                      await PdfService.generateAndPrintReport(
                        transactions: txns,
                        startDate: selectedDateRange.start,
                        endDate: selectedDateRange.end,
                        selectedCategories: selectedCategories,
                        totalIncome: income,
                        totalExpense: expense,
                      );
                      
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      print('EXPORT ERROR: $e');
                      String msg = e.toString();
                      if (msg.contains('failed-precondition') || msg.contains('index')) {
                        msg = 'Indeks Firestore sedang dibuat atau diperlukan. Silakan cek terminal dan klik link yang tersedia.';
                      }
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg.replaceFirst('Exception: ', '').replaceFirst('error: ', '')),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setModalState(() => isExporting = false);
                    }
                  },
                  child: isExporting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Download PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
