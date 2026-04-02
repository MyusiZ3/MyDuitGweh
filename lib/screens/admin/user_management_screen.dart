import 'package:flutter/material.dart';
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Atur Kasta ${name.split(' ')[0]}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Pilih peran baru untuk pengguna ini',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
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
                        : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    roles[index] == 'superadmin'
                        ? Icons.shield_rounded
                        : (roles[index] == 'admin'
                            ? Icons.verified_user_rounded
                            : Icons.person_rounded),
                    color: isCurrent
                        ? AppColors.primary
                        : (roles[index] == 'superadmin'
                            ? Colors.indigo
                            : (roles[index] == 'admin'
                                ? Colors.blue
                                : Colors.grey)),
                    size: 20,
                  ),
                ),
                title: Text(roleLabels[index],
                    style: TextStyle(
                      fontWeight:
                          isCurrent ? FontWeight.w900 : FontWeight.normal,
                      color: isCurrent ? AppColors.primary : Colors.black,
                    )),
                trailing: isCurrent
                    ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
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
        if (mounted)
          UIHelper.showErrorSnackBar(context, 'Gagal ubah akses: $e');
      }
    }
  }

  void _confirmToggleStatus(String uid, bool currentStatus, String name) async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: currentStatus ? 'Aktifkan Akun?' : 'Bekukan Akun?',
      message:
          'Apakah Anda yakin ingin ${currentStatus ? 'mengaktifkan kembali' : 'membekukan'} akun $name?',
      confirmText: currentStatus ? 'AKTIFKAN' : 'BEKUKAN',
      cancelText: 'BATAL',
      isDangerous: !currentStatus,
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .update({'isDeactivated': !currentStatus});
        await _firestore
            .collection('app_config')
            .doc('global')
            .collection('history')
            .add({
          'updatedBy': _authService.auth.currentUser?.uid ?? 'system',
          'updatedAt': FieldValue.serverTimestamp(),
          'action': 'STATUS_CHANGE',
          'targetUid': uid,
          'newStatus': !currentStatus ? 'active' : 'deactivated',
        });
        if (mounted)
          _showSuccessSheet(
              'Status Diperbarui', 'Status akun telah berhasil diubah.');
      } catch (e) {
        if (mounted)
          UIHelper.showErrorSnackBar(context, 'Gagal ubah status: $e');
      }
    }
  }

  void _deleteUser(String uid, String name) async {
    final confirm = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Hapus User Permanen?',
      message:
          'Tindakan ini tidak bisa dibatalkan. Akun $name akan dihapus selamanya dari sistem.',
      confirmText: 'HAPUS PERMANEN',
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
        if (mounted)
          _showSuccessSheet(
              'User Dihapus', 'Data user telah dibersihkan dari sistem.');
      } catch (e) {
        if (mounted)
          UIHelper.showErrorSnackBar(context, 'Gagal menghapus user: $e');
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
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
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('User Control Center',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _checkRole(),
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Segarkan Data',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.primary),
                  fillColor: AppColors.surfaceVariant.withOpacity(0.5),
                ),
                onChanged: (val) =>
                    setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final users = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name =
                        (data['displayName'] ?? '').toString().toLowerCase();
                    final email =
                        (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery);
                  }).toList();

                  if (users.isEmpty) {
                    return Center(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_rounded,
                            color: Colors.grey[300], size: 64),
                        const SizedBox(height: 16),
                        const Text('Tidak ada user ditemukan',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                        24, 0, 24, MediaQuery.of(context).padding.bottom + 32),
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
                      final String joinDateStr =
                          DateFormat('dd MMM yyyy').format(joinDate);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.surfaceVariant),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.02),
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
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: isDeactivated
                                          ? Colors.red
                                          : Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
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
                                        child: Text(
                                            user['displayName'] ?? 'User',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                                overflow:
                                                    TextOverflow.ellipsis)),
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
                                                    ? AppColors.primary
                                                        .withOpacity(0.1)
                                                    : AppColors.surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(8),
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
                                  Text(user['email'] ?? 'No email',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('Joined: $joinDateStr',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 10)),
                                ],
                              ),
                            ),
                            if (_isSuperAdmin || (_isAdmin && role == 'user'))
                              _buildActionMenu(uid, role, isDeactivated,
                                  user['displayName'] ?? 'User'),
                          ],
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
    );
  }

  Widget _buildActionMenu(
      String uid, String role, bool isDeactivated, String name) {
    final bool canManageRole = _isSuperAdmin;
    final bool canManageStatus = _isSuperAdmin || (_isAdmin && role == 'user');
    final bool canDelete = _isSuperAdmin;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
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
                Icon(Icons.theater_comedy_rounded,
                    size: 20, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Text('Ubah Kasta Akun', style: TextStyle(fontSize: 13)),
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
                        ? Icons.check_circle_rounded
                        : Icons.block_flipped,
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
                const Icon(Icons.delete_forever_rounded,
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
