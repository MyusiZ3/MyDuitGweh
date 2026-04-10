import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/connectivity_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../widgets/shimmer_loading.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Method to reset search when leaving screen
  void resetSearch() {
    if (mounted) {
      setState(() {
        _searchController.clear();
        _searchQuery = "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Dompet Saya',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          titleSpacing: 24,
          toolbarHeight: 70,
          actions: [
            IconButton(
              onPressed: _showCreateWalletDialog,
              icon: Icon(Icons.add_circle_rounded,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? const Color(0xFF0A84FF) 
                      : Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 12),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 16),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Cari dompet ...',
                    hintStyle: TextStyle(color: Theme.of(context).hintColor),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Theme.of(context).hintColor, size: 20),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                            child: Icon(Icons.cancel_rounded,
                                color: Theme.of(context).hintColor, size: 18),
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // iOS Style Segmented Control
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE3E3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Theme.of(context).textTheme.titleLarge?.color,
                unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF8E8E93) // Apple System Gray for Dark
                    : Theme.of(context).hintColor,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Pribadi'),
                  Tab(text: 'Bersama'),
                  Tab(text: 'Hutang'),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<WalletModel>>(
                stream: _firestoreService.getWalletsStream(_uid),
                builder: (context, snapshot) {
                  // Only show shimmer if we are waiting for initial data and there is no data yet
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(
                        3,
                        (index) => ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 0),
                          physics: const BouncingScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, _) =>
                              const ShimmerWalletCard(),
                        ),
                      ),
                    );
                  }

                  final wallets = snapshot.data ?? [];
                  final filteredWallets = wallets.where((w) {
                    return w.walletName.toLowerCase().contains(_searchQuery);
                  }).toList();

                  final personalWallets =
                      filteredWallets.where((w) => w.isPersonal).toList();
                  final colabWallets =
                      filteredWallets.where((w) => w.isColab).toList();
                  final debtWallets =
                      filteredWallets.where((w) => w.isDebt).toList();

                  return TabBarView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildWalletList(personalWallets),
                      _buildWalletList(colabWallets),
                      _buildWalletList(debtWallets),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletList(List<WalletModel> wallets) {
    if (wallets.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: wallets.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _WalletCard(
          wallet: wallets[index],
          onTap: () => _showWalletDetails(wallets[index]),
        ),
      ),
    );
  }

  void _showCreateWalletDialog() {
    final nameController = TextEditingController();
    final debtorNameController = TextEditingController();
    final debtorPhoneController = TextEditingController();
    String selectedType = 'personal';
    String debtType = 'payable'; // 'payable' = ngutang, 'receivable' = minjamin

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Buat Dompet Baru',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTypeOption(
                        setModalState,
                        'personal',
                        'Pribadi',
                        Icons.person_outline,
                        selectedType,
                        (val) => selectedType = val),
                    const SizedBox(width: 8),
                    _buildTypeOption(
                        setModalState,
                        'colab',
                        'Bersama',
                        Icons.groups_outlined,
                        selectedType,
                        (val) => selectedType = val),
                    const SizedBox(width: 8),
                    _buildTypeOption(
                        setModalState,
                        'debt',
                        'Hutang',
                        Icons.handshake_outlined,
                        selectedType,
                        (val) => selectedType = val),
                  ],
                ),
                const SizedBox(height: 20),
                if (selectedType == 'debt') ...[
                  Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white.withOpacity(0.05) 
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Posisi Anda',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: Theme.of(context).hintColor)),
                            Row(
                              children: [
                                Expanded(
                                    child: RadioListTile<String>(
                                  title: Text('Saya Ngutang',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  value: 'payable',
                                  groupValue: debtType,
                                  onChanged: (val) =>
                                      setModalState(() => debtType = val!),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  activeColor: Theme.of(context).brightness == Brightness.dark 
                                      ? const Color(0xFF0A84FF) 
                                      : Theme.of(context).primaryColor,
                                )),
                                Expanded(
                                    child: RadioListTile<String>(
                                  title: Text('Saya Minjamin',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  value: 'receivable',
                                  groupValue: debtType,
                                  onChanged: (val) =>
                                      setModalState(() => debtType = val!),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  activeColor: Theme.of(context).brightness == Brightness.dark 
                                      ? const Color(0xFF0A84FF) 
                                      : Theme.of(context).primaryColor,
                                )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: debtorNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: 'Nama Teman / Pihak Lain',
                                filled: true,
                                fillColor: Theme.of(context).cardColor,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                                suffixIcon: IconButton(
                                    icon: Icon(Icons.contacts,
                                        color: Theme.of(context).brightness == Brightness.dark 
                                            ? const Color(0xFF0A84FF) 
                                            : Theme.of(context).primaryColor),
                                    onPressed: () async {
                                      var status =
                                          await Permission.contacts.status;
                                      if (!status.isGranted) {
                                        status =
                                            await Permission.contacts.request();
                                      }
                                      if (status.isGranted) {
                                        final allContacts =
                                            await FlutterContacts.getContacts(
                                                withProperties: true);
                                        if (!context.mounted) return;

                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (ctx) {
                                            String contactSearchQuery = "";
                                            return StatefulBuilder(
                                              builder: (ctx, setContactState) {
                                                final filteredContacts =
                                                    allContacts.where((c) {
                                                  final name = c.displayName
                                                      .toLowerCase();
                                                  final phone = c
                                                          .phones.isNotEmpty
                                                      ? c.phones.first.number
                                                          .replaceAll(' ', '')
                                                      : "";
                                                  return name.contains(
                                                          contactSearchQuery
                                                              .toLowerCase()) ||
                                                      phone.contains(
                                                          contactSearchQuery);
                                                }).toList();

                                                return Container(
                                                  height: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.8,
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).cardColor,
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                    24)),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      const SizedBox(
                                                          height: 12),
                                                      Center(
                                                        child: Container(
                                                          width: 40,
                                                          height: 4,
                                                          decoration: BoxDecoration(
                                                              color: Theme.of(context).hintColor.withOpacity(0.3),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          2)),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(24),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                'Pilih Kontak',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        20,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold)),
                                                            const SizedBox(
                                                                height: 16),
                                                            Container(
                                                              height: 48,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.15) : Theme.of(context).inputDecorationTheme.fillColor,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child: TextField(
                                                                onChanged:
                                                                    (val) {
                                                                  setContactState(
                                                                      () {
                                                                    contactSearchQuery =
                                                                        val;
                                                                  });
                                                                },
                                                                decoration:
                                                                    InputDecoration(
                                                                  hintText:
                                                                      'Cari nama atau nomor...',
                                                                  prefixIcon: Icon(Icons.search_rounded,
                                                                      color: Theme.of(context).brightness == Brightness.dark 
                                                                          ? const Color(0xFF0A84FF) 
                                                                          : Theme.of(context).primaryColor),
                                                                  border:
                                                                      InputBorder
                                                                          .none,
                                                                  contentPadding:
                                                                      EdgeInsets.symmetric(
                                                                          vertical:
                                                                              12,
                                                                          horizontal:
                                                                              16),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: ListView.builder(
                                                          itemCount:
                                                              filteredContacts
                                                                  .length,
                                                          itemBuilder:
                                                              (ctx, i) =>
                                                                  ListTile(
                                                            leading:
                                                                CircleAvatar(
                                                              backgroundColor:
                                                                  Theme.of(context).brightness == Brightness.dark 
                                                                      ? const Color(0xFF0A84FF).withOpacity(0.25) 
                                                                      : Theme.of(context).primaryColor.withOpacity(0.1),
                                                              child: Text(
                                                                  filteredContacts[i]
                                                                          .displayName
                                                                          .isNotEmpty
                                                                      ? filteredContacts[i]
                                                                              .displayName[
                                                                          0]
                                                                      : '?',
                                                                  style: TextStyle(
                                                                      color: Theme.of(context).brightness == Brightness.dark 
                                                                          ? const Color(0xFF0A84FF) 
                                                                          : Theme.of(context).primaryColor,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold)),
                                                            ),
                                                            title: Text(
                                                                filteredContacts[
                                                                        i]
                                                                    .displayName),
                                                            subtitle: Text(filteredContacts[
                                                                        i]
                                                                    .phones
                                                                    .isNotEmpty
                                                                ? filteredContacts[
                                                                        i]
                                                                    .phones
                                                                    .first
                                                                    .number
                                                                : 'Tanpa nomor HP'),
                                                            onTap: () {
                                                              setModalState(() {
                                                                debtorNameController
                                                                        .text =
                                                                    filteredContacts[
                                                                            i]
                                                                        .displayName;
                                                                if (filteredContacts[
                                                                        i]
                                                                    .phones
                                                                    .isNotEmpty) {
                                                                  debtorPhoneController
                                                                          .text =
                                                                      filteredContacts[
                                                                              i]
                                                                          .phones
                                                                          .first
                                                                          .number;
                                                                }
                                                                nameController
                                                                    .text = debtType ==
                                                                        'payable'
                                                                    ? 'Hutang ke ${filteredContacts[i].displayName}'
                                                                    : 'Piutang ${filteredContacts[i].displayName}';
                                                              });
                                                              Navigator.pop(
                                                                  ctx);
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        );
                                      } else if (status.isPermanentlyDenied) {
                                        if (!context.mounted) return;
                                        UIHelper.showErrorSnackBar(context,
                                            'Izin kontak ditolak permanen. Buka Settings untuk mengizinkan.');
                                        openAppSettings();
                                      } else {
                                        if (!context.mounted) return;
                                        UIHelper.showErrorSnackBar(context,
                                            'Izin akses kontak ditolak!');
                                      }
                                    }),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: debtorPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: 'Nomor HP (bisa via kontak)',
                                filled: true,
                                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                          ]))
                ],
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: selectedType == 'colab'
                        ? 'Nama kelompok/tujuan'
                        : selectedType == 'debt'
                            ? 'Label Catatan (Misal: Hutang Budi)'
                            : 'Nama dompet (misal: Jajan)',
                    prefixIcon: Icon(
                        selectedType == 'colab'
                            ? Icons.groups_rounded
                            : selectedType == 'debt'
                                ? Icons.receipt_long
                                : Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF0A84FF) 
                            : Theme.of(context).primaryColor),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFF0A84FF).withOpacity(0.5) 
                                : Theme.of(context).primaryColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFF0A84FF) 
                                : Theme.of(context).primaryColor, 
                            width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty) {
                        final isOnline = await ConnectivityService.isOnline();
                        final newWallet = WalletModel(
                          id: '', // Will be set by service
                          walletName: nameController.text,
                          balance: 0,
                          type: selectedType,
                          members: [_uid],
                          owner: _uid,
                          createdAt: DateTime.now(),
                          debtorName: selectedType == 'debt'
                              ? debtorNameController.text
                              : null,
                          debtorPhone: selectedType == 'debt'
                              ? debtorPhoneController.text
                              : null,
                          debtType: selectedType == 'debt' ? debtType : null,
                        );

                        if (!isOnline) {
                          _firestoreService.createWallet(newWallet);
                          if (mounted) {
                            Navigator.pop(context);
                            UIHelper.showInfoSnackBar(
                                context, 'Dompet dibuat offline');
                          }
                          return;
                        }

                        try {
                          await _firestoreService
                              .createWallet(newWallet)
                              .timeout(
                                const Duration(seconds: 10),
                                onTimeout: () =>
                                    throw TimeoutException('Timeout'),
                              );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          UIHelper.showSuccessSnackBar(context,
                              'Dompet "${nameController.text}" berhasil dibuat!');
                        } catch (e) {
                          if (mounted) {
                            if (e is TimeoutException) {
                              Navigator.pop(context);
                              UIHelper.showInfoSnackBar(context,
                                  'Koneksi lambat, dompet akan muncul saat tersambung.');
                            } else {
                              UIHelper.showErrorSnackBar(context, 'Gagal: $e');
                            }
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF0A84FF) 
                          : Theme.of(context).primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Simpan Dompet',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showJoinWalletDialog();
                    },
                    child: Text(
                        'Sudah punya kode undangan? Gabung di sini',
                        style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFF0A84FF) 
                                : Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(StateSetter setModalState, String type, String label,
      IconData icon, String current, Function(String) onSelect) {
    final isSelected = current == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: () => setModalState(() => onSelect(type)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark 
                    ? const Color(0xFF0A84FF).withOpacity(0.25) 
                    : Theme.of(context).primaryColor.withOpacity(0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected
                    ? (isDark 
                        ? const Color(0xFF0A84FF) 
                        : Theme.of(context).primaryColor)
                    : Theme.of(context).dividerColor.withOpacity(0.1),
                width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected 
                      ? (isDark ? const Color(0xFF0A84FF) : Theme.of(context).primaryColor)
                      : (isDark 
                          ? Colors.white.withOpacity(0.5) 
                          : Theme.of(context).hintColor),
                  size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: isSelected 
                          ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A84FF) : Theme.of(context).primaryColor)
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.7) : Theme.of(context).hintColor),
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinWalletDialog() {
    final codeController = TextEditingController();
    bool isChecking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF0A84FF) 
                        : Theme.of(context).primaryColor).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.group_add_rounded,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF0A84FF) 
                          : Theme.of(context).primaryColor, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Gabung Dompet Bersama',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text(
                  'Masukkan 6 digit kode undangan dari temanmu\nuntuk mulai mencatat bersama.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).hintColor, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: codeController,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF0A84FF) 
                          : Theme.of(context).primaryColor),
                  decoration: InputDecoration(
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(
                        fontSize: 28,
                        letterSpacing: 8,
                        color: Theme.of(context).hintColor.withOpacity(0.3)),
                    counterText: '',
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.05)
                        : AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFF0A84FF) 
                                : Theme.of(context).primaryColor, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 18, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isChecking
                        ? null
                        : () async {
                            if (codeController.text.length < 6) {
                              UIHelper.showErrorSnackBar(
                                  context, 'Kode harus 6 digit ya! (〜￣▽￣)〜');
                              return;
                            }
                            setModalState(() => isChecking = true);
                            final success = await _firestoreService
                                .joinWalletByCode(codeController.text, _uid);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            if (success) {
                              UIHelper.showSuccessSnackBar(context,
                                  'Berhasil bergabung! Selamat berkolaborasi');
                            } else {
                              UIHelper.showErrorSnackBar(context,
                                  'Kode tidak valid atau kamu sudah bergabung');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.dark 
                          ? const Color(0xFF0A84FF) 
                          : Theme.of(context).primaryColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isChecking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text('Gabung Sekarang',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWalletDetails(WalletModel wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(wallet.walletName,
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            wallet.isDebt
                                ? (wallet.debtType == 'payable'
                                    ? 'Hutang (Saya Ngutang)'
                                    : 'Piutang (Saya Minjamin)')
                                : wallet.isColab
                                    ? 'Dompet Bersama'
                                    : 'Dompet Pribadi',
                            style: TextStyle(
                                color: wallet.isDebt
                                    ? AppColors.warning
                                    : Theme.of(context).hintColor,
                                fontWeight: wallet.isDebt
                                    ? FontWeight.w600
                                    : FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      onSelected: (value) async {
                        if (value == 'rename') {
                          _showRenameWalletDialog(wallet);
                        } else if (value == 'delete') {
                          final confirm = await UIHelper.showConfirmDialog(
                            context: context,
                            title:
                                '${ToneManager.t('dialog_del_wallet_title')} "${wallet.walletName}"?',
                            message: ToneManager.t('dialog_del_wallet_msg'),
                          );
                          if (confirm == true) {
                            final isOnline =
                                await ConnectivityService.isOnline();
                            if (!isOnline) {
                              _firestoreService.deleteWallet(wallet.id);
                              if (mounted) {
                                Navigator.of(context).pop(); // Close sheet
                                UIHelper.showInfoSnackBar(context,
                                    'Dompet akan dihapus setelah online');
                              }
                              return;
                            }

                            try {
                              await _firestoreService
                                  .deleteWallet(wallet.id)
                                  .timeout(
                                    const Duration(seconds: 10),
                                    onTimeout: () =>
                                        throw TimeoutException('Timeout'),
                                  );
                              if (!mounted) return;
                              Navigator.of(context).pop(); // Close sheet
                              UIHelper.showSuccessSnackBar(
                                  context, 'Dompet berhasil dihapus');
                            } catch (e) {
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    UIHelper.showInfoSnackBar(context,
                                        'Proses hapus tertunda koneksi.');
                                  }
                            }
                          }
                        } else if (value == 'leave') {
                          final confirm = await UIHelper.showConfirmDialog(
                            context: context,
                            title:
                                '${ToneManager.t('dialog_leave_wallet_title')} "${wallet.walletName}"?',
                            message: ToneManager.t('dialog_leave_wallet_msg'),
                          );
                          if (confirm == true) {
                            await _firestoreService.leaveWallet(
                                wallet.id, _uid);
                            if (!mounted) return;
                            Navigator.of(context).pop(); // Close sheet
                            UIHelper.showSuccessSnackBar(
                                context, 'Berhasil keluar dari dompet.');
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (wallet.owner == _uid || !wallet.isColab) ...[
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 12),
                                Text('Ubah Nama'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded,
                                    size: 20, color: AppColors.expense),
                                SizedBox(width: 12),
                                Text('Hapus Dompet',
                                    style: TextStyle(color: AppColors.expense)),
                              ],
                            ),
                          ),
                        ] else ...[
                          const PopupMenuItem(
                            value: 'leave',
                            child: Row(
                              children: [
                                Icon(Icons.exit_to_app_rounded,
                                    size: 20, color: AppColors.expense),
                                SizedBox(width: 12),
                                Text('Keluar dari Dompet',
                                    style: TextStyle(color: AppColors.expense)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (wallet.isColab) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF0A84FF) 
                        : Theme.of(context).primaryColor).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: (Theme.of(context).brightness == Brightness.dark 
                            ? const Color(0xFF0A84FF) 
                            : Theme.of(context).primaryColor).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KODE UNDANGAN',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A84FF).withOpacity(0.9) : Theme.of(context).hintColor,
                                  letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Text(wallet.inviteCode ?? '-',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white
                                      : Theme.of(context).primaryColor)),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: wallet.inviteCode ?? ''));
                          UIHelper.showSuccessSnackBar(
                              context, 'Kode disalin ke clipboard!');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? const Color(0xFF0A84FF) 
                                : Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: (Theme.of(context).brightness == Brightness.dark 
                                      ? const Color(0xFF0A84FF) 
                                      : Theme.of(context).primaryColor).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded,
                                  size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Salin',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Member List (only for colab)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ANGGOTA',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).hintColor,
                              letterSpacing: 1)),
                      const SizedBox(height: 12),
                      ...wallet.members
                          .map((memberUid) =>
                              FutureBuilder<Map<String, dynamic>?>(
                                future:
                                    _firestoreService.getUserInfo(memberUid),
                                builder: (context, snapshot) {
                                  final name = snapshot.data?['displayName'] ??
                                      'Memuat...';
                                  final isOwner = memberUid == wallet.owner;
                                  final isMe = memberUid == _uid;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: (Theme.of(context).brightness == Brightness.dark 
                                              ? const Color(0xFF0A84FF) 
                                              : Theme.of(context).primaryColor).withOpacity(0.1),
                                          child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).brightness == Brightness.dark 
                                                      ? const Color(0xFF0A84FF) 
                                                      : Theme.of(context).primaryColor)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            isMe ? '$name (Anda)' : name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isMe
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: Theme.of(context).textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                        ),
                                        if (isOwner)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (Theme.of(context).brightness == Brightness.dark 
                                                  ? const Color(0xFF0A84FF) 
                                                  : Theme.of(context).primaryColor).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text('OWNER',
                                                style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w800,
                                                    color: Theme.of(context).brightness == Brightness.dark 
                                                        ? const Color(0xFF0A84FF) 
                                                        : Theme.of(context).primaryColor)),
                                          )
                                        else if (wallet.owner == _uid)
                                          IconButton(
                                            icon: Icon(
                                                Icons.person_remove_rounded,
                                                color: AppColors.expense,
                                                size: 18),
                                            onPressed: () async {
                                              final confirm = await UIHelper
                                                  .showConfirmDialog(
                                                context: context,
                                                title: ToneManager.t(
                                                    'dialog_kick_member_title'),
                                                message: ToneManager.t(
                                                    'dialog_kick_member_msg'),
                                              );
                                              if (confirm == true) {
                                                await _firestoreService
                                                    .kickMember(
                                                        wallet.id, memberUid);
                                                // No need to pop, StreamBuilder will update
                                              }
                                            },
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ))
                          .toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Info Hutang/Piutang
              if (wallet.isDebt) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: (wallet.debtType == 'payable'
                            ? AppColors.expense
                            : AppColors.income)
                        .withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: (wallet.debtType == 'payable'
                                ? AppColors.expense
                                : AppColors.income)
                            .withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            wallet.debtType == 'payable'
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 18,
                            color: wallet.debtType == 'payable'
                                ? AppColors.expense
                                : AppColors.income,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            wallet.debtType == 'payable'
                                ? 'SAYA NGUTANG'
                                : 'SAYA MINJAMIN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: wallet.debtType == 'payable'
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? const Color(0xFF2C2C2E) 
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.person_rounded,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? const Color(0xFF0A84FF) 
                                    : Theme.of(context).hintColor),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.debtorName?.isNotEmpty == true
                                    ? wallet.debtorName!
                                    : 'Tidak disebutkan',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              if (wallet.debtorPhone?.isNotEmpty == true)
                                Text(
                                  wallet.debtorPhone!,
                                  style: TextStyle(
                                      fontSize: 12, color: Theme.of(context).hintColor),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _firestoreService.getTransactionsStream(wallet.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final txns = snapshot.data!;
                    if (txns.isEmpty)
                      return Center(
                          child: Text('Belum ada transaksi',
                              style: TextStyle(color: Theme.of(context).hintColor)));

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: txns.length,
                      itemBuilder: (context, index) {
                        final t = txns[index];
                        return Dismissible(
                          key: Key(t.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            // Restriction: only the creator can delete their transaction
                            if (t.createdBy != _uid) {
                              UIHelper.showErrorSnackBar(context,
                                  ToneManager.t('error_not_creator_delete'));
                              return false;
                            }
                            return await UIHelper.showConfirmDialog(
                              context: context,
                              title: ToneManager.t('dialog_del_tx_title'),
                              message: ToneManager.t('dialog_del_tx_msg'),
                            );
                          },
                          onDismissed: (direction) async {
                            if (t.createdBy == _uid) {
                              await _firestoreService.deleteTransaction(t);
                              if (!context.mounted) return;
                              UIHelper.showSuccessSnackBar(
                                  context, 'Transaksi berhasil dihapus');
                            }
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.delete_outline_rounded,
                                color: Colors.white),
                          ),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (t.isIncome
                                        ? AppColors.income
                                        : AppColors.expense)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                TransactionCategory.getIconForCategory(
                                    t.category),
                                color: t.isIncome
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                            title: Text(t.category,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    DateFormat('dd MMM yyyy • HH:mm')
                                        .format(t.date),
                                    style: TextStyle(fontSize: 12)),
                                if (wallet.isColab) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Dibuat oleh: ${t.createdByName}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ]
                              ],
                            ),
                            trailing: Text(
                              '${t.isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(t.amount)}',
                              style: TextStyle(
                                color: t.isIncome
                                    ? AppColors.income
                                    : AppColors.expense,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
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

  void _showRenameWalletDialog(WalletModel wallet) {
    final nameController = TextEditingController(text: wallet.walletName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).hintColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Ubah Nama Dompet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Masukkan nama baru',
                prefixIcon:
                    Icon(Icons.edit_rounded, color: Theme.of(context).primaryColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      nameController.text != wallet.walletName) {
                    final isOnline = await ConnectivityService.isOnline();
                    if (!isOnline) {
                      _firestoreService.renameWallet(
                          wallet.id, nameController.text);
                      if (mounted) {
                        Navigator.of(context).pop(); // Pop dialog
                        Navigator.of(context).pop(); // Pop details sheet
                        UIHelper.showInfoSnackBar(
                            context, 'Nama dompet akan berubah setelah online');
                      }
                      return;
                    }

                    try {
                      await _firestoreService
                          .renameWallet(wallet.id, nameController.text)
                          .timeout(
                            const Duration(seconds: 10),
                            onTimeout: () => throw TimeoutException('Timeout'),
                          );
                      if (!mounted) return;
                      Navigator.of(context).pop(); // Pop dialog
                      Navigator.of(context).pop(); // Pop details sheet
                      UIHelper.showSuccessSnackBar(context,
                          'Nama dompet berhasil diubah ke "${nameController.text}"!');
                    } catch (e) {
                      if (mounted) {
                        if (e is TimeoutException) {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          UIHelper.showInfoSnackBar(
                              context, 'Perubahan nama tertunda koneksi.');
                        } else {
                          UIHelper.showErrorSnackBar(context, 'Gagal: $e');
                        }
                      }
                    }
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Simpan Perubahan',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 80, color: Theme.of(context).hintColor.withOpacity(0.3)),
              const SizedBox(height: 20),
              Text(
                ToneManager.t('wallet_empty_title'),
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                ToneManager.t('wallet_empty_msg'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                height: 52,
                child: ElevatedButton(
                  onPressed: _showCreateWalletDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A84FF) : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Buat Dompet',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onTap;

  const _WalletCard({required this.wallet, required this.onTap});

  Color _getCardAccent(BuildContext context) {
    if (wallet.isDebt) {
      return wallet.debtType == 'payable'
          ? AppColors.expense
          : AppColors.income;
    }
    if (wallet.isColab) { return (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0A84FF) : AppColors.primary); }
    
    // In dark mode, use a slightly lighter primary color for icons if the primary is too dark
    final primary = Theme.of(context).primaryColor;
    if (Theme.of(context).brightness == Brightness.dark) {
      // Return a lighter version or specific vibrant blue for iOS feel
      return const Color(0xFF0A84FF); // iOS Vibrant Blue
    }
    return primary;
  }

  IconData get _cardIcon {
    if (wallet.isDebt) return Icons.handshake_rounded;
    if (wallet.isColab) return Icons.group_rounded;
    return Icons.account_balance_wallet_rounded;
  }

  String get _subtitle {
    if (wallet.isDebt) {
      final label = wallet.debtType == 'payable' ? 'Hutang' : 'Piutang';
      final name = wallet.debtorName?.isNotEmpty == true
          ? ' · ${wallet.debtorName}'
          : '';
      return '$label$name';
    }
    if (wallet.isColab) return 'Bersama · ${wallet.members.length} anggota';
    return 'Dompet Pribadi';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCardAccent(context).withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_cardIcon, color: _getCardAccent(context), size: 24),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.walletName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Balance & Badge
                Flexible(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatCurrency(wallet.balance),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: wallet.isDebt && wallet.debtType == 'payable'
                              ? AppColors.expense
                              : Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (wallet.isColab)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.deepBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'BERSAMA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepBlue,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: Theme.of(context).hintColor.withOpacity(0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
