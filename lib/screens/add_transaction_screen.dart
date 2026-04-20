import 'dart:async';
import 'package:flutter/cupertino.dart';
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
import '../utils/currency_formatter.dart';

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
            : 'Gagal simpan: ${e.toString()}';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom +
              (bottomPadding > 0 ? bottomPadding : 32)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Tambah Transaksi',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    )),
            const SizedBox(height: 24),

            // Type toggle
            _buildTypeToggle(),
            const SizedBox(height: 20),

            // Amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1C1C1E) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.05),
                ),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: Theme.of(context).hintColor.withOpacity(0.2),
                  ),
                  prefixIcon: Container(
                    width: 42,
                    alignment: Alignment.centerLeft,
                    child: Text('Rp',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        )),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category selector (Searchable)
            InkWell(
              onTap: _showCategoryPicker,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_selectedCategory == null
                                ? Theme.of(context).hintColor
                                : (isDark
                                    ? const Color(0xFF0A84FF)
                                    : AppColors.primary))
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedCategory == null
                            ? CupertinoIcons.square_grid_2x2
                            : TransactionCategory.getIconForCategory(
                                _selectedCategory!),
                        color: _selectedCategory == null
                            ? AppColors.textHint
                            : (isDark
                                ? const Color(0xFF0A84FF)
                                : AppColors.primary),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _selectedCategory ?? 'Pilih Kategori',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedCategory == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: _selectedCategory == null
                              ? Theme.of(context).hintColor
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 20,
                        color: Theme.of(context).hintColor.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Wallet selector (Searchable)
            InkWell(
              onTap: _showWalletPicker,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_selectedWalletId == null
                                ? Theme.of(context).hintColor
                                : (isDark
                                    ? const Color(0xFF32D74B)
                                    : const Color(0xFF34C759)))
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        CupertinoIcons.creditcard,
                        color: _selectedWalletId == null
                            ? AppColors.textHint
                            : (isDark
                                ? const Color(0xFF32D74B)
                                : const Color(0xFF34C759)),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _wallets
                            .firstWhere((w) => w.id == _selectedWalletId,
                                orElse: () => WalletModel(
                                    id: '',
                                    walletName: 'Pilih Dompet',
                                    type: '',
                                    balance: 0,
                                    owner: '',
                                    createdAt: DateTime.now(),
                                    members: []))
                            .walletName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: _selectedWalletId == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: _selectedWalletId == null
                              ? Theme.of(context).hintColor
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 20,
                        color: Theme.of(context).hintColor.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1C1C1E) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.05),
                ),
              ),
              child: TextField(
                controller: _noteController,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Catatan (opsional)',
                  hintStyle: TextStyle(
                      color: Theme.of(context).hintColor.withOpacity(0.4)),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.doc_text,
                      color: Theme.of(context).hintColor.withOpacity(0.7),
                      size: 20,
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Simpan Transaksi',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2)),
              ),
            ),
            const SizedBox(height: 12),
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
                CupertinoIcons.arrow_down_circle, AppColors.expense)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildTypeButton('income', 'Pemasukan',
                CupertinoIcons.arrow_up_circle, AppColors.income)),
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
          color: isSelected
              ? color.withOpacity(0.1)
              : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : AppColors.surfaceVariant),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = TransactionCategory.getCategoriesForType(_selectedType);
    final searchController = TextEditingController();
    List<String> filteredCategories = List.from(categories);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // iOS Drag Handle & Title
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Kategori',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoSearchTextField(
                  controller: searchController,
                  placeholder: 'Cari kategori...',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
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
              const SizedBox(height: 16),

              Expanded(
                child: filteredCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.search,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 16),
                            Text(
                              ToneManager.t('category_not_found'),
                              style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredCategories.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 50,
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        ),
                        itemBuilder: (context, index) {
                          final category = filteredCategories[index];
                          final isSelected = _selectedCategory == category;
                          final iconData = TransactionCategory.getIconForCategory(category);
                          
                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedCategory = category);
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark
                                              ? const Color(0xFF0A84FF).withOpacity(0.2)
                                              : const Color(0xFF007AFF).withOpacity(0.1))
                                          : (isDark
                                              ? const Color(0xFF2C2C2E)
                                              : Colors.grey[100]),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF))
                                          : (isDark ? Colors.white70 : Colors.black54),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      CupertinoIcons.checkmark_alt,
                                      color: Color(0xFF007AFF),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
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

  void _showWalletPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchController = TextEditingController();
    List<WalletModel> filteredWallets = List.from(_wallets);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // iOS Drag Handle & Title
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Dompet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoSearchTextField(
                  controller: searchController,
                  placeholder: 'Cari dompet...',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  onChanged: (val) {
                    setModalState(() {
                      filteredWallets = _wallets
                          .where((w) => w.walletName
                              .toLowerCase()
                              .contains(val.toLowerCase()))
                          .toList();
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: filteredWallets.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.creditcard,
                                size: 48,
                                color: isDark ? Colors.white24 : Colors.black12),
                            const SizedBox(height: 16),
                            Text(
                              ToneManager.t('wallet_not_found'),
                              style: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredWallets.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 50,
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                        ),
                        itemBuilder: (context, index) {
                          final wallet = filteredWallets[index];
                          final isSelected = _selectedWalletId == wallet.id;
                          
                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedWalletId = wallet.id);
                              Navigator.pop(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark
                                              ? const Color(0xFF32D74B).withOpacity(0.2)
                                              : const Color(0xFF34C759).withOpacity(0.1))
                                          : (isDark
                                              ? const Color(0xFF2C2C2E)
                                              : Colors.grey[100]),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.creditcard_fill,
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF32D74B) : const Color(0xFF34C759))
                                          : (isDark ? Colors.white70 : Colors.black54),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          wallet.walletName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.formatCurrency(wallet.balance),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      CupertinoIcons.checkmark_alt,
                                      color: Color(0xFF34C759),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
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
}
