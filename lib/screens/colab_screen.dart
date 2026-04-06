import 'package:flutter/material.dart';
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

  void resetSearch() {
    if (mounted) {
      _searchController.clear();
      setState(() => _searchQuery = "");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kolaborasi',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.5)),
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 24,
        toolbarHeight: 70,
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
                color: const Color(0xFF767680).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Cari dompet...',
                  hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8E8E93), size: 20),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                          child: const Icon(Icons.cancel_rounded, color: Color(0xFF8E8E93), size: 18),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<WalletModel>>(
              stream: _firestoreService.getColabWalletsStream(_uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: 4,
                    itemBuilder: (context, _) => const ShimmerWalletCard(),
                  );
                }

                final wallets = snapshot.data ?? [];
                final filteredWallets = wallets.where((w) {
                  return w.walletName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredWallets.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: filteredWallets.length,
                  itemBuilder: (context, index) {
                    final wallet = filteredWallets[index];
                    return _ColabWalletCard(
                      key: ValueKey(wallet.id),
                      wallet: wallet,
                      firestoreService: _firestoreService,
                      currentUid: _uid,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_outlined,
                size: 64,
                color: AppColors.textHint.withOpacity(0.4),
              ),
              const SizedBox(height: 16),
              Text(
                ToneManager.t('colab_empty_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                ToneManager.t('colab_empty_msg'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textHint),
              ),
            ],
          ),
        ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  StreamBuilder<int>(
                    stream: _unreadStream,
                    builder: (context, unreadSnap) {
                      final unreadCount = unreadSnap.data ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.deepBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.group_rounded,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.expense,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 20, minHeight: 20),
                                child: Center(
                                  child: Text(
                                    unreadCount > 99 ? '99+' : '$unreadCount',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.wallet.walletName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.wallet.members.length} anggota',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatCurrency(widget.wallet.balance),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textHint,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded section
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 12),

          // Members section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Anggota',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              if (widget.wallet.owner == widget.currentUid)
                GestureDetector(
                  onTap: () => _showAddMemberDialog(),
                  child: const Row(
                    children: [
                      Icon(Icons.person_add_outlined,
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Undang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMembersList(),
          const SizedBox(height: 16),

          const SizedBox(height: 16),
          // Chat & Leave Wallet
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
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
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Buka Chat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.wallet.owner != widget.currentUid) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final confirm = await UIHelper.showConfirmDialog(
                      context: context,
                      title: ToneManager.t('dialog_leave_wallet_title'),
                      message: ToneManager.t('dialog_leave_wallet_msg'),
                    );
                    if (confirm == true) {
                      await widget.firestoreService.leaveWallet(widget.wallet.id, widget.currentUid);
                      if (context.mounted) {
                        UIHelper.showSuccessSnackBar(context, 'Berhasil keluar dompet 👋');
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.expense.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.logout_rounded, size: 18, color: AppColors.expense),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Recent transactions
          const Text(
            'Riwayat Transaksi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.wallet.members.map((uid) {
        final name = _memberNames[uid] ?? 'Memuat...';
        final isOwner = uid == widget.wallet.owner;
        final isMe = uid == widget.currentUid;
        final canKick = widget.wallet.owner == widget.currentUid && !isOwner;

        return Container(
          padding: EdgeInsets.only(left: 12, right: canKick ? 6 : 12, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: isOwner
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: isOwner
                ? Border.all(color: AppColors.primary.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner) ...[
                const Icon(Icons.star_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  isMe ? '$name (You)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isOwner ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
              if (canKick) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    final confirm = await UIHelper.showConfirmDialog(
                      context: context,
                      title: ToneManager.t('dialog_kick_member_title'),
                      message: ToneManager.t('dialog_kick_member_msg'),
                    );
                    if (confirm == true) {
                      await widget.firestoreService.kickMember(widget.wallet.id, uid);
                      if (context.mounted) {
                        UIHelper.showSuccessSnackBar(context, 'Anggota dikeluarkan 👋');
                      }
                    }
                  },
                  child: Icon(Icons.close_rounded, size: 16, color: AppColors.expense.withOpacity(0.7)),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<TransactionModel>>(
      stream: widget.firestoreService.getTransactionsStream(widget.wallet.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Belum ada transaksi',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ),
          );
        }

        final transactions = snapshot.data!.take(10).toList();

        return Column(
          children: transactions.map((txn) {
            final isIncome = txn.isIncome;
            final color = isIncome ? AppColors.income : AppColors.expense;

            return Dismissible(
              key: Key(txn.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                // Restriction: only the creator can delete their transaction
                if (txn.createdBy != widget.currentUid) {
                  UIHelper.showErrorSnackBar(context, ToneManager.t('error_not_creator_delete'));
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
                  UIHelper.showSuccessSnackBar(context, 'Transaksi berhasil dihapus');
                }
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.expense.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        TransactionCategory.getIconForCategory(txn.category),
                        color: color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.category,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatRelativeDate(txn.date),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(txn.amount)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
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
            bottom: MediaQuery.of(ctx).viewInsets.bottom +
                MediaQuery.of(ctx).padding.bottom +
                24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: AppColors.textHint.withOpacity(0.3),
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
                  child: const Icon(Icons.person_add_alt_1_rounded,
                      color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('Undang Anggota',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text(
                  'Masukkan email akun teman yang sudah\nterdaftar di MyDuitGweh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                      height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'contoh@email.com',
                    prefixIcon:
                        const Icon(Icons.email_outlined, color: AppColors.primary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
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
                            final success = await widget.firestoreService
                                .addMemberByEmail(
                              widget.wallet.id,
                              email,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (success) {
                              if (context.mounted) {
                                UIHelper.showSuccessSnackBar(context,
                                    'Undangan berhasil dikirim! 📩');
                              }
                            } else {
                              if (context.mounted) {
                                UIHelper.showErrorSnackBar(context,
                                    'Email tidak ditemukan atau sudah bergabung 😕');
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
