import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../utils/ui_helper.dart';
import '../services/firestore_service.dart';
import '../utils/tone_dictionary.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static const Color pastelBlue = Color(0xFF60A5FA);

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

    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            brightness: Theme.of(context).brightness,
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: EditProfileScreen.pastelBlue,
                  onPrimary: Colors.white,
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
      UIHelper.showErrorSnackBar(context, ToneManager.t('error_empty_field'));
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
          UIHelper.showSuccessSnackBar(
              context, ToneManager.t('success_update_profile'));
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
    Color iconColor = EditProfileScreen.pastelBlue,
    bool showBorder = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: showBorder
            ? Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                  width: 0.8,
                ),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 105, // Fixed width for clean label alignment
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      readOnly: !_isEditing,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _isEditing
            ? (isDark ? Colors.white : Colors.black87)
            : Theme.of(context).hintColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Theme.of(context).hintColor.withOpacity(0.5)),
        filled: _isEditing,
        fillColor: _isEditing
            ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05))
            : Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: EditProfileScreen.pastelBlue, width: 1.5),
        ),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _isEditing ? 12 : 0,
          vertical: _isEditing ? 8 : 4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
          ToneManager.t('profile_title'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.5,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: EditProfileScreen.pastelBlue),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            CupertinoButton(
              padding: const EdgeInsets.only(right: 16),
              onPressed: () => setState(() => _isEditing = true),
              child: Text(
                ToneManager.t('profile_edit_btn'),
                style: const TextStyle(
                  color: EditProfileScreen.pastelBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_isEditing)
            CupertinoButton(
              padding: const EdgeInsets.only(right: 16),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadUserProfile(); // Revert
              },
              child: Text(
                ToneManager.t('profile_cancel_btn'),
                style: const TextStyle(
                  color: Color(0xFFFF746C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: EditProfileScreen.pastelBlue))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // Profile Header section
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: EditProfileScreen.pastelBlue.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: EditProfileScreen.pastelBlue.withOpacity(0.4),
                                width: 2,
                              ),
                              image:
                                  FirebaseAuth.instance.currentUser?.photoURL !=
                                          null
                                      ? DecorationImage(
                                          image: NetworkImage(FirebaseAuth
                                              .instance.currentUser!.photoURL!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                            ),
                            child:
                                FirebaseAuth.instance.currentUser?.photoURL ==
                                        null
                                    ? const Icon(CupertinoIcons.person_fill,
                                        size: 44, color: EditProfileScreen.pastelBlue)
                                    : null,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text
                                : ToneManager.t('nav_profile'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Theme.of(context).textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FirebaseAuth.instance.currentUser?.email ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),

                    // Information Card
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCupertinoTile(
                            icon: CupertinoIcons.person_fill,
                            title: ToneManager.t('profile_label_name'),
                            iconColor: EditProfileScreen.pastelBlue,
                            child: _buildFormField(_nameController,
                                ToneManager.t('profile_hint_name')),
                          ),
                          _buildCupertinoTile(
                            icon: CupertinoIcons.person_2_fill,
                            title: ToneManager.t('profile_label_gender'),
                            iconColor: const Color(0xFFA78BFA),
                            child: _isEditing
                                ? DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _gender,
                                      isExpanded: false,
                                      alignment: Alignment.centerRight,
                                      icon: const Icon(
                                        CupertinoIcons.chevron_down,
                                        size: 14,
                                        color: EditProfileScreen.pastelBlue,
                                      ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                      ),
                                      dropdownColor: isDark
                                          ? const Color(0xFF2C2C2E)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Prefer not to say',
                                          child: Text('Tidak ditentukan'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Laki-laki',
                                          child: Text('Laki-laki'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Perempuan',
                                          child: Text('Perempuan'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _gender = val);
                                        }
                                      },
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8),
                                    child: Text(
                                      _gender == 'Prefer not to say' ? 'Tidak ditentukan' : _gender,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  ),
                          ),
                          _buildCupertinoTile(
                            icon: CupertinoIcons.calendar,
                            title: ToneManager.t('profile_label_dob'),
                            iconColor: const Color(0xFFFBBF24),
                            child: InkWell(
                              onTap: _pickDateOfBirth,
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _isEditing ? 12 : 0,
                                  vertical: _isEditing ? 8 : 8,
                                ),
                                child: Text(
                                  _dateOfBirth != null
                                      ? DateFormat('dd MMM yyyy')
                                          .format(_dateOfBirth!)
                                      : ToneManager.t('profile_hint_dob'),
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _dateOfBirth == null
                                        ? Theme.of(context).hintColor.withOpacity(0.5)
                                        : (_isEditing
                                            ? EditProfileScreen.pastelBlue
                                            : Theme.of(context).hintColor),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildCupertinoTile(
                            icon: CupertinoIcons.briefcase_fill,
                            title: ToneManager.t('profile_label_job'),
                            iconColor: const Color(0xFF34D399),
                            showBorder: false,
                            child: _buildFormField(_occupationController,
                                ToneManager.t('profile_hint_job')),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EditProfileScreen.pastelBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isLoading ? null : _saveProfile,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  ToneManager.t('profile_save_btn'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
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
