import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/connectivity_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import '../utils/currency_formatter.dart';
import '../utils/category_matcher.dart';

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
  Timer? _debounceTimer;

  String _selectedType = 'expense';
  String? _selectedCategory;
  String? _selectedWalletId;
  String? _targetWalletId;
  bool _isLoading = false;
  List<WalletModel> _wallets = [];
  final Map<String, int> _usageMap = {};

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

    _noteController.addListener(_onNoteChanged);
    _loadWallets();
  }

  void _onNoteChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (_noteController.text.isNotEmpty && _selectedCategory == null) {
        final matched = CategoryMatcher.matchCategory(_noteController.text);
        if (matched != null) {
          final categories =
              TransactionCategory.getCategoriesForType(_selectedType);
          if (categories.contains(matched)) {
            setState(() => _selectedCategory = matched);
          }
        }
      }
    });
  }

  Future<void> _loadWallets() async {
    try {
      final txSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('createdBy', isEqualTo: _uid)
          .limit(100)
          .get();

      for (var doc in txSnapshot.docs) {
        final data = doc.data();
        final wId = data['walletId'] as String?;
        final tId = data['targetWalletId'] as String?;
        if (wId != null && wId.isNotEmpty) {
          _usageMap[wId] = (_usageMap[wId] ?? 0) + 1;
        }
        if (tId != null && tId.isNotEmpty) {
          _usageMap[tId] = (_usageMap[tId] ?? 0) + 1;
        }
      }
    } catch (_) {}

    _firestoreService.getWalletsStream(_uid).listen((wallets) {
      if (mounted) {
        // Sort wallets based on frequency of usage (most frequently used first)
        wallets.sort((a, b) {
          final countA = _usageMap[a.id] ?? 0;
          final countB = _usageMap[b.id] ?? 0;
          if (countA != countB) {
            return countB.compareTo(countA);
          }
          return a.walletName.compareTo(b.walletName);
        });

        setState(() {
          _wallets = wallets;
          if (_selectedWalletId == null && wallets.isNotEmpty) {
            _selectedWalletId = wallets.first.id;
          }
          if (_targetWalletId == null && wallets.length > 1) {
            _targetWalletId = wallets[1].id;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (_selectedType == 'transfer') {
      if (amountText.isEmpty ||
          _selectedWalletId == null ||
          _targetWalletId == null) {
        UIHelper.showErrorSnackBar(context, 'Lengkapi semua field yaa!');
        return;
      }
      if (_selectedWalletId == _targetWalletId) {
        UIHelper.showErrorSnackBar(context, 'Dompet asal dan tujuan tidak boleh sama!');
        return;
      }
    } else {
      if (amountText.isEmpty ||
          _selectedCategory == null ||
          _selectedWalletId == null) {
        UIHelper.showErrorSnackBar(context, 'Lengkapi semua field yaa!');
        return;
      }
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
        category: _selectedType == 'transfer' ? 'Pindah Dana' : _selectedCategory!,
        note: _noteController.text.trim(),
        createdBy: _uid,
        createdByName:
            FirebaseAuth.instance.currentUser?.displayName ?? 'Anonim',
        date: DateTime.now(),
        targetWalletId: _selectedType == 'transfer' ? _targetWalletId : null,
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
    final sectionColor = isDark ? const Color(0xFF27272A) : Colors.white;
    final backgroundColor =
        isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);

    final Color activeColor = _selectedType == 'expense'
        ? AppColors.expense
        : (_selectedType == 'income'
            ? AppColors.income
            : AppColors.pastelBlue);

    return Container(
      padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom +
              (bottomPadding > 0 ? bottomPadding : 32)),
      decoration: BoxDecoration(
        color: backgroundColor,
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
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Tambah Transaksi',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                )),
            const SizedBox(height: 20),

            // Type toggle
            _buildTypeToggle(),
            const SizedBox(height: 20),

            // Amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: sectionColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: activeColor,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    color: activeColor.withOpacity(0.3),
                  ),
                  prefixIcon: Container(
                    width: 42,
                    alignment: Alignment.centerLeft,
                    child: Text('Rp',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: activeColor,
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
            if (_selectedType != 'transfer') ...[
              InkWell(
                onTap: _showCategoryPicker,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: sectionColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_selectedCategory == null
                                  ? (isDark
                                      ? const Color(0xFFA1A1AA)
                                      : const Color(0xFF71717A))
                                  : activeColor)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _selectedCategory == null
                              ? CupertinoIcons.square_grid_2x2
                              : TransactionCategory.getIconForCategory(
                                  _selectedCategory!),
                          color: _selectedCategory == null
                              ? (isDark
                                  ? const Color(0xFFA1A1AA)
                                  : const Color(0xFF71717A))
                              : activeColor,
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
                                ? (isDark
                                    ? const Color(0xFFA1A1AA)
                                    : const Color(0xFF71717A))
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1C1C1E)),
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Wallet selector (Searchable) - "Dari Dompet" if transfer
            InkWell(
              onTap: () => _showWalletPicker(isSource: true),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: sectionColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.income.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.creditcard,
                        color: AppColors.income,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _selectedWalletId == null
                            ? (_selectedType == 'transfer'
                                ? 'Pilih Dompet Asal'
                                : 'Pilih Dompet')
                            : _wallets
                                .firstWhere((w) => w.id == _selectedWalletId,
                                    orElse: () => WalletModel(
                                        id: '',
                                        walletName: _selectedType == 'transfer'
                                            ? 'Pilih Dompet Asal'
                                            : 'Pilih Dompet',
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
                              ? (isDark
                                  ? const Color(0xFFA1A1AA)
                                  : const Color(0xFF71717A))
                              : (isDark
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E)),
                        ),
                      ),
                    ),
                    Icon(CupertinoIcons.chevron_right,
                        size: 20,
                        color: isDark ? Colors.white38 : Colors.black38),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Target Wallet selector (only if type is transfer)
            if (_selectedType == 'transfer') ...[
              InkWell(
                onTap: () => _showWalletPicker(isSource: false),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: sectionColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.income.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.creditcard_fill,
                          color: AppColors.income,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _targetWalletId == null
                              ? 'Pilih Dompet Tujuan'
                              : _wallets
                                  .firstWhere((w) => w.id == _targetWalletId,
                                      orElse: () => WalletModel(
                                          id: '',
                                          walletName: 'Pilih Dompet Tujuan',
                                          type: '',
                                          balance: 0,
                                          owner: '',
                                          createdAt: DateTime.now(),
                                          members: []))
                                  .walletName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _targetWalletId == null
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: _targetWalletId == null
                                ? (isDark
                                    ? const Color(0xFFA1A1AA)
                                    : const Color(0xFF71717A))
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF1C1C1E)),
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right,
                          size: 20,
                          color: isDark ? Colors.white38 : Colors.black38),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Note
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: sectionColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _noteController,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Catatan (opsional)',
                  hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFFA1A1AA)
                        : const Color(0xFF71717A),
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.only(right: 14),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark
                              ? const Color(0xFFA1A1AA)
                              : const Color(0xFF71717A))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.doc_text,
                      color: isDark
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF71717A),
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
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF27272A)
                      : const Color(0xFF18181B),
                  foregroundColor: Colors.white,
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
        const SizedBox(width: 8),
        Expanded(
            child: _buildTypeButton('income', 'Pemasukan',
                CupertinoIcons.arrow_up_circle, AppColors.income)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildTypeButton('transfer', 'Pindah Dana',
                CupertinoIcons.arrow_right_arrow_left, AppColors.pastelBlue)),
      ],
    );
  }

  Widget _buildTypeButton(
      String type, String label, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedType = type;
        _selectedCategory = type == 'transfer' ? 'Pindah Dana' : null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.12)
              : (isDark
                  ? const Color(0xFF27272A)
                  : const Color(0xFFF4F4F5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? color
                  : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.04)),
              width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected
                    ? color
                    : (isDark
                        ? const Color(0xFFA1A1AA)
                        : const Color(0xFF71717A)),
                size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? color
                          : (isDark
                              ? const Color(0xFFA1A1AA)
                              : const Color(0xFF71717A)),
                      fontSize: 11)),
            ),
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
      builder: (context) {
        final safeBottom = MediaQuery.of(context).padding.bottom;
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // iOS Drag Handle & Title
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih Kategori',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoSearchTextField(
                    controller: searchController,
                    placeholder: 'Cari kategori...',
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E)),
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
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black12),
                              const SizedBox(height: 16),
                              Text(
                                ToneManager.t('category_not_found'),
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: safeBottom > 0 ? safeBottom + 24 : 24,
                          ),
                          itemCount: filteredCategories.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            indent: 50,
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                          ),
                          itemBuilder: (context, index) {
                            final category = filteredCategories[index];
                            final isSelected = _selectedCategory == category;
                            final iconData =
                                TransactionCategory.getIconForCategory(category);
                            final activeColor = _selectedType == 'expense'
                                ? AppColors.expense
                                : (_selectedType == 'income'
                                    ? AppColors.income
                                    : AppColors.pastelBlue);

                            return InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _selectedCategory = category);
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? activeColor.withOpacity(0.15)
                                            : (isDark
                                                ? const Color(0xFF27272A)
                                                : const Color(0xFFF4F4F5)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        iconData,
                                        color: isSelected
                                            ? activeColor
                                            : (isDark
                                                ? const Color(0xFFA1A1AA)
                                                : const Color(0xFF71717A)),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w400,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1C1C1E),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        CupertinoIcons.checkmark_alt,
                                        color: activeColor,
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
        );
      },
    );
  }

  void _showWalletPicker({bool isSource = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchController = TextEditingController();
    List<WalletModel> filteredWallets = List.from(_wallets);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final safeBottom = MediaQuery.of(context).padding.bottom;
        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // iOS Drag Handle & Title
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isSource ? 'Pilih Dompet Asal' : 'Pilih Dompet Tujuan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoSearchTextField(
                    controller: searchController,
                    placeholder: 'Cari dompet...',
                    style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1C1C1E)),
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
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.black12),
                              const SizedBox(height: 16),
                              Text(
                                ToneManager.t('wallet_not_found'),
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38,
                                    fontSize: 15),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: safeBottom > 0 ? safeBottom + 24 : 24,
                          ),
                          itemCount: filteredWallets.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            indent: 50,
                            color: isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                          ),
                          itemBuilder: (context, index) {
                            final wallet = filteredWallets[index];
                            final isSelected = isSource
                                ? _selectedWalletId == wallet.id
                                : _targetWalletId == wallet.id;
                            final activeColor = isSource
                                ? const Color(0xFF34D399)
                                : AppColors.primary;

                            final isMostUsed = index == 0 &&
                                (_usageMap[wallet.id] ?? 0) > 0;

                            return InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (isSource) {
                                    _selectedWalletId = wallet.id;
                                  } else {
                                    _targetWalletId = wallet.id;
                                  }
                                });
                                Navigator.pop(context);
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? activeColor.withOpacity(0.15)
                                            : (isDark
                                                ? const Color(0xFF27272A)
                                                : const Color(0xFFF4F4F5)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.creditcard_fill,
                                        color: isSelected
                                            ? activeColor
                                            : (isDark
                                                ? const Color(0xFFA1A1AA)
                                                : const Color(0xFF71717A)),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  wallet.walletName,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1C1C1E),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isMostUsed) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF3F3F46)
                                                        : const Color(
                                                            0xFFE4E4E7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    'Sering dipakai',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? const Color(
                                                              0xFFA1A1AA)
                                                          : const Color(
                                                              0xFF71717A),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            CurrencyFormatter.formatCurrency(
                                                wallet.balance),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? const Color(0xFFA1A1AA)
                                                  : const Color(0xFF71717A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        CupertinoIcons.checkmark_alt,
                                        color: activeColor,
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
        );
      },
    );
  }
}
