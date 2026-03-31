import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../utils/app_theme.dart';
import '../utils/currency_formatter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dompet Saya'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            onPressed: _showJoinWalletDialog,
            icon: const Icon(Icons.vpn_key_rounded, color: AppColors.textSecondary),
            tooltip: 'Gabung Dompet',
          ),
          IconButton(
            onPressed: _showCreateWalletDialog,
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Buat Dompet',
          ),
        ],
      ),
      body: StreamBuilder<List<WalletModel>>(
        stream: _firestoreService.getWalletsStream(_uid),
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
              return _WalletCard(
                wallet: wallet,
                onTap: () => _showWalletDetail(wallet),
              );
            },
          );
        },
      ),
    );
  }

  void _showJoinWalletDialog() {
    final codeController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text('Gabung ke Dompet',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Masukkan 6 digit kode undangan dompet kolaborasi.',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'CONTOH: X8Y2Z1',
                  prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.primary),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final code = codeController.text.trim();
                    if (code.length < 6) return;

                    setModalState(() => isLoading = true);
                    final success = await _firestoreService.joinWalletByCode(code, _uid);
                    setModalState(() => isLoading = false);

                    if (mounted) {
                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Berhasil bergabung ke dompet!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kode tidak valid atau dompet tidak ditemukan.')),
                        );
                      }
                    }
                  },
                  child: isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Gabung Sekarang'),
                ),
              ),
            ],
          ),
        ),
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
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: AppColors.textHint.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada dompet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buat dompet pertamamu yuk!',
              style: TextStyle(color: AppColors.textHint),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateWalletDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat Dompet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateWalletDialog() {
    final nameController = TextEditingController();
    String selectedType = 'personal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text('Buat Dompet Baru',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  hintText: 'Nama dompet',
                  prefixIcon: Icon(Icons.edit_outlined, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              // Type selector
              Row(
                children: [
                  _typeChip(
                    label: 'Personal',
                    icon: Icons.person_rounded,
                    selected: selectedType == 'personal',
                    onTap: () => setModalState(() => selectedType = 'personal'),
                  ),
                  const SizedBox(width: 12),
                  _typeChip(
                    label: 'Kolaborasi',
                    icon: Icons.group_rounded,
                    selected: selectedType == 'colab',
                    onTap: () => setModalState(() => selectedType = 'colab'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final wallet = WalletModel(
                      id: '', walletName: nameController.text.trim(),
                      balance: 0, type: selectedType,
                      members: [_uid], owner: _uid,
                      createdAt: DateTime.now(),
                    );
                    await _firestoreService.createWallet(wallet);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Buat Dompet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? AppColors.primary : AppColors.textHint),
              const SizedBox(height: 8),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showWalletDetail(WalletModel wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textHint.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(wallet.walletName,
                                  style: Theme.of(context).textTheme.headlineMedium),
                              const SizedBox(height: 4),
                              Text(
                                wallet.isColab ? 'Dompet Kolaborasi' : 'Dompet Personal',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        // Only owner can delete personal wallet or the colab creator
                        if (wallet.owner == _uid)
                          IconButton(
                            onPressed: () => _confirmDeleteWallet(wallet),
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                            tooltip: 'Hapus Dompet',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      CurrencyFormatter.formatCurrency(wallet.balance),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: AppColors.primary),
                    ),
                    if (wallet.isColab && wallet.inviteCode != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Kode Undangan', 
                                    style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                                const SizedBox(height: 4),
                                Text(wallet.inviteCode!, 
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              ],
                            ),
                            IconButton(
                              onPressed: () {
                                // Implement share or copy logic if needed
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kode berhasil disalin!')),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<List<TransactionModel>>(
                  stream: _firestoreService.getTransactionsStream(wallet.id),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text('Belum ada transaksi',
                            style: TextStyle(color: AppColors.textHint)),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final txn = snapshot.data![index];
                        final isIncome = txn.isIncome;
                        final color = isIncome ? AppColors.income : AppColors.expense;
                        
                        return Dismissible(
                          key: Key(txn.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_sweep_rounded, color: AppColors.expense),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Hapus Transaksi?'),
                                content: const Text('Saldo dompet akan disesuaikan secara otomatis.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Batal'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense, foregroundColor: Colors.white),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) {
                            _firestoreService.deleteTransaction(txn);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transaksi dihapus & Saldo diperbarui!')),
                            );
                          },
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                TransactionCategory.getIconForCategory(txn.category),
                                color: color, size: 20,
                              ),
                            ),
                            title: Text(txn.category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              txn.note.isNotEmpty
                                  ? txn.note
                                  : CurrencyFormatter.formatRelativeDate(txn.date),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '${isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(txn.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color, fontSize: 14,
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
  void _confirmDeleteWallet(WalletModel wallet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Dompet?'),
        content: Text(
          'Semua data transaksi di dompet "${wallet.walletName}" juga akan ikut terhapus selamanya. Yakin?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close bottom sheet detail
              
              await _firestoreService.deleteWallet(wallet.id);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dompet "${wallet.walletName}" berhasil dihapus.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense, 
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onTap;

  const _WalletCard({required this.wallet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
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
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: wallet.isColab
                    ? AppColors.deepBlue.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                wallet.isColab
                    ? Icons.group_rounded
                    : Icons.account_balance_wallet_rounded,
                color: wallet.isColab ? AppColors.deepBlue : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wallet.walletName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    wallet.isColab
                        ? '${wallet.members.length} anggota'
                        : 'Personal',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatCurrency(wallet.balance),
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: wallet.balance >= 0
                    ? AppColors.textPrimary
                    : AppColors.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
