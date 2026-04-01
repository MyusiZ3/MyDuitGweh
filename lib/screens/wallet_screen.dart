import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
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
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  
  // Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Cari nama dompet...',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w400),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              )
            : const Text('Dompet Saya'),
          backgroundColor: AppColors.background,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textHint,
            tabs: [
              Tab(text: 'Pribadi'),
              Tab(text: 'Bersama'),
              Tab(text: 'Hutang'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = "";
                  }
                });
              },
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: AppColors.primary),
            ),
            IconButton(
              onPressed: _showCreateWalletDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            ),
          ],
        ),
        body: StreamBuilder<List<WalletModel>>(
          stream: _firestoreService.getWalletsStream(_uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());

            final wallets = snapshot.data ?? [];
            
            // Filter wallets by search query
            final filteredWallets = wallets.where((w) {
              return w.walletName.toLowerCase().contains(_searchQuery);
            }).toList();

            final personalWallets = filteredWallets.where((w) => w.isPersonal).toList();
            final colabWallets = filteredWallets.where((w) => w.isColab).toList();
            final debtWallets = filteredWallets.where((w) => w.isDebt).toList();

            return TabBarView(
              physics: const BouncingScrollPhysics(),
              children: [
                // Tab 1: Pribadi
                personalWallets.isEmpty 
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: personalWallets.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WalletCard(wallet: personalWallets[index], onTap: () => _showWalletDetails(personalWallets[index]))
                      ),
                    ),
                
                // Tab 2: Bersama
                colabWallets.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: colabWallets.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WalletCard(wallet: colabWallets[index], onTap: () => _showWalletDetails(colabWallets[index]))
                      ),
                    ),

                // Tab 3: Hutang
                debtWallets.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: debtWallets.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _WalletCard(wallet: debtWallets[index], onTap: () => _showWalletDetails(debtWallets[index]))
                      ),
                    ),
              ],
            );
          },
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
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
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
                const Text('Buat Dompet Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTypeOption(setModalState, 'personal', 'Pribadi', Icons.person_outline, selectedType, (val) => selectedType = val),
                    const SizedBox(width: 8),
                    _buildTypeOption(setModalState, 'colab', 'Bersama', Icons.groups_outlined, selectedType, (val) => selectedType = val),
                    const SizedBox(width: 8),
                    _buildTypeOption(setModalState, 'debt', 'Hutang', Icons.handshake_outlined, selectedType, (val) => selectedType = val),
                  ],
                ),
                const SizedBox(height: 20),
                if (selectedType == 'debt') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Posisi Anda', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textHint)),
                        Row(
                          children: [
                            Expanded(child: RadioListTile<String>(
                              title: const Text('Saya Ngutang', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              value: 'payable',
                              groupValue: debtType,
                              onChanged: (val) => setModalState(() => debtType = val!),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: AppColors.primary,
                            )),
                            Expanded(child: RadioListTile<String>(
                              title: const Text('Saya Minjamin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              value: 'receivable',
                              groupValue: debtType,
                              onChanged: (val) => setModalState(() => debtType = val!),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: AppColors.primary,
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
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.contacts, color: AppColors.primary),
                              onPressed: () async {
                                var status = await Permission.contacts.status;
                                if (!status.isGranted) {
                                  status = await Permission.contacts.request();
                                }
                                if (status.isGranted) {
                                  final contacts = await FlutterContacts.getContacts(withProperties: true);
                                  if (!context.mounted) return;
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (ctx) => ListView.builder(
                                      itemCount: contacts.length,
                                      itemBuilder: (ctx, i) => ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: AppColors.primary.withOpacity(0.1),
                                          child: Text(contacts[i].displayName.isNotEmpty ? contacts[i].displayName[0] : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                                        ),
                                        title: Text(contacts[i].displayName),
                                        subtitle: Text(contacts[i].phones.isNotEmpty ? contacts[i].phones.first.number : 'Tanpa nomor HP'),
                                        onTap: () {
                                          setModalState(() {
                                            debtorNameController.text = contacts[i].displayName;
                                            if (contacts[i].phones.isNotEmpty) {
                                              debtorPhoneController.text = contacts[i].phones.first.number;
                                            }
                                            nameController.text = debtType == 'payable' ? 'Hutang ke ${contacts[i].displayName}' : 'Piutang ${contacts[i].displayName}';
                                          });
                                          Navigator.pop(ctx);
                                        },
                                      )
                                    )
                                  );
                                } else if (status.isPermanentlyDenied) {
                                  if (!context.mounted) return;
                                  UIHelper.showErrorSnackBar(context, 'Izin kontak ditolak permanen. Buka Settings untuk mengizinkan.');
                                  openAppSettings();
                                } else {
                                  if (!context.mounted) return;
                                  UIHelper.showErrorSnackBar(context, 'Izin akses kontak ditolak!');
                                }
                              }
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: debtorPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'Nomor HP (bisa via kontak)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ]
                    )
                  )
                ],
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: selectedType == 'colab' ? 'Nama kelompok/tujuan' : selectedType == 'debt' ? 'Label Catatan (Misal: Hutang Budi)' : 'Nama dompet (misal: Jajan)',
                    prefixIcon: Icon(selectedType == 'colab' ? Icons.groups_rounded : selectedType == 'debt' ? Icons.receipt_long : Icons.account_balance_wallet_outlined, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty) {
                        final newWallet = WalletModel(
                          id: '', // Will be set by service
                          walletName: nameController.text,
                          balance: 0,
                          type: selectedType,
                          members: [_uid],
                          owner: _uid,
                          createdAt: DateTime.now(),
                          debtorName: selectedType == 'debt' ? debtorNameController.text : null,
                          debtorPhone: selectedType == 'debt' ? debtorPhoneController.text : null,
                          debtType: selectedType == 'debt' ? debtType : null,
                        );
                        
                        await _firestoreService.createWallet(newWallet);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        UIHelper.showSuccessSnackBar(context, 'Dompet "${nameController.text}" berhasil dibuat! 🎉');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Simpan Dompet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () { Navigator.pop(context); _showJoinWalletDialog(); },
                    child: const Text('Sudah punya kode undangan? Gabung di sini', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(StateSetter setModalState, String type, String label, IconData icon, String current, Function(String) onSelect) {
    final isSelected = current == type;
    return Expanded(
      child: InkWell(
        onTap: () => setModalState(() => onSelect(type)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.textHint.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.textHint, size: 24),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textHint, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinWalletDialog() {
    final codeController = TextEditingController();
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Gabung Dompet Bersama'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Masukkan 6 digit kode undangan dari temanmu untuk mulai mencatat bersama.'),
                const SizedBox(height: 20),
                TextField(
                  controller: codeController,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: 'ABCXYZ',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isChecking ? null : () => Navigator.pop(context), 
              child: const Text('Batal', style: TextStyle(color: AppColors.textHint))
            ),
            ElevatedButton(
              onPressed: isChecking ? null : () async {
                if (codeController.text.length == 6) {
                  setDialogState(() => isChecking = true);
                  final success = await _firestoreService.joinWalletByCode(codeController.text, _uid);
                  if (!context.mounted) return;
                  Navigator.pop(context); // Close dialog
                  if (success) {
                    UIHelper.showSuccessSnackBar(context, 'Berhasil bergabung! Selamat berkolaborasi 🎉');
                  } else {
                    UIHelper.showErrorSnackBar(context, 'Kode tidak valid atau kamu sudah bergabung ❌');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isChecking 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Gabung Sekarang', style: TextStyle(color: Colors.white)),
            ),
          ],
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
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(wallet.walletName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            wallet.isDebt
                              ? (wallet.debtType == 'payable' ? 'Hutang (Saya Ngutang)' : 'Piutang (Saya Minjamin)')
                              : wallet.isColab ? 'Dompet Bersama' : 'Dompet Pribadi',
                            style: TextStyle(color: wallet.isDebt ? AppColors.warning : AppColors.textHint, fontWeight: wallet.isDebt ? FontWeight.w600 : FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    if (wallet.owner == _uid || !wallet.isColab)
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                        onPressed: () async {
                          final confirm = await UIHelper.showConfirmDialog(
                            context: context, 
                            title: '${ToneManager.t('dialog_del_wallet_title')} "${wallet.walletName}"?',
                            message: ToneManager.t('dialog_del_wallet_msg'),
                          );
                          if (confirm == true) {
                            await _firestoreService.deleteWallet(wallet.id);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            UIHelper.showSuccessSnackBar(context, 'Dompet berhasil dihapus');
                          }
                        },
                      )
                    else 
                      IconButton(
                        icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.expense),
                        onPressed: () async {
                          final confirm = await UIHelper.showConfirmDialog(
                            context: context, 
                            title: '${ToneManager.t('dialog_leave_wallet_title')} "${wallet.walletName}"?',
                            message: ToneManager.t('dialog_leave_wallet_msg'),
                          );
                          if (confirm == true) {
                            await _firestoreService.leaveWallet(wallet.id, _uid);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            UIHelper.showSuccessSnackBar(context, 'Berhasil keluar dari dompet. 👋');
                          }
                        },
                      ),
                  ],
                ),
              ),
              if (wallet.isColab) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('KODE UNDANGAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 1)),
                          const SizedBox(height: 6),
                          Text(
                            wallet.inviteCode ?? '-', 
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: AppColors.primary)
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: wallet.inviteCode ?? ''));
                          UIHelper.showSuccessSnackBar(context, 'Kode disalin ke clipboard! 📋');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Salin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
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
                    color: (wallet.debtType == 'payable' ? AppColors.expense : AppColors.income).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (wallet.debtType == 'payable' ? AppColors.expense : AppColors.income).withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            wallet.debtType == 'payable' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 18,
                            color: wallet.debtType == 'payable' ? AppColors.expense : AppColors.income,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            wallet.debtType == 'payable' ? 'SAYA NGUTANG' : 'SAYA MINJAMIN',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2,
                              color: wallet.debtType == 'payable' ? AppColors.expense : AppColors.income,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_rounded, color: AppColors.textHint),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.debtorName?.isNotEmpty == true ? wallet.debtorName! : 'Tidak disebutkan',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              if (wallet.debtorPhone?.isNotEmpty == true)
                                Text(
                                  wallet.debtorPhone!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textHint),
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
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final txns = snapshot.data!;
                    if (txns.isEmpty) return const Center(child: Text('Belum ada transaksi', style: TextStyle(color: AppColors.textHint)));
                    
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
                            return await UIHelper.showConfirmDialog(
                              context: context, 
                              title: ToneManager.t('dialog_del_tx_title'),
                              message: ToneManager.t('dialog_del_tx_msg'),
                            );
                          },
                          onDismissed: (direction) async {
                            await _firestoreService.deleteTransaction(t);
                            if (!context.mounted) return;
                            UIHelper.showSuccessSnackBar(context, 'Transaksi berhasil dihapus');
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.expense.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (t.isIncome ? AppColors.income : AppColors.expense).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                TransactionCategory.getIconForCategory(t.category),
                                color: t.isIncome ? AppColors.income : AppColors.expense,
                              ),
                            ),
                            title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('dd MMM yyyy • HH:mm').format(t.date), style: const TextStyle(fontSize: 12)),
                                if (wallet.isColab) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Dibuat oleh: ${t.createdByName}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ]
                              ],
                            ),
                            trailing: Text(
                              '${t.isIncome ? '+' : '-'}${CurrencyFormatter.formatCurrency(t.amount)}',
                              style: TextStyle(
                                color: t.isIncome ? AppColors.income : AppColors.expense,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 80, color: AppColors.textHint.withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text('Belum ada dompet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Ayo buat satu untuk mulai mencatat!', style: TextStyle(color: AppColors.textHint)),
          const SizedBox(height: 32),
          SizedBox(
            width: 220, // Give it a fixed width for better balance
            height: 52,
            child: ElevatedButton(
              onPressed: _showCreateWalletDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Buat Dompet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
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

  Color get _cardAccent {
    if (wallet.isDebt) {
      return wallet.debtType == 'payable' ? AppColors.expense : AppColors.income;
    }
    if (wallet.isColab) return AppColors.deepBlue;
    return AppColors.primary;
  }

  IconData get _cardIcon {
    if (wallet.isDebt) return Icons.handshake_rounded;
    if (wallet.isColab) return Icons.group_rounded;
    return Icons.account_balance_wallet_rounded;
  }

  String get _subtitle {
    if (wallet.isDebt) {
      final label = wallet.debtType == 'payable' ? 'Hutang' : 'Piutang';
      final name = wallet.debtorName?.isNotEmpty == true ? ' · ${wallet.debtorName}' : '';
      return '$label$name';
    }
    if (wallet.isColab) return 'Bersama (${wallet.members.length} anggota)';
    return 'Pribadi';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _cardAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_cardIcon, color: _cardAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wallet.walletName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    _subtitle,
                    style: TextStyle(fontSize: 12, color: _cardAccent, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.formatCurrency(wallet.balance),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}
