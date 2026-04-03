import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/ui_helper.dart';
import '../services/firestore_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _occupationController = TextEditingController();
  
  bool _isLoading = false;
  bool _isEditing = false;
  String _gender = 'Prefer not to say'; // Default value
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Langsung munculin data lokal dari FirebaseAuth tanpa loading
      setState(() {
        _nameController.text = user.displayName ?? '';
      });
      
      // Ambil sisa data (gender, pekerjaan, tgl lahir) dari Firestore di latar
      try {
        final userInfo = await _firestoreService.getUserInfo(user.uid);
        if (userInfo != null && mounted) {
          setState(() {
            if (userInfo.containsKey('gender')) {
              _gender = userInfo['gender'];
            }
            if (userInfo.containsKey('occupation')) {
              _occupationController.text = userInfo['occupation'];
            }
            if (userInfo.containsKey('dateOfBirth')) {
              final dobData = userInfo['dateOfBirth'];
              if (dobData != null) {
                if (dobData is String) {
                  _dateOfBirth = DateTime.tryParse(dobData);
                } else {
                  _dateOfBirth = dobData.toDate(); 
                }
              }
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    if (!_isEditing) return;
    
    // Gunakan cupertino date picker style widget kalau mau full iOS feel, 
    // tapi Material showDatePicker yg dimodifikasi warnanya juga cukup iOS-ish untuk fungsi.
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    final newOccupation = _occupationController.text.trim();
    if (newName.isEmpty) {
      UIHelper.showErrorSnackBar(context, 'Nama tidak boleh kosong');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
        
        final data = {
          'displayName': newName,
          'gender': _gender,
          'occupation': newOccupation,
        };
        
        if (_dateOfBirth != null) {
          data['dateOfBirth'] = _dateOfBirth!.toIso8601String(); 
        }
        
        await _firestoreService.updateUserProfile(user.uid, data);

        if (mounted) {
          setState(() {
            _isEditing = false;
          });
          UIHelper.showSuccessSnackBar(context, 'Profil berhasil diperbarui! ✨');
        }
      }
    } catch (e) {
      if (mounted) {
        UIHelper.showErrorSnackBar(context, 'Gagal memperbarui profil: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCupertinoTile({
    required IconData icon,
    required String title,
    required Widget child,
    Color iconColor = AppColors.primary,
    bool showBorder = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: showBorder
            ? Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 0.5,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1C1C1E),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      readOnly: !_isEditing,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 15,
        color: _isEditing ? Colors.black : Colors.grey.shade600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS native grouped background
      appBar: AppBar(
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Color(0xFF1C1C1E),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            CupertinoButton(
              padding: const EdgeInsets.only(right: 16),
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          if (_isEditing)
            CupertinoButton(
              padding: const EdgeInsets.only(right: 16),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadUserProfile(); // Revert
              },
              child: const Text('Batal', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // Profile Header section
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                              // Use Google photoURL if signed in via Google, otherwise null
                              image: FirebaseAuth.instance.currentUser?.photoURL != null
                                  ? DecorationImage(
                                      image: NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            // Show icon only if there is no profile photo
                            child: FirebaseAuth.instance.currentUser?.photoURL == null
                                ? const Icon(CupertinoIcons.person_solid, size: 45, color: AppColors.primary)
                                : null,
                          ),
                          const SizedBox(height: 24), // Spacing diperbesar agar teks tidak terlalu mepet dengan border biru
                          Text(
                            _nameController.text.isNotEmpty ? _nameController.text : 'Pengguna',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FirebaseAuth.instance.currentUser?.email ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),

                    // Information Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCupertinoTile(
                            icon: CupertinoIcons.person_fill,
                            title: 'Nama Lengkap',
                            child: _buildFormField(_nameController, 'Masukkan Nama'),
                          ),
                          _buildCupertinoTile(
                            icon: CupertinoIcons.person_3_fill,
                            title: 'Gender',
                            iconColor: Colors.purple,
                            child: _isEditing
                                ? DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _gender,
                                      isExpanded: true,
                                      alignment: Alignment.centerRight,
                                      icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                                      style: const TextStyle(fontSize: 15, color: Colors.black),
                                      items: const [
                                        DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                                        DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                                        DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _gender = val);
                                      },
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      _gender,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                                    ),
                                  ),
                          ),
                          _buildCupertinoTile(
                            icon: CupertinoIcons.calendar,
                            title: 'Tanggal Lahir',
                            iconColor: Colors.orange,
                            child: InkWell(
                              onTap: _pickDateOfBirth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  _dateOfBirth != null
                                      ? DateFormat('dd MMM yyyy').format(_dateOfBirth!)
                                      : 'Pilih Tanggal',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _dateOfBirth == null ? AppColors.textHint : (_isEditing ? AppColors.primary : Colors.grey.shade600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildCupertinoTile(
                            icon: CupertinoIcons.briefcase_fill,
                            title: 'Pekerjaan',
                            iconColor: Colors.teal,
                            showBorder: false,
                            child: _buildFormField(_occupationController, 'Mis: Mahasiswa'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isLoading ? null : _saveProfile,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Simpan Perubahan',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

