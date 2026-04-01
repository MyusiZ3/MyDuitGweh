import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  void _toggleAdmin(String uid, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    await _firestore.collection('users').doc(uid).update({'role': newRole});
    
    // Save history
    await _firestore.collection('app_config').doc('global').collection('history').add({
      'updatedBy': _firestore.app.options.projectId,
      'updatedAt': FieldValue.serverTimestamp(),
      'changes': {
        'uid': uid,
        'newRole': newRole,
      }
    });

    if (mounted) {
      _showSuccessSheet('Role Updated', 'Perubahan role user telah berhasil disimpan dan dicatat.');
    }
  }

  void _showSuccessSheet(String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(32, 32, 32, MediaQuery.of(ctx).padding.bottom + 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('MANTAP')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmToggleStatus(String uid, bool isDeactivated, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeactivated ? 'Aktifkan User?' : 'Bekukan User?'),
        content: Text('Apakah kamu yakin ingin ${isDeactivated ? 'mengaktifkan kembali' : 'membekukan sementara'} akun $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('users').doc(uid).update({'isDeactivated': !isDeactivated});
              if (mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: isDeactivated ? Colors.green : Colors.red),
            child: Text(isDeactivated ? 'AKTIFKAN' : 'BEKUKAN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('User Control Center', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  fillColor: AppColors.surfaceVariant.withOpacity(0.5),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final users = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['displayName'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 32), 
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final doc = users[index];
                      final user = doc.data() as Map<String, dynamic>;
                      final uid = doc.id;
                      final role = user['role'] ?? 'user';
                      final isDeactivated = user['isDeactivated'] ?? false;
                      
                      // Safe access to Join Date
                      final dynamic rawDate = user['createTime'];
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.surfaceVariant),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundImage: user['photoURL'] != null ? NetworkImage(user['photoURL']) : null,
                                  child: user['photoURL'] == null ? const Icon(Icons.person) : null,
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
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, overflow: TextOverflow.ellipsis)),
                                      ),
                                      if (role == 'admin') ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
                                      ],
                                    ],
                                  ),
                                  Text(user['email'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Joined $joinDateStr', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ),
                                ],
                              ),
                            ),
                            _buildActionMenu(uid, role, isDeactivated, user['displayName'] ?? 'User'),
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

  Widget _buildActionMenu(String uid, String role, bool isDeactivated, String name) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
      onSelected: (val) {
        if (val == 'admin') _toggleAdmin(uid, role);
        if (val == 'status') _confirmToggleStatus(uid, isDeactivated, name);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'admin',
          child: Row(
            children: [
              Icon(role == 'admin' ? Icons.person_remove_rounded : Icons.admin_panel_settings_rounded, size: 20),
              const SizedBox(width: 12),
              Text(role == 'admin' ? 'Remove Admin' : 'Make Admin'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              Icon(isDeactivated ? Icons.check_circle_rounded : Icons.block_flipped, size: 20, color: isDeactivated ? Colors.green : Colors.red),
              const SizedBox(width: 12),
              Text(isDeactivated ? 'Activate User' : 'Deactivate', style: TextStyle(color: isDeactivated ? Colors.green : Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
