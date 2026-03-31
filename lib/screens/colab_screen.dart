import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';

class ColabScreen extends StatefulWidget {
  const ColabScreen({super.key});

  @override
  State<ColabScreen> createState() => _ColabScreenState();
}

class _ColabScreenState extends State<ColabScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kolaborasi'),
        backgroundColor: AppColors.background,
      ),
      body: StreamBuilder<List<WalletModel>>(
        stream: _firestoreService.getColabWalletsStream(_uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final wallet = snapshot.data![index];
              return _ColabWalletCard(
                wallet: wallet,
                firestoreService: _firestoreService,
                currentUid: _uid,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              'Belum ada dompet kolaborasi',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buat dompet colab di tab Wallet\nuntuk patungan bareng teman! 🤝',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint),
            ),
          ],
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
    required this.wallet,
    required this.firestoreService,
    required this.currentUid,
  });

  @override
  State<_ColabWalletCard> createState() => _ColabWalletCardState();
}

class _ColabWalletCardState extends State<_ColabWalletCard> {
  bool _expanded = false;

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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.wallet.walletName,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatCurrency(
                            widget.wallet.balance),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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
                        'Tambah',
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
        return FutureBuilder<Map<String, dynamic>?>(
          future: widget.firestoreService.getUserInfo(uid),
          builder: (context, snapshot) {
            String name = 'Loading...';
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasData) {
                // Mencari dari 'displayName' (default Firebase) atau 'name' sebagai fallback
                name = snapshot.data?['displayName'] ?? snapshot.data?['name'] ?? 'Pengguna';
              } else {
                name = 'Tidak diketahui';
              }
            }

            final isOwner = uid == widget.wallet.owner;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOwner ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: isOwner ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOwner) ...[
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isOwner
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<TransactionModel>>(
      stream: widget.firestoreService
          .getTransactionsStream(widget.wallet.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Belum ada transaksi',
                style: TextStyle(
                    color: AppColors.textHint, fontSize: 12),
              ),
            ),
          );
        }

        final transactions = snapshot.data!.take(10).toList();

        return Column(
          children: transactions.map((txn) {
            final isIncome = txn.isIncome;
            final color =
                isIncome ? AppColors.income : AppColors.expense;

            return Padding(
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
                      TransactionCategory.getIconForCategory(
                          txn.category),
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
                          CurrencyFormatter.formatRelativeDate(
                              txn.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(txn.amount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tambah Anggota'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            hintText: 'Email anggota baru',
            prefixIcon:
                Icon(Icons.email_outlined, color: AppColors.primary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailController.text.trim().isEmpty) return;
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final success =
                  await widget.firestoreService.addMemberByEmail(
                widget.wallet.id,
                emailController.text.trim(),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Anggota berhasil ditambahkan! ✅'
                        : 'Email tidak ditemukan 😕'),
                    backgroundColor:
                        success ? AppColors.income : AppColors.expense,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}
