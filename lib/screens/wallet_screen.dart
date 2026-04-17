import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/connectivity_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/debt_model.dart';
import '../services/debt_service.dart';
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
  final DebtService _debtService = DebtService();
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
          centerTitle: true,
          title: Text(ToneManager.t('wallet_list_title'),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.4)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          titleSpacing: 24,
          toolbarHeight: 70,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _showCreateWalletDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        (isDark ? const Color(0xFF0A84FF) : AppColors.primary)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.plus,
                    size: 26,
                    color: isDark ? const Color(0xFF0A84FF) : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
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
                  color: isDark
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFF767680).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 16),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: ToneManager.t('wallet_search_hint'),
                    hintStyle: TextStyle(
                      color: Theme.of(context).hintColor.withOpacity(0.5),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(CupertinoIcons.search,
                        color: Theme.of(context).hintColor.withOpacity(0.5),
                        size: 18),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                            child: Icon(CupertinoIcons.xmark_circle_fill,
                                color: Theme.of(context).hintColor, size: 18),
                          ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // iOS Style Segmented Control (Pribadi, Bersama, Hutang)
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFF767680).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF636366) : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor:
                    isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
                tabs: [
                  Tab(text: ToneManager.t('tab_pribadi')),
                  Tab(text: ToneManager.t('tab_bersama')),
                  Tab(text: ToneManager.t('tab_hutang')),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const BouncingScrollPhysics(),
                children: [
                  // Tab Pribadi
                  StreamBuilder<List<WalletModel>>(
                    stream: _firestoreService.getWalletsStream(_uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 0),
                          physics: const BouncingScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, _) =>
                              const ShimmerWalletCard(),
                        );
                      }
                      final wallets = snapshot.data ?? [];
                      final personalWallets = wallets
                          .where((w) =>
                              w.walletName
                                  .toLowerCase()
                                  .contains(_searchQuery) &&
                              w.isPersonal)
                          .toList();
                      return _buildWalletList(personalWallets);
                    },
                  ),
                  // Tab Bersama
                  StreamBuilder<List<WalletModel>>(
                    stream: _firestoreService.getWalletsStream(_uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 0),
                          physics: const BouncingScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, _) =>
                              const ShimmerWalletCard(),
                        );
                      }
                      final wallets = snapshot.data ?? [];
                      final colabWallets = wallets
                          .where((w) =>
                              w.walletName
                                  .toLowerCase()
                                  .contains(_searchQuery) &&
                              w.isColab)
                          .toList();
                      return _buildWalletList(colabWallets);
                    },
                  ),
                  // Tab Hutang
                  StreamBuilder<List<DebtModel>>(
                    stream: _debtService.getUserDebts(_uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 0),
                          physics: const BouncingScrollPhysics(),
                          itemCount: 4,
                          itemBuilder: (context, _) =>
                              const ShimmerWalletCard(),
                        );
                      }
                      final debts = snapshot.data ?? [];
                      final filteredDebts = debts
                          .where((d) =>
                              d.title.toLowerCase().contains(_searchQuery))
                          .toList();
                      return _buildDebtList(filteredDebts);
                    },
                  ),
                ],
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
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 120),
      physics: const BouncingScrollPhysics(),
      itemCount: wallets.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
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
    final totalAmountController = TextEditingController();
    String? selectedWalletId;
    String selectedType = 'personal';
    String debtType = 'payable'; // 'payable' = ngutang, 'receivable' = minjamin

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setModalState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sbCtx).size.height * 0.7,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(sbCtx).viewInsets.bottom +
                  (MediaQuery.of(sbCtx).viewInsets.bottom > 0
                      ? 16
                      : MediaQuery.of(sbCtx).padding.bottom + 24),
            ),
            decoration: BoxDecoration(
              color: Theme.of(sbCtx).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sbCtx).hintColor.withOpacity(0.3),
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
                          CupertinoIcons.person,
                          selectedType,
                          (val) => selectedType = val),
                      const SizedBox(width: 8),
                      _buildTypeOption(
                          setModalState,
                          'colab',
                          'Bersama',
                          CupertinoIcons.person_2,
                          selectedType,
                          (val) => selectedType = val),
                      const SizedBox(width: 8),
                      _buildTypeOption(
                          setModalState,
                          'debt',
                          'Hutang',
                          CupertinoIcons.doc_plaintext,
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
                            color: Theme.of(sbCtx).brightness == Brightness.dark
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
                                      color: Theme.of(sbCtx).hintColor)),
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
                                    onChanged: (val) {
                                      setModalState(() {
                                        debtType = val!;
                                        if (debtorNameController
                                            .text.isNotEmpty) {
                                          nameController.text =
                                              'Hutang ke ${debtorNameController.text}';
                                        }
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    activeColor: Theme.of(sbCtx).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF0A84FF)
                                        : Theme.of(sbCtx).primaryColor,
                                  )),
                                  Expanded(
                                      child: RadioListTile<String>(
                                    title: Text('Saya Minjamin',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                    value: 'receivable',
                                    groupValue: debtType,
                                    onChanged: (val) {
                                      setModalState(() {
                                        debtType = val!;
                                        if (debtorNameController
                                            .text.isNotEmpty) {
                                          nameController.text =
                                              'Piutang ${debtorNameController.text}';
                                        }
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    activeColor: Theme.of(sbCtx).brightness ==
                                            Brightness.dark
                                        ? const Color(0xFF0A84FF)
                                        : Theme.of(sbCtx).primaryColor,
                                  )),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: debtorNameController,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val.isNotEmpty) {
                                      nameController.text =
                                          debtType == 'payable'
                                              ? 'Hutang ke $val'
                                              : 'Piutang $val';
                                    } else {
                                      nameController.text = '';
                                    }
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Nama Teman / Pihak Lain',
                                  filled: true,
                                  fillColor: Theme.of(sbCtx).cardColor,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none),
                                  suffixIcon: IconButton(
                                      icon: Icon(
                                          CupertinoIcons
                                              .person_crop_circle_fill_badge_plus,
                                          color: Theme.of(sbCtx).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF0A84FF)
                                              : Theme.of(sbCtx).primaryColor),
                                      onPressed: () async {
                                        var status =
                                            await Permission.contacts.status;
                                        if (!status.isGranted) {
                                          status = await Permission.contacts
                                              .request();
                                        }
                                        if (status.isGranted) {
                                          final allContacts =
                                              await FlutterContacts.getContacts(
                                                  withProperties: true);
                                          if (!sbCtx.mounted) return;

                                          showModalBottomSheet(
                                            context: sbCtx,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (contactModalCtx) {
                                              String contactSearchQuery = "";
                                              return StatefulBuilder(
                                                builder: (contactSbCtx,
                                                    setContactState) {
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
                                                    height: MediaQuery.of(
                                                                contactSbCtx)
                                                            .size
                                                            .height *
                                                        0.8,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Theme.of(contactSbCtx)
                                                              .cardColor,
                                                      borderRadius:
                                                          const BorderRadius
                                                              .vertical(
                                                              top: Radius
                                                                  .circular(
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
                                                                color: Theme.of(
                                                                        contactSbCtx)
                                                                    .hintColor
                                                                    .withOpacity(
                                                                        0.3),
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
                                                              TextField(
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
                                                                  filled: true,
                                                                  fillColor: Theme.of(contactSbCtx)
                                                                              .brightness ==
                                                                          Brightness
                                                                              .dark
                                                                      ? const Color(
                                                                          0xFF1C1C1E)
                                                                      : const Color(
                                                                              0xFF767680)
                                                                          .withOpacity(
                                                                              0.12),
                                                                  hintStyle:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Theme.of(
                                                                            contactSbCtx)
                                                                        .hintColor
                                                                        .withOpacity(
                                                                            0.5),
                                                                  ),
                                                                  prefixIcon: Icon(
                                                                      CupertinoIcons
                                                                          .search,
                                                                      size: 20,
                                                                      color: Theme.of(contactSbCtx).brightness ==
                                                                              Brightness
                                                                                  .dark
                                                                          ? const Color(
                                                                              0xFF0A84FF)
                                                                          : Theme.of(contactSbCtx)
                                                                              .primaryColor),
                                                                  border:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                    borderSide:
                                                                        BorderSide
                                                                            .none,
                                                                  ),
                                                                  enabledBorder:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                    borderSide:
                                                                        BorderSide
                                                                            .none,
                                                                  ),
                                                                  focusedBorder:
                                                                      OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                    borderSide: BorderSide(
                                                                        color: Theme.of(contactSbCtx)
                                                                            .primaryColor,
                                                                        width:
                                                                            1),
                                                                  ),
                                                                  contentPadding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          12,
                                                                      horizontal:
                                                                          16),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child:
                                                              ListView.builder(
                                                            itemCount:
                                                                filteredContacts
                                                                    .length,
                                                            itemBuilder:
                                                                (ctx, i) =>
                                                                    ListTile(
                                                              leading:
                                                                  CircleAvatar(
                                                                backgroundColor: Theme.of(contactSbCtx)
                                                                            .brightness ==
                                                                        Brightness
                                                                            .dark
                                                                    ? const Color(
                                                                            0xFF0A84FF)
                                                                        .withOpacity(
                                                                            0.25)
                                                                    : Theme.of(
                                                                            contactSbCtx)
                                                                        .primaryColor
                                                                        .withOpacity(
                                                                            0.1),
                                                                child: Text(
                                                                    filteredContacts[i]
                                                                            .displayName
                                                                            .isNotEmpty
                                                                        ? filteredContacts[i].displayName[
                                                                            0]
                                                                        : '?',
                                                                    style: TextStyle(
                                                                        color: Theme.of(contactSbCtx).brightness == Brightness.dark
                                                                            ? const Color(
                                                                                0xFF0A84FF)
                                                                            : Theme.of(contactSbCtx)
                                                                                .primaryColor,
                                                                        fontWeight:
                                                                            FontWeight.bold)),
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
                                                                setModalState(
                                                                    () {
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
                                                                        .text = filteredContacts[
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
                                                                    contactModalCtx);
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
                                          if (!sbCtx.mounted) return;
                                          UIHelper.showErrorSnackBar(sbCtx,
                                              'Izin kontak ditolak permanen. Buka Settings untuk mengizinkan.');
                                          openAppSettings();
                                        } else {
                                          if (!sbCtx.mounted) return;
                                          UIHelper.showErrorSnackBar(sbCtx,
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
                                  fillColor: Theme.of(sbCtx)
                                      .inputDecorationTheme
                                      .fillColor,
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
                              ? CupertinoIcons.person_2
                              : selectedType == 'debt'
                                  ? CupertinoIcons.doc_text
                                  : CupertinoIcons.creditcard,
                          color: Theme.of(sbCtx).brightness == Brightness.dark
                              ? const Color(0xFF0A84FF)
                              : Theme.of(sbCtx).primaryColor),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color:
                                  Theme.of(sbCtx).brightness == Brightness.dark
                                      ? const Color(0xFF0A84FF).withOpacity(0.5)
                                      : Theme.of(sbCtx).primaryColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color:
                                  Theme.of(sbCtx).brightness == Brightness.dark
                                      ? const Color(0xFF0A84FF)
                                      : Theme.of(sbCtx).primaryColor,
                              width: 2)),
                    ),
                  ),
                  if (selectedType == 'debt') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: totalAmountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixIcon: UnconstrainedBox(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.creditcard,
                                    size: 20,
                                    color: Theme.of(sbCtx).primaryColor),
                                const SizedBox(width: 8),
                                Text('Rp',
                                    style: TextStyle(
                                        color: Theme.of(sbCtx).primaryColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor:
                            Theme.of(sbCtx).inputDecorationTheme.fillColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<WalletModel>>(
                      stream: _firestoreService.getWalletsStream(_uid),
                      builder: (sbCtx, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final wallets =
                            snapshot.data!.where((w) => !w.isDebt).toList();
                        return DropdownButtonFormField<String>(
                          value: selectedWalletId,
                          hint: Text(ToneManager.t('debt_payment_wallet_hint')),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(sbCtx).cardColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                          ),
                          items: wallets.map((w) {
                            return DropdownMenuItem(
                              value: w.id,
                              child: Text(w.walletName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() => selectedWalletId = val);
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isNotEmpty) {
                          final isOnline = await ConnectivityService.isOnline();

                          if (selectedType == 'debt') {
                            if (totalAmountController.text.isEmpty ||
                                selectedWalletId == null ||
                                debtorNameController.text.isEmpty) {
                              if (!sbCtx.mounted) return;
                              UIHelper.showErrorSnackBar(
                                  sbCtx, 'Lengkapi semua field hutang!');
                              return;
                            }
                            final amount =
                                double.tryParse(totalAmountController.text) ??
                                    0;

                            if (!isOnline) {
                              if (!sbCtx.mounted) return;
                              UIHelper.showInfoSnackBar(sbCtx,
                                  'Penambahan hutang butuh koneksi internet');
                              return;
                            }

                            try {
                              final debtTypePayload =
                                  debtType == 'payable' ? 'utang' : 'piutang';
                              final currentUser =
                                  FirebaseAuth.instance.currentUser;
                              final currentUserName =
                                  currentUser?.displayName ?? "User";

                              final debtTitle = nameController.text;

                              await _debtService.addDebt(
                                currentUserId: _uid,
                                currentUserName: currentUserName,
                                type: debtTypePayload,
                                title: debtTitle,
                                totalAmount: amount,
                                walletId: selectedWalletId!,
                              );
                              if (!sbCtx.mounted) return;
                              Navigator.pop(sbCtx);
                              UIHelper.showSuccessSnackBar(
                                  sbCtx, 'Berhasil mencatat $debtTitle!');
                            } catch (e) {
                              if (sbCtx.mounted) {
                                UIHelper.showErrorSnackBar(sbCtx, 'Gagal: $e');
                              }
                            }
                            return;
                          }

                          final newWallet = WalletModel(
                            id: '', // Will be set by service
                            walletName: nameController.text,
                            balance: 0,
                            type: selectedType,
                            members: [_uid],
                            owner: _uid,
                            createdAt: DateTime.now(),
                          );

                          if (!isOnline) {
                            _firestoreService.createWallet(newWallet);
                            if (!sbCtx.mounted) return;
                            Navigator.pop(sbCtx);
                            UIHelper.showInfoSnackBar(
                                sbCtx, 'Dompet dibuat offline');
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
                            if (!sbCtx.mounted) return;
                            Navigator.pop(sbCtx);
                            UIHelper.showSuccessSnackBar(sbCtx,
                                'Dompet "${nameController.text}" berhasil dibuat!');
                          } catch (e) {
                            if (sbCtx.mounted) {
                              if (e is TimeoutException) {
                                Navigator.pop(sbCtx);
                                UIHelper.showInfoSnackBar(sbCtx,
                                    'Koneksi lambat, dompet akan muncul saat tersambung.');
                              } else {
                                UIHelper.showErrorSnackBar(sbCtx, 'Gagal: $e');
                              }
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF0A84FF)
                                : Theme.of(context).primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                          selectedType == 'debt'
                              ? 'Simpan Hutang/Piutang'
                              : 'Simpan Dompet',
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
                      child: Text('Sudah punya kode undangan? Gabung di sini',
                          style: TextStyle(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
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
                      ? (isDark
                          ? const Color(0xFF0A84FF)
                          : Theme.of(context).primaryColor)
                      : (isDark
                          ? Colors.white.withOpacity(0.5)
                          : Theme.of(context).hintColor),
                  size: 24),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: isSelected
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0A84FF)
                              : Theme.of(context).primaryColor)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.7)
                              : Theme.of(context).hintColor),
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
      enableDrag: true,
      showDragHandle: true,
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
                            : Theme.of(context).primaryColor)
                        .withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.person_badge_plus,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0A84FF)
                          : Theme.of(context).primaryColor,
                      size: 36),
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
                      color: Theme.of(context).hintColor,
                      fontSize: 13,
                      height: 1.5),
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF0A84FF)
                                    : Theme.of(context).primaryColor,
                            width: 2)),
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
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
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

  void _showEditDebtDialog(DebtModel debt) {
    final titleController = TextEditingController(text: debt.title);
    final amountController =
        TextEditingController(text: debt.totalAmount.toStringAsFixed(0));
    DateTime? selectedDate = debt.dueDate;
    bool isSaving = false;
    final String typeLabel = debt.isUtang ? 'Hutang' : 'Piutang';

    UIHelper.showPremiumBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (sbCtx, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 16,
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
                    color: Theme.of(sbCtx).hintColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                ToneManager.t('debt_edit_title')
                    .replaceAll('{type}', typeLabel),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: ToneManager.t('debt_label_title'),
                  prefixIcon: const Icon(CupertinoIcons.pencil),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: ToneManager.t('debt_history_table_amount'),
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(CupertinoIcons.creditcard),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: sbCtx,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(sbCtx).dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.calendar),
                      const SizedBox(width: 12),
                      Text(selectedDate != null
                          ? DateFormat('dd MMM yyyy').format(selectedDate!)
                          : 'Pilih Tanggal'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newAmount =
                                  double.tryParse(amountController.text);
                              if (newAmount == null ||
                                  titleController.text.isEmpty) {
                                UIHelper.showErrorSnackBar(sbCtx,
                                    ToneManager.t('debt_error_incomplete'));
                                return;
                              }

                              setModalState(() => isSaving = true);
                              try {
                                await _debtService.updateDebt(
                                  userId: _uid,
                                  debtId: debt.id,
                                  title: titleController.text,
                                  newTotalAmount: newAmount,
                                  dueDate: selectedDate,
                                );
                                if (sbCtx.mounted) {
                                  UIHelper.showSuccessSnackBar(
                                      sbCtx,
                                      ToneManager.t('debt_success_update')
                                          .replaceAll('{type}', typeLabel));
                                  Navigator.pop(sbCtx);
                                }
                              } catch (e) {
                                if (sbCtx.mounted) {
                                  setModalState(() => isSaving = false);
                                  UIHelper.showErrorSnackBar(
                                      sbCtx, 'Gagal: $e');
                                }
                              } finally {
                                if (sbCtx.mounted && isSaving) {
                                  // Fallback safety for offline hanging
                                  Future.delayed(const Duration(seconds: 8),
                                      () {
                                    if (sbCtx.mounted && isSaving) {
                                      setModalState(() => isSaving = false);
                                    }
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const CupertinoActivityIndicator(
                              color: Colors.white)
                          : Text(ToneManager.t('profile_save_btn'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => Navigator.pop(sbCtx),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(sbCtx).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                Theme.of(sbCtx).dividerColor.withOpacity(0.12)),
                      ),
                      child: Center(
                        child: Text(
                          ToneManager.t('dialog_no'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Theme.of(sbCtx).hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIncreaseDebtDialog(DebtModel debt) {
    final amountController = TextEditingController();
    String? selectedWalletId;
    bool isSaving = false;
    final String typeLabel = debt.isUtang ? 'Hutang' : 'Piutang';

    UIHelper.showPremiumBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (sbCtx, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 24,
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
                    color: Theme.of(sbCtx).hintColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                ToneManager.t('debt_increase_title')
                    .replaceAll('{type}', typeLabel),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                debt.isUtang
                    ? ToneManager.t('debt_increase_msg_utang')
                    : ToneManager.t('debt_increase_msg_piutang'),
                style: TextStyle(color: Theme.of(sbCtx).hintColor),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: ToneManager.t('debt_increase_label'),
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(CupertinoIcons.creditcard),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
              // Wallet Selection
              StreamBuilder<List<WalletModel>>(
                stream: _firestoreService.getWalletsStream(_uid),
                builder: (streamCtx, snapshot) {
                  final wallets =
                      (snapshot.data ?? []).where((w) => w.isPersonal).toList();
                  return DropdownButtonFormField<String>(
                    value: selectedWalletId,
                    decoration: InputDecoration(
                      labelText: ToneManager.t('debt_select_wallet'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    items: wallets
                        .map((w) => DropdownMenuItem(
                              value: w.id,
                              child: Text(w.walletName),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedWalletId = val),
                  );
                },
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(amountController.text);
                              if (amount == null ||
                                  amount <= 0 ||
                                  selectedWalletId == null) {
                                UIHelper.showErrorSnackBar(sbCtx,
                                    ToneManager.t('debt_error_incomplete'));
                                return;
                              }

                              setModalState(() => isSaving = true);
                              try {
                                await _debtService.increaseDebt(
                                  userId: _uid,
                                  userName: FirebaseAuth
                                          .instance.currentUser?.displayName ??
                                      'User',
                                  debt: debt,
                                  additionalAmount: amount,
                                  walletId: selectedWalletId!,
                                );
                                if (sbCtx.mounted) {
                                  UIHelper.showSuccessSnackBar(
                                      sbCtx,
                                      ToneManager.t('debt_success_increase')
                                          .replaceAll('{type}', typeLabel));
                                  Navigator.pop(sbCtx);
                                }
                              } catch (e) {
                                if (sbCtx.mounted) {
                                  setModalState(() => isSaving = false);
                                  UIHelper.showErrorSnackBar(
                                      sbCtx, 'Gagal: $e');
                                }
                              } finally {
                                if (sbCtx.mounted && isSaving) {
                                  // Fallback safety for offline hanging
                                  Future.delayed(const Duration(seconds: 8),
                                      () {
                                    if (sbCtx.mounted && isSaving) {
                                      setModalState(() => isSaving = false);
                                    }
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const CupertinoActivityIndicator(
                              color: Colors.white)
                          : Text(ToneManager.t('btn_add_nominal'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => Navigator.pop(sbCtx),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(sbCtx).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                Theme.of(sbCtx).dividerColor.withOpacity(0.12)),
                      ),
                      child: Center(
                        child: Text(
                          ToneManager.t('dialog_no'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Theme.of(sbCtx).hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteDebt(DebtModel debt) async {
    final String typeLabel = debt.isUtang ? 'Hutang' : 'Piutang';

    final confirmed = await UIHelper.showConfirmDialog(
      context: context,
      title: ToneManager.t('debt_delete_confirm_title')
          .replaceAll('{type}', typeLabel),
      message: ToneManager.t('debt_delete_confirm_msg')
          .replaceAll('{type}', typeLabel)
          .replaceAll('{title}', debt.title),
      confirmText: ToneManager.t('profile_logout').contains('Keluar')
          ? 'Hapus'
          : 'Delete', // Fallback if no specific delete btn
      cancelText: ToneManager.t('dialog_no'),
      isDangerous: true,
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        await _debtService.deleteDebt(_uid, debt.id);
        if (!mounted) return;
        UIHelper.showSuccessSnackBar(
            context,
            ToneManager.t('debt_success_delete')
                .replaceAll('{type}', typeLabel));
      } catch (e) {
        if (!mounted) return;
        UIHelper.showErrorSnackBar(context, 'Gagal menghapus: $e');
      }
    }
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
                      icon: Icon(CupertinoIcons.ellipsis,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : (Theme.of(context).textTheme.bodyLarge?.color ??
                                  Colors.black87)),
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
                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // Close sheet
                              UIHelper.showInfoSnackBar(context,
                                  'Dompet akan dihapus setelah online');
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
                                UIHelper.showInfoSnackBar(
                                    context, 'Proses hapus tertunda koneksi.');
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
                                Icon(CupertinoIcons.pencil, size: 20),
                                SizedBox(width: 12),
                                Text('Ubah Nama'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.trash,
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
                                Icon(CupertinoIcons.square_arrow_right,
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
                            : Theme.of(context).primaryColor)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: (Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF0A84FF)
                                : Theme.of(context).primaryColor)
                            .withOpacity(0.2)),
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
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF0A84FF).withOpacity(0.9)
                                      : Theme.of(context).hintColor,
                                  letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Text(wallet.inviteCode ?? '-',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
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
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF0A84FF)
                                    : Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? const Color(0xFF0A84FF)
                                          : Theme.of(context).primaryColor)
                                      .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(CupertinoIcons.doc_on_doc,
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
                      ...wallet.members.map((memberUid) => FutureBuilder<
                              Map<String, dynamic>?>(
                          future: _firestoreService.getUserInfo(memberUid),
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?['displayName'] ?? 'Memuat...';
                            final isOwner = memberUid == wallet.owner;
                            final isMe = memberUid == _uid;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: (Theme.of(context)
                                                    .brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF0A84FF)
                                            : Theme.of(context).primaryColor)
                                        .withOpacity(0.1),
                                    child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFF0A84FF)
                                                    : Theme.of(context)
                                                        .primaryColor)),
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
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                      ),
                                    ),
                                  ),
                                  if (isOwner)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF0A84FF)
                                                : Theme.of(context)
                                                    .primaryColor)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('OWNER',
                                          style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF0A84FF)
                                                  : Theme.of(context)
                                                      .primaryColor)),
                                    )
                                  else if (wallet.owner == _uid)
                                    IconButton(
                                      icon: Icon(
                                          CupertinoIcons.person_badge_minus,
                                          color: AppColors.expense,
                                          size: 18),
                                      onPressed: () async {
                                        final confirm =
                                            await UIHelper.showConfirmDialog(
                                          context: context,
                                          title: ToneManager.t(
                                              'dialog_kick_member_title'),
                                          message: ToneManager.t(
                                              'dialog_kick_member_msg'),
                                        );
                                        if (confirm == true) {
                                          await _firestoreService.kickMember(
                                              wallet.id, memberUid);
                                          // No need to pop, StreamBuilder will update
                                        }
                                      },
                                    ),
                                ],
                              ),
                            );
                          })),
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
                                ? CupertinoIcons.arrow_up_circle
                                : CupertinoIcons.arrow_down_circle,
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
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(CupertinoIcons.person_fill,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
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
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor),
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
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final txns = snapshot.data!;
                    if (txns.isEmpty) {
                      return Center(
                          child: Text('Belum ada transaksi',
                              style: TextStyle(
                                  color: Theme.of(context).hintColor)));
                    }

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
                              if (!mounted) return;
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
                            child:
                                Icon(CupertinoIcons.trash, color: Colors.white),
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
                                style: TextStyle(fontWeight: FontWeight.bold)),
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
                prefixIcon: Icon(CupertinoIcons.pencil,
                    color: Theme.of(context).primaryColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor)),
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
                      if (!context.mounted) return;
                      Navigator.of(context).pop(); // Pop dialog
                      Navigator.of(context).pop(); // Pop details sheet
                      UIHelper.showInfoSnackBar(
                          context, 'Nama dompet akan berubah setelah online');
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
              Icon(CupertinoIcons.creditcard,
                  size: 80,
                  color: Theme.of(context).hintColor.withOpacity(0.3)),
              const SizedBox(height: 20),
              Text(
                ToneManager.t('wallet_empty_title'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0A84FF)
                            : Theme.of(context).primaryColor,
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

  Widget _buildDebtList(List<DebtModel> debts) {
    if (debts.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 120),
      physics: const BouncingScrollPhysics(),
      itemCount: debts.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _DebtCard(
          debt: debts[index],
          onTap: () => _showDebtDetails(debts[index]),
          onEdit: () => _showEditDebtDialog(debts[index]),
          onDelete: () => _deleteDebt(debts[index]),
          onIncrease: () => _showIncreaseDebtDialog(debts[index]),
        ),
      ),
    );
  }

  void _showDebtDetails(DebtModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => _DebtDetailsSheet(
          debt: debt,
          scrollController: scrollController,
          firestoreService: _firestoreService,
          debtService: _debtService,
          currentUserId: _uid,
          onEdit: () => _showEditDebtDialog(debt),
          onDelete: () => _deleteDebt(debt),
          onIncrease: () => _showIncreaseDebtDialog(debt),
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
    if (wallet.isColab) {
      return (Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A84FF)
          : AppColors.primary);
    }

    // In dark mode, use a slightly lighter primary color for icons if the primary is too dark
    final primary = Theme.of(context).primaryColor;
    if (Theme.of(context).brightness == Brightness.dark) {
      // Return a lighter version or specific vibrant blue for iOS feel
      return const Color(0xFF0A84FF); // iOS Vibrant Blue
    }
    return primary;
  }

  IconData get _cardIcon {
    if (wallet.isDebt) return CupertinoIcons.rectangle_stack_person_crop;
    if (wallet.isColab) return CupertinoIcons.person_2_fill;
    return CupertinoIcons.creditcard_fill;
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
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ).copyWith(
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.05 : 0.08),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCardAccent(context).withOpacity(
                        Theme.of(context).brightness == Brightness.dark
                            ? 0.2
                            : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child:
                      Icon(_cardIcon, color: _getCardAccent(context), size: 24),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        wallet.walletName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
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
                          color: Theme.of(context).hintColor.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Trailing part: Balance & Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
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
                        ),
                        if (wallet.isColab)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'BERSAMA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.blueAccent
                                        : AppColors.deepBlue)
                                    .withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: Theme.of(context).hintColor.withOpacity(0.3),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrease;

  const _DebtCard({
    required this.debt,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = debt.totalAmount - debt.paidAmount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        debt.type == 'utang' ? AppColors.expense : AppColors.income;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ).copyWith(
        border: Border.all(
          color:
              Theme.of(context).dividerColor.withOpacity(isDark ? 0.05 : 0.08),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon Container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    debt.type == 'utang'
                        ? CupertinoIcons.arrow_down_right_square_fill
                        : CupertinoIcons.arrow_up_right_square_fill,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        debt.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sisa: ${CurrencyFormatter.formatCurrency(remaining)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: accentColor.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Trailing part: Amount & Status
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatCurrency(debt.totalAmount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (debt.status == 'completed'
                                    ? AppColors.income
                                    : Colors.orange)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            debt.status == 'completed'
                                ? 'Lunas'
                                : 'Belum Lunas',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: debt.status == 'completed'
                                  ? AppColors.income
                                  : Colors.orange,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(CupertinoIcons.ellipsis_vertical,
                          size: 18,
                          color: Theme.of(context).hintColor.withOpacity(0.3)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (value) {
                        if (value == 'increase') {
                          onIncrease();
                        } else if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.pencil, size: 18),
                              const SizedBox(width: 12),
                              Text(
                                  'Edit ${debt.isUtang ? 'Hutang' : 'Piutang'}'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.trash,
                                  size: 18, color: AppColors.expense),
                              const SizedBox(width: 12),
                              Text(
                                  'Hapus ${debt.isUtang ? 'Hutang' : 'Piutang'}',
                                  style: const TextStyle(
                                      color: AppColors.expense)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DebtDetailsSheet extends StatelessWidget {
  final DebtModel debt;
  final ScrollController scrollController;
  final FirestoreService firestoreService;
  final DebtService debtService;
  final String currentUserId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onIncrease;

  const _DebtDetailsSheet({
    required this.debt,
    required this.scrollController,
    required this.firestoreService,
    required this.debtService,
    required this.currentUserId,
    required this.onEdit,
    required this.onDelete,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = debt.totalAmount - debt.paidAmount;
    final accentColor = debt.isUtang ? AppColors.expense : AppColors.income;

    return Container(
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
                      Text(debt.title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        debt.isUtang
                            ? 'Hutang (Tagihan)'
                            : 'Piutang (Peminjaman)',
                        style: TextStyle(
                            color: accentColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(CupertinoIcons.ellipsis),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) {
                    if (value == 'increase') {
                      onIncrease();
                    } else if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'increase',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.plus_circle, size: 20),
                          SizedBox(width: 12),
                          Text('Tambah Nominal'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.pencil, size: 20),
                          SizedBox(width: 12),
                          Text('Ubah Detail'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.trash,
                              size: 20, color: AppColors.expense),
                          SizedBox(width: 12),
                          Text('Hapus Catatan',
                              style: TextStyle(color: AppColors.expense)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Summary Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildSummaryItem(context, 'Total', debt.totalAmount,
                    Theme.of(context).hintColor),
                const SizedBox(width: 12),
                _buildSummaryItem(
                    context, 'Terbayar', debt.paidAmount, AppColors.income),
                const SizedBox(width: 12),
                _buildSummaryItem(context, 'Sisa', remaining, accentColor),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(CupertinoIcons.list_bullet, size: 18),
                SizedBox(width: 8),
                Text('Riwayat Transaksi',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: firestoreService.getTransactionsByDebtId(debt.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CupertinoActivityIndicator(),
                        const SizedBox(height: 16),
                        const Text('Memuat riwayat...',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Gagal memuat: ${snapshot.error}',
                        style: const TextStyle(
                            color: AppColors.expense, fontSize: 12)),
                  );
                }

                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.doc_text,
                            size: 40,
                            color:
                                Theme.of(context).hintColor.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Belum ada transaksi',
                            style:
                                TextStyle(color: Theme.of(context).hintColor)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (tx.type == 'income'
                                  ? AppColors.income
                                  : AppColors.expense)
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          tx.type == 'income'
                              ? CupertinoIcons.arrow_down_left
                              : CupertinoIcons.arrow_up_right,
                          size: 16,
                          color: tx.type == 'income'
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                      ),
                      title: Text(tx.category,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(tx.date),
                          style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.formatCurrency(tx.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: tx.type == 'income'
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Allow edit/delete for all debt transactions
                          PopupMenuButton<String>(
                            icon: Icon(CupertinoIcons.ellipsis_vertical,
                                size: 16,
                                color: Theme.of(context)
                                    .hintColor
                                    .withOpacity(0.4)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                                if (val == 'edit') {
                                  _showEditDebtTransactionDialog(
                                      context, tx, debt);
                                } else if (val == 'delete') {
                                  _deleteDebtTransaction(context, tx, debt);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(CupertinoIcons.pencil, size: 16),
                                      SizedBox(width: 8),
                                      Text(ToneManager.t('debt_tx_edit_title'),
                                          style: TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(CupertinoIcons.trash,
                                          size: 16, color: AppColors.expense),
                                      SizedBox(width: 8),
                                      Text(
                                          ToneManager.t('dialog_logout_msg')
                                                  .contains('keluar')
                                              ? 'Hapus'
                                              : 'Delete',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.expense)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (remaining > 0)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      UIHelper.showPremiumBottomSheet(
                        context: context,
                        child: _DebtPaymentModal(
                          debt: debt,
                          firestoreService: firestoreService,
                          debtService: debtService,
                          currentUserId: currentUserId,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                        ToneManager.t('nav_manual').contains('Input')
                            ? 'Bayar Cicilan'
                            : 'Pay Installment',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      BuildContext context, String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).hintColor,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                CurrencyFormatter.formatCurrency(amount),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDebtTransactionDialog(
      BuildContext context, TransactionModel transaction, DebtModel debt) {
    final amountController =
        TextEditingController(text: transaction.amount.toStringAsFixed(0));
    bool isSaving = false;

    UIHelper.showPremiumBottomSheet(
      context: context,
      child: StatefulBuilder(
        builder: (sbCtx, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 16,
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
                    color: Theme.of(sbCtx).hintColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                ToneManager.t('debt_history_edit_title'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: ToneManager.t('debt_history_table_amount'),
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(CupertinoIcons.creditcard),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 32),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newAmount =
                                  double.tryParse(amountController.text);
                              if (newAmount == null) return;

                              setModalState(() => isSaving = true);
                              try {
                                await debtService.updateDebtTransaction(
                                  userId: currentUserId,
                                  oldTransaction: transaction,
                                  debt: debt,
                                  newAmount: newAmount,
                                );
                                if (sbCtx.mounted) {
                                  UIHelper.showSuccessSnackBar(sbCtx,
                                      ToneManager.t('debt_tx_success_update'));
                                  Navigator.pop(sbCtx);
                                }
                              } catch (e) {
                                if (sbCtx.mounted) {
                                  setModalState(() => isSaving = false);
                                  UIHelper.showErrorSnackBar(
                                      sbCtx, 'Gagal: $e');
                                }
                              } finally {
                                if (sbCtx.mounted && isSaving) {
                                  Future.delayed(const Duration(seconds: 8),
                                      () {
                                    if (sbCtx.mounted && isSaving) {
                                      setModalState(() => isSaving = false);
                                    }
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const CupertinoActivityIndicator(
                              color: Colors.white)
                          : Text(ToneManager.t('profile_save_btn'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.12)),
                      ),
                      child: Center(
                        child: Text(
                          ToneManager.t('dialog_no'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteDebtTransaction(
      BuildContext context, TransactionModel tx, DebtModel debt) async {
    final confirmed = await UIHelper.showConfirmDialog(
      context: context,
      title: ToneManager.t('debt_tx_delete_title'),
      message: ToneManager.t('debt_tx_delete_msg')
          .replaceAll('{type}', debt.isUtang ? 'Hutang' : 'Piutang'),
    );

    if (confirmed == true) {
      try {
        await debtService.deleteDebtTransaction(
          userId: currentUserId,
          transaction: tx,
          debt: debt,
        );
        if (context.mounted) {
          UIHelper.showSuccessSnackBar(
              context, ToneManager.t('debt_tx_success_delete'));
        }
      } catch (e) {
        if (context.mounted) {
          UIHelper.showErrorSnackBar(context, 'Gagal menghapus: $e');
        }
      }
    }
  }
}

class _DebtPaymentModal extends StatefulWidget {
  final DebtModel debt;
  final FirestoreService firestoreService;
  final DebtService debtService;
  final String currentUserId;

  const _DebtPaymentModal({
    required this.debt,
    required this.firestoreService,
    required this.debtService,
    required this.currentUserId,
  });

  @override
  State<_DebtPaymentModal> createState() => _DebtPaymentModalState();
}

class _DebtPaymentModalState extends State<_DebtPaymentModal> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedWalletId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final remaining = widget.debt.totalAmount - widget.debt.paidAmount;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
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
            Text(
                ToneManager.t('debt_payment_title')
                    .replaceAll('{title}', widget.debt.title),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                ToneManager.t('debt_remaining_label')
                    .replaceAll(
                        '{type}', widget.debt.isUtang ? 'Hutang' : 'Piutang')
                    .replaceAll('{amount}',
                        CurrencyFormatter.formatCurrency(remaining)),
                style: TextStyle(
                    fontSize: 14, color: Theme.of(context).hintColor)),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0',
                prefixIcon: UnconstrainedBox(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.creditcard,
                            size: 20, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 8),
                        Text('Rp',
                            style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<WalletModel>>(
              stream: widget.firestoreService
                  .getWalletsStream(widget.currentUserId),
              builder: (streamCtx, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final wallets = snapshot.data!.where((w) => !w.isDebt).toList();
                return DropdownButtonFormField<String>(
                  value: _selectedWalletId,
                  hint: Text(ToneManager.t('debt_payment_wallet_hint')),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(streamCtx).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.05)
                        : AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text(w.walletName),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedWalletId = val);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: ToneManager.t('debt_payment_note_hint'),
                prefixIcon: Icon(CupertinoIcons.pencil,
                    color: Theme.of(context).primaryColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.05)
                    : AppColors.surfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_amountController.text.isEmpty ||
                                _selectedWalletId == null) {
                              UIHelper.showErrorSnackBar(
                                  context,
                                  ToneManager.t(
                                      'debt_payment_error_incomplete'));
                              return;
                            }

                            final payAmount =
                                double.tryParse(_amountController.text) ?? 0;
                            if (payAmount <= 0) return;
                            final remaining = widget.debt.totalAmount -
                                widget.debt.paidAmount;
                            if (payAmount > remaining) {
                              UIHelper.showErrorSnackBar(
                                  context,
                                  ToneManager.t('debt_payment_error_exceed')
                                      .replaceAll(
                                          '{type}',
                                          widget.debt.isUtang
                                              ? 'Hutang'
                                              : 'Piutang'));
                              return;
                            }

                            setState(() => _isLoading = true);
                            try {
                              await widget.debtService.payInstallment(
                                currentUserId: widget.currentUserId,
                                currentUserName: FirebaseAuth
                                        .instance.currentUser?.displayName ??
                                    'User',
                                targetDebt: widget.debt,
                                installmentAmount: payAmount,
                                paymentWalletId: _selectedWalletId!,
                              );

                              if (!mounted) return;
                              UIHelper.showSuccessSnackBar(context,
                                  ToneManager.t('debt_payment_success'));
                              Navigator.pop(context);
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isLoading = false);
                              UIHelper.showErrorSnackBar(
                                  context, 'Gagal mencatat pembayaran: $e');
                            } finally {
                              if (mounted && _isLoading) {
                                Future.delayed(const Duration(seconds: 8), () {
                                  if (mounted && _isLoading) {
                                    setState(() => _isLoading = false);
                                  }
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0A84FF)
                              : Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text('Simpan Pembayaran',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.12)),
                    ),
                    child: Center(
                      child: Text(
                        ToneManager.t('dialog_no'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
