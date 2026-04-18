import 'dart:async';
import 'dart:ui' as ui;
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
        body: NestedScrollView(
          physics: const ClampingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  pinned: true,
                  floating: false,
                  centerTitle: true,
                  expandedHeight: 180,
                  collapsedHeight: 70,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: isDark
                      ? Colors.black.withOpacity(0.7)
                      : Colors.white.withOpacity(0.7),
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(
                            left: 24, bottom: 155, right: 60),
                        centerTitle: false,
                        title: Text(
                          ToneManager.t('wallet_list_title'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            letterSpacing: -1.0,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        background: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
                  actions: [
                    _buildHeaderActions(context, isDark),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(130),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildSearchBar(context, isDark),
                        const SizedBox(height: 16),
                        _buildSegmentedControl(context, isDark),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPersonalTab(context),
              _buildSharedTab(context),
              _buildDebtTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconButton(
            icon: CupertinoIcons.plus,
            onPressed: _showCreateWalletDialog,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF2C2C2E)
              : Color(0xFF767680).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 16),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: InputDecoration(
            hintText: ToneManager.t('wallet_search_hint'),
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor.withOpacity(0.5),
              fontSize: 15,
            ),
            prefixIcon: Icon(CupertinoIcons.search,
                color: Theme.of(context).hintColor.withOpacity(0.5), size: 18),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedControl(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2C2C2E)
            : Color(0xFF767680).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        onTap: (_) => HapticFeedback.selectionClick(),
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
        unselectedLabelColor: const Color(0xFF8E8E93),
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
    );
  }

  Widget _buildPersonalTab(BuildContext context) {
    return Builder(
      builder: (context) => CustomScrollView(
        key: const PageStorageKey('personal_wallets'),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          StreamBuilder<List<WalletModel>>(
            stream: _firestoreService.getWalletsStream(_uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _buildShimmerSliverList();
              }
              final wallets = snapshot.data ?? [];
              final filtered = wallets
                  .where((w) =>
                      w.walletName.toLowerCase().contains(_searchQuery) &&
                      w.isPersonal)
                  .toList();
              return _buildWalletSliverList(filtered);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSharedTab(BuildContext context) {
    return Builder(
      builder: (context) => CustomScrollView(
        key: const PageStorageKey('shared_wallets'),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          StreamBuilder<List<WalletModel>>(
            stream: _firestoreService.getWalletsStream(_uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _buildShimmerSliverList();
              }
              final wallets = snapshot.data ?? [];
              final filtered = wallets
                  .where((w) =>
                      w.walletName.toLowerCase().contains(_searchQuery) &&
                      w.isColab)
                  .toList();
              return _buildWalletSliverList(filtered);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDebtTab(BuildContext context) {
    return Builder(
      builder: (context) => CustomScrollView(
        key: const PageStorageKey('debt_list'),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          StreamBuilder<List<DebtModel>>(
            stream: _debtService.getUserDebts(_uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _buildShimmerSliverList();
              }
              final debts = snapshot.data ?? [];
              final filtered = debts
                  .where((d) => d.title.toLowerCase().contains(_searchQuery))
                  .toList();
              return _buildDebtSliverList(filtered);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSliverList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, _) => const ShimmerWalletCard(),
          childCount: 4,
        ),
      ),
    );
  }

  Widget _buildWalletSliverList(List<WalletModel> wallets) {
    if (wallets.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState());
    return SliverPadding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final wallet = wallets[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WalletCard(
                wallet: wallet,
                onTap: () => _showWalletDetails(wallet),
              ),
            );
          },
          childCount: wallets.length,
        ),
      ),
    );
  }

  void _showCreateWalletDialog() {
    String selectedType = 'personal';
    String debtType = 'payable'; // 'payable' or 'receivable'
    String? selectedWalletId;
    final nameController = TextEditingController();
    final debtorNameController = TextEditingController();
    final debtorPhoneController = TextEditingController();
    final totalAmountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setModalState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final backgroundColor =
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
          final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
          final primaryBlue =
              isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

          return Container(
            height: MediaQuery.of(sbCtx).size.height * 0.85,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // iOS Drag Handle
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // iOS Action Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sbCtx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Text(
                        'Dompet Baru',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (nameController.text.isNotEmpty) {
                            final isOnline =
                                await ConnectivityService.isOnline();

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
                                  UIHelper.showErrorSnackBar(
                                      sbCtx, 'Gagal: $e');
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
                                  UIHelper.showErrorSnackBar(
                                      sbCtx, 'Gagal: $e');
                                }
                              }
                            }
                          }
                        },
                        child: Text(
                          'Simpan',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Type Selection
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Text(
                            'TIPE DOMPET',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              _buildIOSTypeOption(
                                  sbCtx,
                                  setModalState,
                                  'personal',
                                  'Pribadi',
                                  selectedType,
                                  (v) => selectedType = v),
                              _buildIOSTypeOption(
                                  sbCtx,
                                  setModalState,
                                  'colab',
                                  'Bersama',
                                  selectedType,
                                  (v) => selectedType = v),
                              _buildIOSTypeOption(
                                  sbCtx,
                                  setModalState,
                                  'debt',
                                  'Hutang',
                                  selectedType,
                                  (v) => selectedType = v),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Section 2: Info Utama
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Text(
                            'INFORMASI UTAMA',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: sectionColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // Conditional Debt Sub-Sections
                              if (selectedType == 'debt') ...[
                                // Debtor Name
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: TextField(
                                    controller: debtorNameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: InputDecoration(
                                      hintText: 'Nama Teman / Pihak Lain',
                                      hintStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38),
                                      border: InputBorder.none,
                                      prefixIcon: Icon(CupertinoIcons.person,
                                          size: 20,
                                          color: primaryBlue.withOpacity(0.7)),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                            CupertinoIcons
                                                .person_crop_circle_fill_badge_plus,
                                            size: 24,
                                            color: primaryBlue),
                                        onPressed: () async {
                                          var status =
                                              await Permission.contacts.status;
                                          if (!status.isGranted) {
                                            status = await Permission.contacts
                                                .request();
                                          }
                                          if (status.isGranted) {
                                            final allContacts =
                                                await FlutterContacts
                                                    .getContacts(
                                                        withProperties: true);
                                            if (!sbCtx.mounted) return;
                                            _showContactPicker(
                                                sbCtx, allContacts, (contact) {
                                              setModalState(() {
                                                debtorNameController.text =
                                                    contact.displayName;
                                                if (contact.phones.isNotEmpty) {
                                                  debtorPhoneController.text =
                                                      contact
                                                          .phones.first.number;
                                                }
                                                nameController.text =
                                                    debtType == 'payable'
                                                        ? 'Hutang ke ${contact.displayName}'
                                                        : 'Piutang ${contact.displayName}';
                                              });
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val.isNotEmpty) {
                                          nameController.text = debtType ==
                                                  'payable'
                                              ? 'Hutang ke $val'
                                              : 'Piutang $val';
                                        } else {
                                          nameController.text = '';
                                        }
                                      });
                                    },
                                  ),
                                ),
                                Divider(
                                    height: 1,
                                    indent: 52,
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12),
                                // Phone Number
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: TextField(
                                    controller: debtorPhoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: 'Nomor HP (Opsional)',
                                      hintStyle: TextStyle(
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.black38),
                                      prefixIcon: Icon(CupertinoIcons.phone,
                                          size: 20,
                                          color: primaryBlue.withOpacity(0.7)),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                Divider(
                                    height: 1,
                                    indent: 52,
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12),
                                // Transaction Type (Radio)
                                _buildIOSRadioTile(
                                    sbCtx,
                                    setModalState,
                                    'Saya Berhutang',
                                    'payable',
                                    debtType, (v) {
                                  debtType = v;
                                  if (debtorNameController.text.isNotEmpty) {
                                    nameController.text =
                                        'Hutang ke ${debtorNameController.text}';
                                  }
                                }),
                                Divider(
                                    height: 1,
                                    indent: 56,
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12),
                                _buildIOSRadioTile(
                                    sbCtx,
                                    setModalState,
                                    'Saya Meminjamkan',
                                    'receivable',
                                    debtType, (v) {
                                  debtType = v;
                                  if (debtorNameController.text.isNotEmpty) {
                                    nameController.text =
                                        'Piutang ${debtorNameController.text}';
                                  }
                                }),
                                Divider(
                                    height: 1,
                                    indent: 16,
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12),
                              ],

                              // Main Name / Label Input
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: TextField(
                                  controller: nameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: selectedType == 'colab'
                                        ? 'Nama kelompok/tujuan'
                                        : selectedType == 'debt'
                                            ? 'Label Catatan (Misal: Hutang Budi)'
                                            : 'Nama dompet (misal: Jajan)',
                                    hintStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      selectedType == 'colab'
                                          ? CupertinoIcons.person_2
                                          : selectedType == 'debt'
                                              ? CupertinoIcons.doc_text
                                              : CupertinoIcons.creditcard,
                                      color: primaryBlue.withOpacity(0.7),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (selectedType == 'debt') ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Text(
                              'NOMINAL & SUMBER DANA',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: sectionColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                // Amount Input
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: TextField(
                                    controller: totalAmountController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      prefixIcon: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 12, right: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.money_dollar,
                                                size: 20,
                                                color: primaryBlue
                                                    .withOpacity(0.7)),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Rp ',
                                              style: TextStyle(
                                                color: primaryBlue,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                              minWidth: 0, minHeight: 0),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                Divider(
                                    height: 1,
                                    indent: 52,
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12),
                                // Wallet Selection
                                StreamBuilder<List<WalletModel>>(
                                  stream:
                                      _firestoreService.getWalletsStream(_uid),
                                  builder: (ctx, snapshot) {
                                    if (!snapshot.hasData)
                                      return const SizedBox.shrink();
                                    final wallets = snapshot.data!
                                        .where((w) => !w.isDebt)
                                        .toList();
                                    final selectedWallet =
                                        selectedWalletId != null
                                            ? wallets.firstWhere(
                                                (w) => w.id == selectedWalletId,
                                                orElse: () => wallets.first)
                                            : null;

                                    return ListTile(
                                      onTap: () => _showWalletPicker(
                                          sbCtx, wallets, (wallet) {
                                        setModalState(() =>
                                            selectedWalletId = wallet.id);
                                      }),
                                      leading: Icon(CupertinoIcons.creditcard,
                                          size: 20,
                                          color: primaryBlue.withOpacity(0.7)),
                                      title: Text(
                                        selectedWallet != null
                                            ? selectedWallet.walletName
                                            : 'Pilih Dompet Sumber/Tujuan',
                                        style: TextStyle(
                                            fontSize: 15,
                                            color: selectedWallet != null
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black)
                                                : (isDark
                                                    ? Colors.white38
                                                    : Colors.black38)),
                                      ),
                                      trailing: Icon(
                                          CupertinoIcons.chevron_right,
                                          size: 14,
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black26),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(sbCtx);
                              _showJoinWalletDialog();
                            },
                            child: Text(
                              'Sudah punya kode undangan? Gabung di sini',
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIOSTypeOption(BuildContext context, StateSetter setState,
      String type, String label, String current, Function(String) onSelect) {
    final isSelected = current == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => onSelect(type)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF636366) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIOSRadioTile(
      BuildContext context,
      StateSetter setState,
      String title,
      String value,
      String groupValue,
      Function(String) onChanged) {
    final isSelected = value == groupValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue =
        isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

    return InkWell(
      onTap: () => setState(() => onChanged(value)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: isSelected
                  ? primaryBlue
                  : (isDark ? Colors.white24 : Colors.black12),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactPicker(BuildContext context, List<Contact> allContacts,
      Function(Contact) onPicked) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = "";
        return StatefulBuilder(
          builder: (sbCtx, setLocalState) {
            final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
            final filtered = allContacts.where((c) {
              final n = c.displayName.toLowerCase();
              final p = c.phones.isNotEmpty
                  ? c.phones.first.number.replaceAll(' ', '')
                  : "";
              return n.contains(query.toLowerCase()) || p.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(sbCtx).size.height * 0.8,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2.5))),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: CupertinoSearchTextField(
                      onChanged: (v) => setLocalState(() => query = v),
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (lCtx, i) {
                        return ListTile(
                          title: Text(filtered[i].displayName),
                          subtitle: Text(filtered[i].phones.isNotEmpty
                              ? filtered[i].phones.first.number
                              : ""),
                          onTap: () {
                            onPicked(filtered[i]);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWalletPicker(BuildContext context, List<WalletModel> wallets, Function(WalletModel) onPicked) {
    String query = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sbCtx, setPickerState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final filtered = wallets.where((w) {
            return w.walletName.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(sbCtx).size.height * 0.7,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  // iOS Drag Handle
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PILIH SUMBER DANA', 
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.w600, 
                            color: isDark ? Colors.white60 : Colors.black54,
                            letterSpacing: 0.5,
                          )
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Text('Tutup', 
                            style: TextStyle(
                              color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF), 
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            )
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: CupertinoSearchTextField(
                      placeholder: 'Cari dompet...',
                      onChanged: (v) => setPickerState(() => query = v),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                      ? Center(child: Text('Dompet tidak ditemukan', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (lCtx, i) {
                            final w = filtered[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              tileColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  w.type == 'personal' ? CupertinoIcons.person_fill : (w.type == 'colab' ? CupertinoIcons.person_3_fill : CupertinoIcons.creditcard_fill),
                                  color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                                  size: 20,
                                ),
                              ),
                              title: Text(w.walletName, 
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                )
                              ),
                              trailing: Icon(CupertinoIcons.chevron_right, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                              onTap: () {
                                onPicked(w);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                        ),
                  ),
                ],
              ),
            ),
          );
        },
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
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setModalState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final backgroundColor =
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
          final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
          final primaryBlue =
              isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // iOS Drag Handle
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // iOS Action Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sbCtx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Text(
                        'Gabung Dompet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: isChecking
                            ? null
                            : () async {
                                if (codeController.text.length < 6) {
                                  UIHelper.showErrorSnackBar(
                                      sbCtx, 'Kode harus 6 digit ya! (〜￣▽￣)〜');
                                  return;
                                }
                                setModalState(() => isChecking = true);
                                try {
                                  final success =
                                      await _firestoreService.joinWalletByCode(
                                          codeController.text.toUpperCase(),
                                          _uid);
                                  if (!sbCtx.mounted) return;
                                  if (success) {
                                    Navigator.pop(sbCtx);
                                    UIHelper.showSuccessSnackBar(sbCtx,
                                        'Berhasil bergabung! Selamat berkolaborasi');
                                  } else {
                                    UIHelper.showErrorSnackBar(sbCtx,
                                        'Kode tidak valid atau kamu sudah bergabung');
                                    setModalState(() => isChecking = false);
                                  }
                                } catch (e) {
                                  if (sbCtx.mounted) {
                                    UIHelper.showErrorSnackBar(
                                        sbCtx, 'Gagal bergabung: $e');
                                    setModalState(() => isChecking = false);
                                  }
                                }
                              },
                        child: isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                'Gabung',
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.person_badge_plus,
                          color: primaryBlue,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Masukkan Kode Undangan',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Minta temanmu untuk membagikan kode undangan dari pengaturan dompet mereka.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: codeController,
                          maxLength: 6,
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          cursorColor: primaryBlue,
                          decoration: InputDecoration(
                            hintText: '• • • • • •',
                            counterText: '',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white24 : Colors.black26,
                              fontSize: 28,
                              letterSpacing: 8,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setModalState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final backgroundColor =
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
          final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
          final primaryBlue =
              isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

          return Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sbCtx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        'Ubah $typeLabel',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final newAmount = double.tryParse(amountController.text);
                                if (newAmount == null || titleController.text.isEmpty) {
                                  UIHelper.showErrorSnackBar(sbCtx, 'Lengkapi data terlebih dahulu.');
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
                                    UIHelper.showSuccessSnackBar(sbCtx, 'Berhasil memperbarui $typeLabel');
                                    Navigator.pop(sbCtx);
                                  }
                                } catch (e) {
                                  if (sbCtx.mounted) {
                                    setModalState(() => isSaving = false);
                                    UIHelper.showErrorSnackBar(sbCtx, 'Gagal: $e');
                                  }
                                }
                              },
                        child: isSaving
                            ? const CupertinoActivityIndicator()
                            : Text(
                                'Simpan',
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RINCIAN $typeLabel',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            // Title
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: TextField(
                                controller: titleController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Keterangan / Label',
                                  prefixIcon: Icon(CupertinoIcons.pencil, size: 20, color: primaryBlue.withOpacity(0.7)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            Divider(height: 1, indent: 52, color: isDark ? Colors.white10 : Colors.black12),
                            // Amount
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(left: 12, right: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.creditcard, size: 20, color: primaryBlue.withOpacity(0.7)),
                                        const SizedBox(width: 8),
                                        Text('Rp ', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700, fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'TENGGAT WAKTU (OPSIONAL)',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: sbCtx,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                              builder: (context, child) {
                                return Theme(
                                  data: isDark
                                      ? ThemeData.dark().copyWith(
                                          colorScheme: ColorScheme.dark(
                                            primary: primaryBlue,
                                            onPrimary: Colors.white,
                                            surface: backgroundColor,
                                            onSurface: Colors.white,
                                          ),
                                          dialogBackgroundColor: backgroundColor,
                                        )
                                      : ThemeData.light().copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: primaryBlue,
                                            onPrimary: Colors.white,
                                            surface: Colors.white,
                                            onSurface: Colors.black,
                                          ),
                                        ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          leading: Icon(CupertinoIcons.calendar, size: 20, color: primaryBlue.withOpacity(0.7)),
                          title: Text(
                            selectedDate != null ? DateFormat('dd MMMM yyyy').format(selectedDate!) : 'Pilih Tanggal',
                            style: const TextStyle(fontSize: 15),
                          ),
                          trailing: Icon(CupertinoIcons.chevron_right, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  void _showIncreaseDebtDialog(DebtModel debt) {
    final amountController = TextEditingController();
    String? selectedWalletId;
    bool isSaving = false;
    final String typeLabel = debt.isUtang ? 'Hutang' : 'Piutang';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setModalState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final backgroundColor =
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
          final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
          final primaryBlue =
              isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

          return Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sbCtx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        'Tambah $typeLabel',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final amount = double.tryParse(amountController.text);
                                if (amount == null || amount <= 0 || selectedWalletId == null) {
                                  UIHelper.showErrorSnackBar(sbCtx, 'Lengkapi data terlebih dahulu.');
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                try {
                                  await _debtService.increaseDebt(
                                    userId: _uid,
                                    userName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                                    debt: debt,
                                    additionalAmount: amount,
                                    walletId: selectedWalletId!,
                                  );
                                  if (sbCtx.mounted) {
                                    UIHelper.showSuccessSnackBar(sbCtx, 'Berhasil menambahkan nominal $typeLabel');
                                    Navigator.pop(sbCtx);
                                  }
                                } catch (e) {
                                  if (sbCtx.mounted) {
                                    setModalState(() => isSaving = false);
                                    UIHelper.showErrorSnackBar(sbCtx, 'Gagal: $e');
                                  }
                                }
                              },
                        child: isSaving
                            ? const CupertinoActivityIndicator()
                            : Text(
                                'Tambah',
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOMINAL TAMBAHAN',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: 'Nominal',
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(left: 12, right: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.plus_circle, size: 20, color: primaryBlue.withOpacity(0.7)),
                                        const SizedBox(width: 8),
                                        Text('Rp ', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700, fontSize: 16)),
                                      ],
                                    ),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'SUMBER DANA',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<WalletModel>>(
                        stream: _firestoreService.getWalletsStream(_uid),
                        builder: (ctx, snapshot) {
                          final wallets = (snapshot.data ?? []).where((w) => w.isPersonal).toList();
                          final selectedWallet = selectedWalletId != null
                              ? wallets.firstWhere((w) => w.id == selectedWalletId, orElse: () => wallets.first)
                              : null;

                          return Container(
                            decoration: BoxDecoration(
                              color: sectionColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              onTap: () => _showWalletPicker(sbCtx, wallets, (wallet) {
                                setModalState(() => selectedWalletId = wallet.id);
                              }),
                              leading: Icon(CupertinoIcons.creditcard, size: 20, color: primaryBlue.withOpacity(0.7)),
                              title: Text(
                                selectedWallet != null ? selectedWallet.walletName : 'Pilih Dompet',
                                style: const TextStyle(fontSize: 15),
                              ),
                              trailing: Icon(CupertinoIcons.chevron_right, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
      if (!context.mounted) return;
      try {
        await _debtService.deleteDebt(_uid, debt.id);
        if (!context.mounted) return;
        UIHelper.showSuccessSnackBar(
            context,
            ToneManager.t('debt_success_delete')
                .replaceAll('{type}', typeLabel));
      } catch (e) {
        if (!context.mounted) return;
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
                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // Close sheet
                              UIHelper.showSuccessSnackBar(
                                  context, 'Dompet berhasil dihapus');
                            } catch (e) {
                              if (context.mounted) {
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
                            if (!context.mounted) return;
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
                                      ? Color(0xFF0A84FF).withOpacity(0.9)
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
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setModalState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final backgroundColor =
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
          final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
          final primaryBlue =
              isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sbCtx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // iOS Drag Handle
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // iOS Action Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sbCtx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Text(
                        'Ubah Nama',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (nameController.text.isNotEmpty &&
                              nameController.text != wallet.walletName) {
                            final isOnline =
                                await ConnectivityService.isOnline();
                            if (!isOnline) {
                              _firestoreService.renameWallet(
                                  wallet.id, nameController.text);
                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // Pop dialog
                              Navigator.of(context).pop(); // Pop details sheet
                              UIHelper.showInfoSnackBar(context,
                                  'Nama dompet akan berubah setelah online');
                              return;
                            }

                            try {
                              await _firestoreService
                                  .renameWallet(wallet.id, nameController.text)
                                  .timeout(
                                    const Duration(seconds: 10),
                                    onTimeout: () =>
                                        throw TimeoutException('Timeout'),
                                  );
                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // Pop dialog
                              Navigator.of(context).pop(); // Pop details sheet
                              UIHelper.showSuccessSnackBar(context,
                                  'Nama dompet berhasil diubah ke "${nameController.text}"!');
                            } catch (e) {
                              if (context.mounted) {
                                if (e is TimeoutException) {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                  UIHelper.showInfoSnackBar(context,
                                      'Perubahan nama tertunda koneksi.');
                                } else {
                                  UIHelper.showErrorSnackBar(
                                      context, 'Gagal mengubah nama: $e');
                                }
                              }
                            }
                          } else {
                            Navigator.pop(sbCtx);
                          }
                        },
                        child: Text(
                          'Simpan',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 17,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nama Dompet',
                            prefixIcon: Icon(
                              CupertinoIcons.pencil,
                              color: isDark ? Colors.white54 : Colors.black45,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildDebtSliverList(List<DebtModel> debts) {
    if (debts.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState());
    return SliverPadding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 120),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final debt = debts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DebtCard(
                debt: debt,
                onTap: () => _showDebtDetails(debt),
                onEdit: () => _showEditDebtDialog(debt),
                onDelete: () => _deleteDebt(debt),
                onIncrease: () => _showIncreaseDebtDialog(debt),
              ),
            );
          },
          childCount: debts.length,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.05 : 0.08),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
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
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(isDark ? 0.05 : 0.08),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatCurrency(debt.totalAmount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: remaining <= 0 
                                ? AppColors.income.withOpacity(0.12)
                                : Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            remaining <= 0 ? 'LUNAS' : 'BELUM LUNAS',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: remaining <= 0 ? AppColors.income : Colors.orange,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (debt.dueDate != null)
                          Text(
                            DateFormat('dd MMM').format(debt.dueDate!),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DebtActionButton(
                        icon: CupertinoIcons.info,
                        label: 'Detail',
                        onTap: onTap,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DebtActionButton(
                        icon: CupertinoIcons.add,
                        label: 'Bayar',
                        onTap: onIncrease,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DebtActionButton(
                        icon: CupertinoIcons.ellipsis,
                        label: 'Opsi',
                        onTap: () => _showDebtOptions(context),
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
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

  void _showDebtOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
            child: Text('Edit ${debt.isUtang ? 'Hutang' : 'Piutang'}'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Hapus Catatan'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ),
    );
  }
}

class _DebtActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _DebtActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;

  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0A84FF) : AppColors.primary)
              .withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 24,
          color: isDark ? const Color(0xFF0A84FF) : AppColors.primary,
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setModalState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final backgroundColor =
              isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
          final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
          final primaryBlue =
              isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sbCtx).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sbCtx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Text(
                        'Edit Nominal',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final newAmount = double.tryParse(amountController.text);
                                if (newAmount == null || newAmount <= 0) return;

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
                                    UIHelper.showErrorSnackBar(sbCtx, 'Gagal: $e');
                                  }
                                }
                              },
                        child: isSaving
                            ? const CupertinoActivityIndicator()
                            : Text(
                                'Simpan',
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'NOMINAL BARU',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: '0',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.creditcard, size: 20, color: primaryBlue.withOpacity(0.7)),
                                  const SizedBox(width: 8),
                                  Text('Rp ', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w700, fontSize: 16)),
                                ],
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Perubahan nominal akan menyesuaikan saldo dompet terkait dan sisa ${debt.isUtang ? 'hutang' : 'piutang'}.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
  WalletModel? _selectedWallet;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final remaining = widget.debt.totalAmount - widget.debt.paidAmount;
    _amountController.text = remaining.toStringAsFixed(0);
  }

  void _showLocalWalletPicker(BuildContext context, List<WalletModel> wallets) {
    String query = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (sbCtx, setPickerState) {
          final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
          final backgroundColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
          final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
          final primaryBlue = isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

          final filtered = wallets.where((w) {
            return w.walletName.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(sbCtx).size.height * 0.7,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sbCtx),
                        child: Text('Tutup', style: TextStyle(color: primaryBlue, fontSize: 17)),
                      ),
                      const Text('Pilih Dompet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 60),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoSearchTextField(
                    onChanged: (v) => setPickerState(() => query = v),
                    placeholder: 'Cari dompet...',
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text('Dompet tidak ditemukan', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final w = filtered[index];
                            final isSelected = _selectedWallet?.id == w.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: sectionColor,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected ? Border.all(color: primaryBlue, width: 2) : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryBlue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(CupertinoIcons.creditcard, color: primaryBlue, size: 20),
                                ),
                                title: Text(w.walletName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(CurrencyFormatter.formatCurrency(w.balance), style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
                                trailing: isSelected ? Icon(CupertinoIcons.checkmark_circle_fill, color: primaryBlue) : null,
                                onTap: () {
                                  setState(() => _selectedWallet = w);
                                  Navigator.pop(sbCtx);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.debt.totalAmount - widget.debt.paidAmount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final sectionColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final primaryBlue = isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final accentColor = widget.debt.isUtang ? AppColors.expense : AppColors.income;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Batal', style: TextStyle(color: primaryBlue, fontSize: 17)),
                ),
                Text(
                  widget.debt.isUtang ? 'Bayar Hutang' : 'Terima Piutang',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedWallet == null
                      ? null
                      : () async {
                          final amount = double.tryParse(_amountController.text);
                          if (amount == null || amount <= 0) return;
                          if (amount > remaining) {
                            UIHelper.showErrorSnackBar(context, 'Melebihi sisa ${widget.debt.isUtang ? 'hutang' : 'piutang'}');
                            return;
                          }

                          setState(() => _isLoading = true);
                          try {
                            await widget.debtService.payInstallment(
                              currentUserId: widget.currentUserId,
                              currentUserName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                              targetDebt: widget.debt,
                              installmentAmount: amount,
                              paymentWalletId: _selectedWallet!.id,
                            );
                            if (mounted) {
                              UIHelper.showSuccessSnackBar(context, ToneManager.t('debt_tx_success_add'));
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              UIHelper.showErrorSnackBar(context, 'Gagal: $e');
                            }
                          }
                        },
                  child: _isLoading
                      ? const CupertinoActivityIndicator()
                      : Text(
                          'Simpan',
                          style: TextStyle(
                            color: _selectedWallet == null ? Colors.grey : primaryBlue,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Debt Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'INFO ${widget.debt.isUtang ? 'HUTANG' : 'PIUTANG'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: sectionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Pihak', widget.debt.title, CupertinoIcons.person_2, isDark),
                        const Divider(height: 24),
                        _buildInfoRow('Sisa', CurrencyFormatter.formatCurrency(remaining), CupertinoIcons.hourglass, isDark, color: Colors.orange),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Form
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'PEMBAYARAN',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: sectionColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Amount
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            decoration: InputDecoration(
                              hintText: '0',
                              border: InputBorder.none,
                              prefixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(CupertinoIcons.money_rubl, size: 20, color: accentColor),
                                  const SizedBox(width: 8),
                                  Text('Rp ', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                            ),
                          ),
                        ),
                        Divider(height: 1, indent: 52, color: isDark ? Colors.white10 : Colors.black12),
                        // Wallet Selection
                        StreamBuilder<List<WalletModel>>(
                          stream: widget.firestoreService.getWalletsStream(widget.currentUserId),
                          builder: (ctx, snapshot) {
                            final wallets = (snapshot.data ?? []).where((w) => !w.isDebt).toList();
                            return ListTile(
                              onTap: wallets.isEmpty ? null : () => _showLocalWalletPicker(context, wallets),
                              leading: Icon(CupertinoIcons.creditcard, size: 20, color: primaryBlue.withOpacity(0.7)),
                              title: Text(
                                _selectedWallet?.walletName ?? 'Pilih Dompet',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _selectedWallet != null ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white38 : Colors.black38)
                                ),
                              ),
                              trailing: Icon(CupertinoIcons.chevron_right, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                            );
                          },
                        ),
                        Divider(height: 1, indent: 52, color: isDark ? Colors.white10 : Colors.black12),
                        // Note
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: TextField(
                            controller: _noteController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Catatan (Opsional)',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                              prefixIcon: Icon(CupertinoIcons.pencil, size: 20, color: primaryBlue.withOpacity(0.7)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? (isDark ? Colors.white54 : Colors.black54)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color)),
      ],
    );
  }
}
