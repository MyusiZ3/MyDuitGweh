import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _selectedType = 'expense';
  String? _selectedCategory;
  String? _selectedWalletId;
  bool _isLoading = false;
  List<WalletModel> _wallets = [];

  @override
  void initState() {
    super.initState();
    _loadWallets();
  }

  Future<void> _loadWallets() async {
    _firestoreService.getWalletsStream(_uid).listen((wallets) {
      if (mounted) {
        setState(() {
          _wallets = wallets;
          if (_selectedWalletId == null && wallets.isNotEmpty) {
            _selectedWalletId = wallets.first.id;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (amountText.isEmpty || _selectedCategory == null || _selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lengkapi semua field ya!'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final transaction = TransactionModel(
        id: '',
        walletId: _selectedWalletId!,
        amount: double.parse(amountText),
        type: _selectedType,
        category: _selectedCategory!,
        note: _noteController.text.trim(),
        createdBy: _uid,
        date: DateTime.now(),
      );

      await _firestoreService.addTransaction(transaction);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Transaksi berhasil disimpan! ✅'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString()}'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = TransactionCategory.getCategoriesForType(_selectedType);

    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Tambah Transaksi', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Type toggle
            _buildTypeToggle(),
            const SizedBox(height: 20),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: 'Rp ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),

            // Category dropdown
            _buildDropdown<String>(
              value: _selectedCategory,
              hint: 'Pilih Kategori',
              icon: Icons.category_outlined,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 12),

            // Wallet dropdown
            _buildDropdown<String>(
              value: _selectedWalletId,
              hint: 'Pilih Dompet',
              icon: Icons.account_balance_wallet_outlined,
              items: _wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.walletName))).toList(),
              onChanged: (val) => setState(() => _selectedWalletId = val),
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Catatan (opsional)',
                prefixIcon: Icon(Icons.note_outlined, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Simpan Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        Expanded(child: _buildTypeButton('expense', 'Pengeluaran', Icons.arrow_downward_rounded, AppColors.expense)),
        const SizedBox(width: 12),
        Expanded(child: _buildTypeButton('income', 'Pemasukan', Icons.arrow_upward_rounded, AppColors.income)),
      ],
    );
  }

  Widget _buildTypeButton(String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() { _selectedType = type; _selectedCategory = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textHint, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? color : AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({T? value, required String hint, required IconData icon, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, isExpanded: true,
          hint: Row(children: [Icon(icon, color: AppColors.textHint, size: 20), const SizedBox(width: 12), Text(hint, style: const TextStyle(color: AppColors.textHint))]),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textHint),
          items: items, onChanged: onChanged,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
        ),
      ),
    );
  }
}
