import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../services/firestore_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/debt_service.dart';
import '../../models/wallet_model.dart';
import '../../utils/ui_helper.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';

/// Public helper function to open Create Wallet Modal Overlay directly from anywhere
void showCreateWalletSheet(BuildContext context) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final firestoreService = FirestoreService();
  final debtService = DebtService();

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
            isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
        final sectionColor =
            isDark ? const Color(0xFF27272A) : Colors.white;
        final primaryAccent =
            isDark ? const Color(0xFFE4E4E7) : const Color(0xFF18181B);
        final iconBgColor =
            isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05);
        final iconColor =
            isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
        final borderColor = isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.05);

        return Container(
          height: MediaQuery.of(sbCtx).size.height * 0.85,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sbCtx).viewInsets.bottom +
                (MediaQuery.of(sbCtx).padding.bottom > 0
                    ? MediaQuery.of(sbCtx).padding.bottom + 12
                    : 24),
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // iOS Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Action Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: borderColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(sbCtx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Text(
                      'Dompet Baru',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
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

                              await debtService.addDebt(
                                currentUserId: uid,
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
                            id: '',
                            walletName: nameController.text,
                            balance: 0,
                            type: selectedType,
                            members: [uid],
                            owner: uid,
                            createdAt: DateTime.now(),
                          );

                          if (!isOnline) {
                            firestoreService.createWallet(newWallet);
                            if (!sbCtx.mounted) return;
                            Navigator.pop(sbCtx);
                            UIHelper.showInfoSnackBar(
                                sbCtx, 'Dompet dibuat offline');
                            return;
                          }

                          try {
                            await firestoreService
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
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Simpan',
                        style: TextStyle(
                          color: primaryAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Type Selection
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        child: Text(
                          'TIPE DOMPET',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
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
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
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

                      const SizedBox(height: 20),

                      // Section 2: Main Info
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        child: Text(
                          'INFORMASI UTAMA',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: sectionColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            if (selectedType == 'debt') ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(CupertinoIcons.person_fill,
                                          size: 16, color: iconColor),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: debtorNameController,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Nama Teman / Pihak Lain',
                                          hintStyle: TextStyle(
                                              fontSize: 15,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
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
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                          CupertinoIcons
                                              .person_crop_circle_fill_badge_plus,
                                          size: 22,
                                          color: iconColor),
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
                                              nameController
                                                  .text = debtType ==
                                                      'payable'
                                                  ? 'Hutang ke ${contact.displayName}'
                                                  : 'Piutang ${contact.displayName}';
                                            });
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  indent: 62,
                                  color: borderColor),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(CupertinoIcons.phone_fill,
                                          size: 16, color: iconColor),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: debtorPhoneController,
                                        keyboardType: TextInputType.phone,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Nomor HP (Opsional)',
                                          hintStyle: TextStyle(
                                              fontSize: 15,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.black38),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  indent: 62,
                                  color: borderColor),
                              _buildIOSRadioTile(sbCtx, setModalState,
                                  'Saya Berhutang', 'payable', debtType, (v) {
                                debtType = v;
                                if (debtorNameController.text.isNotEmpty) {
                                  nameController.text =
                                      'Hutang ke ${debtorNameController.text}';
                                }
                              }),
                              Divider(
                                  height: 1,
                                  indent: 62,
                                  color: borderColor),
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
                                  color: borderColor),
                            ],

                            // Name Controller Input
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconBgColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      selectedType == 'colab'
                                          ? CupertinoIcons.person_2_fill
                                          : selectedType == 'debt'
                                              ? CupertinoIcons.doc_text_fill
                                              : CupertinoIcons.creditcard_fill,
                                      color: iconColor,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: nameController,
                                      textCapitalization: TextCapitalization.words,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: selectedType == 'colab'
                                            ? 'Nama kelompok/tujuan'
                                            : selectedType == 'debt'
                                                ? 'Label Catatan (Misal: Hutang Budi)'
                                                : 'Nama dompet (misal: Jajan)',
                                        hintStyle: TextStyle(
                                            fontSize: 15,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (selectedType == 'debt') ...[
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          child: Text(
                            'NOMINAL & SUMBER DANA',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black45,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: sectionColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Text(
                                      'Rp',
                                      style: TextStyle(
                                        color: iconColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: totalAmountController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly
                                        ],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          hintStyle: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  indent: 16,
                                  color: borderColor),
                              StreamBuilder<List<WalletModel>>(
                                stream: firestoreService.getWalletsStream(uid),
                                builder: (ctx, snapshot) {
                                  if (!snapshot.hasData) return const SizedBox.shrink();
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
                                      setModalState(
                                          () => selectedWalletId = wallet.id);
                                    }),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(CupertinoIcons.creditcard_fill,
                                          size: 16,
                                          color: iconColor),
                                    ),
                                    title: Text(
                                      selectedWallet != null
                                          ? selectedWallet.walletName
                                          : 'Pilih Dompet Sumber/Tujuan',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: selectedWallet != null
                                              ? FontWeight.w600
                                              : FontWeight.w400,
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
                                            ? Colors.white38
                                            : Colors.black38),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),
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
  final activeBg = isDark ? const Color(0xFF3F3F46) : const Color(0xFF18181B);

  return Expanded(
    child: GestureDetector(
      onTap: () => setState(() => onSelect(type)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: activeBg.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    ),
  );
}

Widget _buildIOSRadioTile(BuildContext context, StateSetter setState,
    String title, String value, String groupValue, Function(String) onSelect) {
  final isSelected = value == groupValue;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final activeColor = isDark ? const Color(0xFFE4E4E7) : const Color(0xFF18181B);

  return InkWell(
    onTap: () => setState(() => onSelect(value)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Icon(
            isSelected
                ? CupertinoIcons.checkmark_alt_circle_fill
                : CupertinoIcons.circle,
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white24 : Colors.black26),
            size: 22,
          ),
        ],
      ),
    ),
  );
}

void _showWalletPicker(BuildContext context, List<WalletModel> wallets,
    Function(WalletModel) onSelect) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  String searchQuery = '';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (bottomCtx) => StatefulBuilder(
      builder: (sbCtx, setModalState) {
        final safeBottom = MediaQuery.of(sbCtx).padding.bottom;
        final filtered = wallets
            .where((w) =>
                w.walletName.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

        return Container(
          height: MediaQuery.of(sbCtx).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
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
                'Pilih Dompet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CupertinoSearchTextField(
                  placeholder: 'Cari dompet...',
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E)),
                  onChanged: (val) {
                    setModalState(() {
                      searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.creditcard,
                              size: 48,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Dompet tidak ditemukan',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 15,
                              ),
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
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 50,
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.05),
                        ),
                        itemBuilder: (ctx, i) {
                          final w = filtered[i];
                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onSelect(w);
                              Navigator.pop(ctx);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF27272A)
                                          : const Color(0xFFF4F4F5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      CupertinoIcons.creditcard_fill,
                                      color: isDark
                                          ? const Color(0xFFA1A1AA)
                                          : const Color(0xFF71717A),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.walletName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF1C1C1E),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          CurrencyFormatter.formatCurrency(
                                              w.balance),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? const Color(0xFFA1A1AA)
                                                : const Color(0xFF71717A),
                                          ),
                                        ),
                                      ],
                                    ),
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
        );
      },
    ),
  );
}

void _showContactPicker(BuildContext context, List<Contact> contacts,
    Function(Contact) onSelect) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final safeBottom = MediaQuery.of(context).padding.bottom;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Pilih Kontak',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: safeBottom > 0 ? safeBottom + 24 : 24,
              ),
              itemCount: contacts.length,
              itemBuilder: (ctx, i) {
                final c = contacts[i];
                final phone =
                    c.phones.isNotEmpty ? c.phones.first.number : 'Tidak ada nomor';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.pastelBlue.withOpacity(0.12),
                    child: Text(
                      c.displayName.isNotEmpty
                          ? c.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppColors.pastelBlue,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(c.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(phone, style: const TextStyle(fontSize: 12)),
                  onTap: () {
                    onSelect(c);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
