import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../services/auth_service.dart';
import '../../utils/ui_helper.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String _searchQuery = '';
  bool _isSuperAdmin = false;
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    try {
      // Clear cache first to ensure we get latest from Firestore
      _authService.clearCache();

      bool isSuper = await _authService.isSuperAdmin(forceRefresh: true);
      bool isAdmin = await _authService.isAdmin(forceRefresh: true);

      if (mounted) {
        setState(() {
          _isSuperAdmin = isSuper;
          _isAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRoleSelection(String uid, String currentRole, String name) async {
    if (!_isSuperAdmin) return;

    final List<String> roles = ['user', 'admin', 'superadmin'];
    final List<String> roleLabels = [
      'User Biasa',
      'Administrator',
      'Owner / Super Admin'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Atur Role untuk ${name.split(' ')[0]}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Pilih role baru untuk pengguna ini',
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)),
            const SizedBox(height: 24),
            ...List.generate(roles.length, (index) {
              final isCurrent = currentRole == roles[index];
              return ListTile(
                onTap: isCurrent
                    ? null
                    : () => _updateRole(uid, roles[index], name),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.primary.withOpacity(0.1)
                        : Theme.of(context).dividerColor.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    roles[index] == 'superadmin'
                        ? CupertinoIcons.shield_fill
                        : (roles[index] == 'admin'
                            ? CupertinoIcons.checkmark_shield_fill
                            : CupertinoIcons.person_solid),
                    color: isCurrent
                        ? AppColors.primary
                        : (roles[index] == 'superadmin'
                            ? Colors.indigo
                            : (roles[index] == 'admin'
                                ? Colors.blue
                                : Theme.of(context).disabledColor)),
                    size: 20,
                  ),
                ),
                title: Text(roleLabels[index],
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.w900 : FontWeight.normal,
                        color: isCurrent ? AppColors.primary : Theme.of(context).textTheme.titleMedium?.color,
                    )),
                trailing: isCurrent
                    ? Icon(CupertinoIcons.check_mark_circled, color: AppColors.primary)
                    : null,
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _updateRole(String uid, String newRole, String name) async {
    Navigator.pop(context);

    final roleLabel = newRole == 'superadmin'
        ? 'Owner'
        : (newRole == 'admin' ? 'Admin' : 'User Biasa');

    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Ubah Akses?',
      message:
          'Apakah Anda yakin ingin mengubah akses $name menjadi $roleLabel?',
      confirmText: 'YA, UBAH',
      cancelText: 'BATAL',
      isDangerous: false,
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(uid).update({'role': newRole});

        await _firestore
            .collection('app_config')
            .doc('global')
            .collection('history')
            .add({
          'updatedBy': _authService.auth.currentUser?.uid ?? 'system',
          'updatedAt': FieldValue.serverTimestamp(),
          'action': 'ROLE_CHANGE',
          'targetUid': uid,
          'newRole': newRole,
        });

        if (mounted) {
          _showSuccessSheet(
              'Berhasil!', '$name sekarang memiliki akses $roleLabel.');
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showErrorSnackBar(context, 'Gagal ubah akses: $e');
        }
      }
    }
  }

  void _confirmToggleStatus(
      String uid, bool isCurrentlyDeactivated, String name) async {
    if (isCurrentlyDeactivated) {
      final confirm = await UIHelper.showConfirmDialog(
        context: context,
        title: 'Aktifkan Akun?',
        message: 'Apakah Anda yakin ingin mengaktifkan kembali akun $name?',
        confirmText: 'AKTIFKAN',
        cancelText: 'BATAL',
        isDangerous: false,
      );

      if (confirm == true) {
        _updateUserStatus(uid, false, name: name);
      }
    } else {
      _showSuspensionForm(uid, name);
    }
  }

  void _showSuspensionForm(String uid, String name) async {
    final reasonController = TextEditingController();
    String duration = '24'; // Default 1 day
    final durations = {
      '1': '1 Jam',
      '6': '6 Jam',
      '12': '12 Jam',
      '24': '1 Hari',
      '72': '3 Hari',
      '168': '1 Minggu',
      '720': '1 Bulan',
      '0': 'Permanen',
    };

    final result = await UIHelper.showPremiumDialog<Map<String, dynamic>>(
      context: context,
      child: StatefulBuilder(
        builder: (context, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.expense.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.hammer_fill,
                  color: AppColors.expense, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Bekukan Akun $name',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8)),
            const SizedBox(height: 8),
            Text('Berikan alasan dan tentukan durasi pembekuan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color, height: 1.4)),
            const SizedBox(height: 24),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Alasan Pembekuan',
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                hintText: 'Contoh: Melanggar aturan komunitas',
                hintStyle: TextStyle(color: Theme.of(context).disabledColor, fontSize: 13),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                filled: true,
                fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                prefixIcon: const Icon(CupertinoIcons.doc_text, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: duration,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyLarge?.color),
              icon: const Icon(CupertinoIcons.chevron_down),
              items: durations.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (val) => setModalState(() => duration = val!),
              decoration: InputDecoration(
                labelText: 'Durasi Pembekuan',
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                filled: true,
                fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                prefixIcon: const Icon(CupertinoIcons.timer, size: 20),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Center(
                        child: Text('Batal',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (reasonController.text.trim().isEmpty) {
                        UIHelper.showErrorSnackBar(
                            context, 'Masukan alasan pembekuan!');
                        return;
                      }
                      Navigator.pop(context, {
                        'reason': reasonController.text.trim(),
                        'duration': int.parse(duration),
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.expense,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.expense.withOpacity(0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 5)),
                        ],
                      ),
                      child: const Center(
                        child: Text('Bekukan Akun',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
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

    if (result != null) {
      _updateUserStatus(
        uid,
        true,
        name: name,
        reason: result['reason'],
        durationHrs: result['duration'],
      );
    }
  }

  void _updateUserStatus(String uid, bool deactivate,
      {required String name, String? reason, int? durationHrs}) async {
    DateTime? until;
    if (deactivate && durationHrs != null && durationHrs > 0) {
      until = DateTime.now().add(Duration(hours: durationHrs));
    }

    try {
      final updates = <String, dynamic>{
        'isDeactivated': deactivate,
        'deactivatedReason': deactivate ? (reason ?? 'Tanpa alasan.') : null,
        'deactivatedUntil': deactivate
            ? (until != null ? Timestamp.fromDate(until) : null)
            : null,
      };

      await _firestore.collection('users').doc(uid).update(updates);

      // Audit Log
      await _firestore
          .collection('app_config')
          .doc('global')
          .collection('history')
          .add({
        'updatedBy': _authService.auth.currentUser?.uid ?? 'system',
        'updatedAt': FieldValue.serverTimestamp(),
        'action': deactivate ? 'USER_SUSPEND' : 'USER_ACTIVATE',
        'targetUid': uid,
        'reason': reason,
        'durationHrs': durationHrs,
      });

      if (mounted) {
        _showSuccessSheet(
            deactivate ? 'Akun Dibekukan' : 'Akun Diaktifkan',
            deactivate
                ? 'Akun $name berhasil dibekukan.'
                : 'Akun $name sudah bisa digunakan kembali.');
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showErrorSnackBar(context, 'Gagal memproses status: $e');
      }
    }
  }

  void _deleteUser(String uid, String name) async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Hapus User Permanen?',
      message:
          'Tindakan ini tidak bisa dibatalkan. Akun $name akan dihapus selamanya dari sistem.',
      confirmText: 'HAPUS',
      cancelText: 'BATAL',
      isDangerous: true,
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(uid).delete();
        await _firestore
            .collection('app_config')
            .doc('global')
            .collection('history')
            .add({
          'updatedBy': _authService.auth.currentUser?.uid ?? 'system',
          'updatedAt': FieldValue.serverTimestamp(),
          'action': 'DELETE_USER',
          'targetUid': uid,
        });
        if (mounted) {
          _showSuccessSheet(
              'User Dihapus', 'Data user telah dibersihkan dari sistem.');
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showErrorSnackBar(context, 'Gagal menghapus user: $e');
        }
      }
    }
  }

  void _showSuccessSheet(String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            32, 32, 32, MediaQuery.of(ctx).padding.bottom + 32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.check_mark_circled,
                color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('MANTAP')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('User Control Center',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Theme.of(context).textTheme.titleLarge?.color)),
          centerTitle: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          actions: [
            IconButton(
              onPressed: () => _checkRole(),
              icon: const Icon(CupertinoIcons.refresh, color: AppColors.primary),
              tooltip: 'Segarkan Data',
            ),
          ],
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            tabs: const [
              Tab(text: 'PENGGUNA'),
              Tab(text: 'STAFF & ADMIN'),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau email...',
                    prefixIcon: const Icon(CupertinoIcons.search,
                        color: AppColors.primary),
                    fillColor: Theme.of(context).dividerColor.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('users').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allUsers = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name =
                          (data['displayName'] ?? '').toString().toLowerCase();
                      final email =
                          (data['email'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) ||
                          email.contains(_searchQuery);
                    }).toList();

                    return TabBarView(
                      children: [
                        _buildUserList(allUsers, isStaff: false),
                        _buildUserList(allUsers, isStaff: true),
                      ],
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

  Widget _buildUserList(List<QueryDocumentSnapshot> allUsers,
      {required bool isStaff}) {
    final users = allUsers.where((doc) {
      final role = (doc.data() as Map<String, dynamic>)['role'] ?? 'user';
      if (isStaff) return role == 'admin' || role == 'superadmin';
      return role == 'user';
    }).toList();

    // Sorting: Superadmin first, then Admin, then alphabetically by name
    if (isStaff) {
      users.sort((a, b) {
        final roleA = (a.data() as Map<String, dynamic>)['role'] ?? 'user';
        final roleB = (b.data() as Map<String, dynamic>)['role'] ?? 'user';
        final nameA = (a.data() as Map<String, dynamic>)['displayName'] ?? '';
        final nameB = (b.data() as Map<String, dynamic>)['displayName'] ?? '';

        if (roleA == 'superadmin' && roleB != 'superadmin') return -1;
        if (roleA != 'superadmin' && roleB == 'superadmin') return 1;
        if (roleA == 'admin' && roleB != 'admin') return -1;
        if (roleA != 'admin' && roleB == 'admin') return 1;

        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });
    } else {
      users.sort((a, b) {
        final nameA = (a.data() as Map<String, dynamic>)['displayName'] ?? '';
        final nameB = (b.data() as Map<String, dynamic>)['displayName'] ?? '';
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });
    }

    if (users.isEmpty) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              isStaff
                  ? CupertinoIcons.shield_fill
                  : CupertinoIcons.person_badge_minus,
              color: Theme.of(context).disabledColor,
              size: 64),
          const SizedBox(height: 16),
          Text(
              isStaff
                  ? 'Tidak ada staff ditemukan'
                  : 'Tidak ada user ditemukan',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ));
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).padding.bottom + 32),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final doc = users[index];
        final user = doc.data() as Map<String, dynamic>;
        final uid = doc.id;
        final role = user['role'] ?? 'user';
        final isDeactivated = user['isDeactivated'] ?? false;

        final dynamic rawDate = user['createdAt'];
        DateTime joinDate = DateTime.now();
        if (rawDate is Timestamp) {
          joinDate = rawDate.toDate();
        } else if (rawDate is String) {
          joinDate = DateTime.tryParse(rawDate) ?? DateTime.now();
        }
        final String joinDateStr = DateFormat('dd MMM yyyy').format(joinDate);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: role == 'superadmin'
                    ? Colors.amber.withOpacity(0.3)
                    : Theme.of(context).dividerColor.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                  color: role == 'superadmin'
                      ? Colors.amber.withOpacity(0.05)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: user['photoURL'] != null &&
                            user['photoURL'].toString().isNotEmpty
                        ? NetworkImage(user['photoURL'])
                        : null,
                    child: (user['photoURL'] == null ||
                            user['photoURL'].toString().isEmpty)
                        ? const Icon(CupertinoIcons.person)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isDeactivated ? Colors.red : Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(user['displayName'] ?? 'User',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Theme.of(context).textTheme.titleMedium?.color,
                                  overflow: TextOverflow.ellipsis)),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: role == 'superadmin'
                                  ? Colors.amber.withOpacity(0.1)
                                  : role == 'admin'
                                      ? AppColors.primary.withOpacity(0.1)
                                      : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                role == 'superadmin'
                                    ? 'OWNER'
                                    : role == 'admin'
                                        ? 'ADMIN'
                                        : 'MEMBER',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: role == 'superadmin'
                                        ? Colors.amber[900]
                                        : role == 'admin'
                                            ? AppColors.primary
                                            : Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(user['email'] ?? 'No email',
                          style:
                              TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
                    ),
                    const SizedBox(height: 4),
                    Text('Joined: $joinDateStr',
                        style:
                            TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5), fontSize: 10)),
                  ],
                ),
              ),
              if (_isSuperAdmin || (_isAdmin && role == 'user'))
                _buildActionMenu(
                    uid, role, isDeactivated, user['displayName'] ?? 'User'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionMenu(
      String uid, String role, bool isDeactivated, String name) {
    final bool canManageRole = _isSuperAdmin;
    final bool canManageStatus = _isSuperAdmin || (_isAdmin && role == 'user');
    final bool canDelete = _isSuperAdmin;

    return PopupMenuButton<String>(
      icon: const Icon(CupertinoIcons.ellipsis_vertical, color: Colors.grey),
      onSelected: (val) {
        if (val == 'role') _showRoleSelection(uid, role, name);
        if (val == 'status') _confirmToggleStatus(uid, isDeactivated, name);
        if (val == 'delete') _deleteUser(uid, name);
      },
      itemBuilder: (ctx) => [
        if (canManageRole)
          PopupMenuItem(
            value: 'role',
            child: Row(
              children: [
                Icon(CupertinoIcons.person_crop_circle_badge_checkmark,
                    size: 20, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Text('Ubah Role Akun', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (canManageStatus)
          PopupMenuItem(
            value: 'status',
            child: Row(
              children: [
                Icon(
                    isDeactivated
                        ? CupertinoIcons.check_mark_circled
                        : CupertinoIcons.slash_circle,
                    size: 20,
                    color: isDeactivated ? Colors.green : Colors.red),
                const SizedBox(width: 12),
                Text(isDeactivated ? 'Aktifkan User' : 'Bekukan Akun',
                    style: TextStyle(
                        color: isDeactivated ? Colors.green : Colors.red,
                        fontSize: 13)),
              ],
            ),
          ),
        if (canDelete) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(CupertinoIcons.trash_fill,
                    size: 20, color: Colors.black),
                const SizedBox(width: 12),
                const Text('Hapus Permanen',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
        if (!canManageRole && !canManageStatus && !canDelete)
          const PopupMenuItem(
            enabled: false,
            child: Text('Hak akses terbatas', style: TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}
