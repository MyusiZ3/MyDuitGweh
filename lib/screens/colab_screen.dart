import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../widgets/shimmer_loading.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/ui_helper.dart';
import '../utils/tone_dictionary.dart';
import 'wallet_chat_screen.dart';

class ColabScreen extends StatefulWidget {
  const ColabScreen({super.key});

  @override
  State<ColabScreen> createState() => ColabScreenState();
}

class ColabScreenState extends State<ColabScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  bool _isSearchOpen = false;

  void resetSearch() {
    if (mounted) {
      _searchController.clear();
      setState(() {
        _searchQuery = "";
        _isSearchOpen = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  StreamBuilder<List<WalletModel>>(
                    stream: _firestoreService.getColabWalletsStream(_uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: ShimmerWalletCard(),
                              ),
                              childCount: 4,
                            ),
                          ),
                        );
                      }

                      final wallets = snapshot.data ?? [];
                      final filteredWallets = wallets.where((w) {
                        return w.walletName.toLowerCase().contains(_searchQuery);
                      }).toList();

                      if (filteredWallets.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final wallet = filteredWallets[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ColabWalletCard(
                                  key: ValueKey(wallet.id),
                                  wallet: wallet,
                                  firestoreService: _firestoreService,
                                  currentUid: _uid,
                                ),
                              );
                            },
                            childCount: filteredWallets.length,
                          ),
                        ),
                      );
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

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      color: isDark
          ? const Color(0xFF000000)
          : Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Kolaborasi',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      letterSpacing: -0.8,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                _buildHeaderActions(context, isDark),
              ],
            ),
          ),
          if (_isSearchOpen) ...[
            _buildSearchBar(context, isDark),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCircularIconButton(
            icon: _isSearchOpen ? CupertinoIcons.xmark : CupertinoIcons.search,
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  _searchQuery = "";
                }
              });
            },
            isDark: isDark,
            isActive: _isSearchOpen,
          ),
          _buildCircularIconButton(
            icon: CupertinoIcons.person_badge_plus,
            onPressed: _showJoinWalletDialog,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isDark,
    bool isActive = false,
  }) {
    final bg = isActive
        ? (isDark ? Colors.white : const Color(0xFF18181B))
        : (isDark ? const Color(0xFF1C1C22) : const Color(0xFFF4F4F5));
    final iconColor = isActive
        ? (isDark ? const Color(0xFF18181B) : Colors.white)
        : (isDark ? Colors.white : const Color(0xFF18181B));

    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: iconColor,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    final bg = isDark ? const Color(0xFF1C1C22) : const Color(0xFFF4F4F5);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: TextField(
          controller: _searchController,
          scrollPadding: EdgeInsets.zero,
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.white : const Color(0xFF18181B),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Cari dompet kolaborasi...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              fontSize: 13.5,
            ),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              size: 16,
            ),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    },
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      size: 16,
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0A84FF)
                          : AppColors.primary)
                      .withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.group_solid,
                  size: 64,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF0A84FF)
                          : AppColors.primary)
                      .withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                ToneManager.t('colab_empty_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ToneManager.t('colab_empty_msg'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Theme.of(context).hintColor.withOpacity(0.7),
                ),
              ),
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
}

class _ColabWalletCard extends StatefulWidget {
  final WalletModel wallet;
  final FirestoreService firestoreService;
  final String currentUid;

  const _ColabWalletCard({
    super.key,
    required this.wallet,
    required this.firestoreService,
    required this.currentUid,
  });

  @override
  State<_ColabWalletCard> createState() => _ColabWalletCardState();
}

class _ColabWalletCardState extends State<_ColabWalletCard> {
  bool _expanded = false;
  bool _showAllMembers = false;
  final Map<String, String> _memberNames = {};
  late Stream<int> _unreadStream;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _unreadStream = widget.firestoreService
        .getUnreadCountStream(widget.wallet.id, widget.currentUid);
  }

  Future<void> _loadMembers() async {
    for (final uid in widget.wallet.members) {
      try {
        final info = await widget.firestoreService.getUserInfo(uid);
        if (mounted) {
          setState(() {
            _memberNames[uid] =
                info?['displayName'] ?? info?['name'] ?? 'Pengguna';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _memberNames[uid] = 'Pengguna';
          });
        }
      }
    }
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
          color:
              Theme.of(context).dividerColor.withOpacity(isDark ? 0.05 : 0.08),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            // Header
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _expanded = !_expanded);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      StreamBuilder<int>(
                        stream: _unreadStream,
                        builder: (context, unreadSnap) {
                          final unreadCount = unreadSnap.data ?? 0;
                          final accentColor = isDark
                              ? const Color(0xFF0A84FF)
                              : AppColors.deepBlue;

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withOpacity(0.2),
                                      accentColor.withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: accentColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  CupertinoIcons.group_solid,
                                  color: accentColor,
                                  size: 28,
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: -5,
                                  right: -5,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.expense,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Theme.of(context).cardColor,
                                          width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.expense
                                              .withOpacity(0.4),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const SizedBox(width: 8, height: 8),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.wallet.walletName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(CupertinoIcons.person_2_fill,
                                    size: 13,
                                    color: Theme.of(context)
                                        .hintColor
                                        .withOpacity(0.5)),
                                const SizedBox(width: 5),
                                Text(
                                  '${widget.wallet.members.length} Anggota',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .hintColor
                                        .withOpacity(0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'SALDO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color:
                                  Theme.of(context).hintColor.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.formatCurrency(
                                widget.wallet.balance),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              color:
                                  Theme.of(context).textTheme.titleLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Expanded section
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _buildExpandedContent()
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFF0A84FF) : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            width: double.infinity,
            color: Theme.of(context)
                .dividerColor
                .withOpacity(isDark ? 0.08 : 0.04),
          ),
          const SizedBox(height: 20),

          // Members section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ANGGOTA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Theme.of(context).hintColor.withOpacity(0.5),
                ),
              ),
              if (widget.wallet.owner == widget.currentUid)
                Material(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _showAddMemberDialog(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.person_add_solid,
                              size: 14, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            'Undang',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildMembersList(),

          const SizedBox(height: 16),

          // Chat & Actions
          Row(
            children: [
              Expanded(
                child: Material(
                  color: accentColor.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WalletChatScreen(
                            walletId: widget.wallet.id,
                            walletName: widget.wallet.walletName,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: accentColor.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.chat_bubble_2_fill,
                              size: 18, color: accentColor),
                          const SizedBox(width: 8),
                          Text(
                            'Buka Chat',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.wallet.owner != widget.currentUid) ...[
                const SizedBox(width: 12),
                Material(
                  color: AppColors.expense.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      final confirm = await UIHelper.showConfirmDialog(
                        context: context,
                        title: ToneManager.t('dialog_leave_wallet_title'),
                        message: ToneManager.t('dialog_leave_wallet_msg'),
                      );
                      if (confirm == true) {
                        await widget.firestoreService
                            .leaveWallet(widget.wallet.id, widget.currentUid);
                        if (mounted) {
                          UIHelper.showSuccessSnackBar(
                              context, 'Berhasil keluar dompet 👋');
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.expense.withOpacity(0.12)),
                      ),
                      child: const Icon(CupertinoIcons.square_arrow_right,
                          size: 20, color: AppColors.expense),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 12),
          _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final members = widget.wallet.members;
    // Limit to 6 members which is roughly 2 rows on most devices
    const int limit = 6;
    final bool hasMore = members.length > limit;
    final displayMembers =
        _showAllMembers ? members : members.take(limit).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...displayMembers.map((uid) {
          final name = _memberNames[uid] ?? '...';
          final isOwner = uid == widget.wallet.owner;
          final isMe = uid == widget.currentUid;
          final canKick = widget.wallet.owner == widget.currentUid && !isOwner;
          final accentColor =
              isDark ? const Color(0xFF0A84FF) : AppColors.primary;

          return Container(
            padding: EdgeInsets.fromLTRB(10, 6, canKick ? 5 : 12, 6),
            decoration: BoxDecoration(
              color: isOwner
                  ? (isDark
                      ? accentColor.withOpacity(0.15)
                      : accentColor.withOpacity(0.08))
                  : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOwner
                    ? accentColor.withOpacity(0.3)
                    : Theme.of(context)
                        .dividerColor
                        .withOpacity(isDark ? 0.08 : 0.04),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwner) ...[
                  Icon(CupertinoIcons.star_fill,
                      size: 10,
                      color: isDark ? accentColor : AppColors.primary),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    isMe ? '$name (You)' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isOwner || isMe ? FontWeight.w800 : FontWeight.w600,
                      color: isOwner
                          ? (isDark ? accentColor : AppColors.primary)
                          : Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color
                              ?.withOpacity(0.85),
                    ),
                  ),
                ),
                if (canKick) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.heavyImpact();
                      final confirm = await UIHelper.showConfirmDialog(
                        context: context,
                        title: ToneManager.t('dialog_kick_member_title'),
                        message: ToneManager.t('dialog_kick_member_msg'),
                      );
                      if (confirm == true) {
                        await widget.firestoreService
                            .kickMember(widget.wallet.id, uid);
                        if (mounted) {
                          UIHelper.showSuccessSnackBar(
                              context, 'Anggota dikeluarkan 👋');
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppColors.expense.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.xmark,
                          size: 11, color: AppColors.expense),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        if (hasMore)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showAllMembers = !_showAllMembers);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor
                        .withOpacity(isDark ? 0.08 : 0.04),
                  ),
                ),
                child: Text(
                  _showAllMembers
                      ? 'Lihat Sedikit'
                      : '+${members.length - limit} Lainnya',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RIWAYAT TRANSAKSI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Theme.of(context).hintColor.withOpacity(0.5),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).highlightColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Terbaru',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).hintColor.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<TransactionModel>>(
          stream:
              widget.firestoreService.getTransactionsStream(widget.wallet.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.02)
                      : Colors.black.withOpacity(0.01),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.03)),
                ),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.tray,
                        size: 32,
                        color: Theme.of(context).hintColor.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada transaksi',
                      style: TextStyle(
                        color: Theme.of(context).hintColor.withOpacity(0.4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final transactions = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 10),
                  physics: const BouncingScrollPhysics(),
                  itemCount: transactions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 52,
                    color: Theme.of(context)
                        .dividerColor
                        .withOpacity(isDark ? 0.08 : 0.05),
                  ),
                  itemBuilder: (context, index) {
                    final txn = transactions[index];
                    final isIncome = txn.isIncome;
                    final color =
                        isIncome ? AppColors.income : AppColors.expense;

                    return Dismissible(
                      key: Key(txn.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) async {
                        if (txn.createdBy != widget.currentUid) {
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
                        await widget.firestoreService.deleteTransaction(txn);
                        if (context.mounted) {
                          UIHelper.showSuccessSnackBar(
                              context, 'Transaksi dihapus');
                        }
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.expense,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(CupertinoIcons.trash,
                            color: Colors.white, size: 20),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                TransactionCategory.getIconForCategory(
                                    txn.category),
                                color: color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    txn.category,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.formatRelativeDate(
                                        txn.date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .hintColor
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(txn.amount)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white24
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.person_add_solid,
                      color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Undang Anggota',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).textTheme.titleLarge?.color)),
                const SizedBox(height: 8),
                Text(
                  'Masukkan email akun teman yang sudah\nterdaftar di MyDuitGweh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'contoh@email.com',
                    prefixIcon: const Icon(CupertinoIcons.mail,
                        color: AppColors.primary),
                    filled: true,
                    fillColor: Theme.of(context).canvasColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              UIHelper.showErrorSnackBar(
                                  ctx, 'Email tidak boleh kosong! ✉️');
                              return;
                            }
                            if (!email.contains('@') || !email.contains('.')) {
                              UIHelper.showErrorSnackBar(
                                  ctx, 'Format email tidak valid 😕');
                              return;
                            }
                            setModalState(() => isSending = true);
                            final success =
                                await widget.firestoreService.addMemberByEmail(
                              widget.wallet.id,
                              email,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (success) {
                              if (mounted) {
                                UIHelper.showSuccessSnackBar(
                                    context, 'Undangan berhasil dikirim!');
                              }
                            } else {
                              if (mounted) {
                                UIHelper.showErrorSnackBar(context,
                                    'Email tidak ditemukan atau sudah bergabung');
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('Kirim Undangan',
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
}
