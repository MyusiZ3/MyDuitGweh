import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/connectivity_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';

class AddTransactionScreen extends StatefulWidget {
  final double? initialAmount;
  final String? initialNote;
  final String? initialCategory;
  final String? initialType;

  const AddTransactionScreen({
    super.key,
    this.initialAmount,
    this.initialNote,
    this.initialCategory,
    this.initialType,
  });

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
    // Pre-fill if values are passed
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!.toInt().toString();
    }
    if (widget.initialNote != null) _noteController.text = widget.initialNote!;

    // Safer category pre-fill: only set if it exists in the available list for the selected type
    if (widget.initialType != null) _selectedType = widget.initialType!;
    final availableCategories =
        TransactionCategory.getCategoriesForType(_selectedType);
    if (widget.initialCategory != null &&
        availableCategories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory;
    }

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
    if (amountText.isEmpty ||
        _selectedCategory == null ||
        _selectedWalletId == null) {
      UIHelper.showErrorSnackBar(context, 'Lengkapi semua field yaa!');
      return;
    }

    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final isOnline = await ConnectivityService.isOnline();
      final transaction = TransactionModel(
        id: '',
        walletId: _selectedWalletId!,
        amount: double.parse(amountText),
        type: _selectedType,
        category: _selectedCategory!,
        note: _noteController.text.trim(),
        createdBy: _uid,
        createdByName:
            FirebaseAuth.instance.currentUser?.displayName ?? 'Anonim',
        date: DateTime.now(),
      );

      if (!isOnline) {
        // Mode Offline: Langsung simpan ke cache dan tutup
        _firestoreService.addTransaction(
            transaction); // Jangan di-await agar tidak nge-hang jika stream error
        if (mounted) {
          Navigator.pop(context);
          UIHelper.showInfoSnackBar(context, 'Transaksi disimpan offline');
        }
        return;
      }

      // Mode Online: Tunggu konfirmasi (timeout if necessary)
      await _firestoreService.addTransaction(transaction).timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException('Gagal menghubungi server.'),
          );

      if (mounted) {
        Navigator.pop(context);
        UIHelper.showSuccessSnackBar(
            context, ToneManager.t('snack_tx_success'));
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e is TimeoutException
            ? 'Koneksi lambat, transaksi akan disinkronkan di latar belakang.'
            : 'Gagal simpan: ${e.toString()} ❌';

        if (e is TimeoutException) {
          Navigator.pop(context);
          UIHelper.showInfoSnackBar(context, errorMsg);
        } else {
          UIHelper.showErrorSnackBar(context, errorMsg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Tambah Transaksi',
                style: Theme.of(context).textTheme.headlineMedium),
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
                prefixStyle: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),

            // Category selector (Searchable)
            InkWell(
              onTap: _showCategoryPicker,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedCategory == null
                          ? Icons.category_outlined
                          : TransactionCategory.getIconForCategory(
                              _selectedCategory!),
                      color: _selectedCategory == null
                          ? AppColors.textHint
                          : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedCategory ?? 'Pilih Kategori',
                        style: TextStyle(
                          color: _selectedCategory == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.search_rounded,
                        size: 20, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Wallet dropdown
            _buildDropdown<String>(
              value: _selectedWalletId,
              hint: 'Pilih Dompet',
              icon: Icons.account_balance_wallet_outlined,
              items: _wallets
                  .map((w) =>
                      DropdownMenuItem(value: w.id, child: Text(w.walletName)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedWalletId = val),
            ),
            const SizedBox(height: 12),

            // Note
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: 'Catatan (opsional)',
                prefixIcon:
                    Icon(Icons.note_outlined, color: AppColors.textHint),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Simpan Transaksi',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
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
        Expanded(
            child: _buildTypeButton('expense', 'Pengeluaran',
                Icons.arrow_downward_rounded, AppColors.expense)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildTypeButton('income', 'Pemasukan',
                Icons.arrow_upward_rounded, AppColors.income)),
      ],
    );
  }

  Widget _buildTypeButton(
      String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedType = type;
        _selectedCategory = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? color : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? color : AppColors.textHint, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : AppColors.textSecondary,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    final categories = TransactionCategory.getCategoriesForType(_selectedType);
    final searchController = TextEditingController();
    List<String> filteredCategories = List.from(categories);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari kategori...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setModalState(
                                  () => filteredCategories = categories);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      filteredCategories = categories
                          .where((c) =>
                              c.toLowerCase().contains(val.toLowerCase()))
                          .toList();
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredCategories.length,
                  itemBuilder: (context, index) {
                    final category = filteredCategories[index];
                    final isSelected = _selectedCategory == category;
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          TransactionCategory.getIconForCategory(category),
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        category,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() => _selectedCategory = category);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>(
      {T? value,
      required String hint,
      required IconData icon,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Row(children: [
            Icon(icon, color: AppColors.textHint, size: 20),
            const SizedBox(width: 12),
            Text(hint, style: const TextStyle(color: AppColors.textHint))
          ]),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textHint),
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: Colors.white,
        ),
      ),
    );
  }
}
