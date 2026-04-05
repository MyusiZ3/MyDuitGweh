import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../utils/app_theme.dart';
import '../../utils/ui_helper.dart';
import '../../services/auth_service.dart';

class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _authService = AuthService();
  bool _isSuperAdmin = false;
  bool _maintenanceMode = false;
  bool _advisorEnabled = true;
  String _advisorProvider = 'gemini';
  List<String> _geminiKeys = [];
  List<String> _groqKeys = [];
  final TextEditingController _minVersionController = TextEditingController();
  final TextEditingController _latestVersionController =
      TextEditingController();
  final TextEditingController _downloadUrlController = TextEditingController();
  final TextEditingController _maintenanceMsgController =
      TextEditingController();
  final TextEditingController _advisorMinTransController =
      TextEditingController();
  final TextEditingController _advisorCooldownController =
      TextEditingController();
  // Survey Config
  bool _surveyEnabled = false;
  final TextEditingController _surveyMinTransactionsController =
      TextEditingController();
  final TextEditingController _surveyMinAccountAgeController =
      TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  bool _isSaving = false;
  bool _isForceUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _checkSuperAdmin();
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    _latestVersionController.dispose();
    _downloadUrlController.dispose();
    _maintenanceMsgController.dispose();
    _advisorMinTransController.dispose();
    _advisorCooldownController.dispose();
    _surveyMinTransactionsController.dispose();
    _surveyMinAccountAgeController.dispose();
    super.dispose();
  }

  Future<void> _checkSuperAdmin() async {
    final isSuper = await _authService.isSuperAdmin();
    if (mounted) {
      setState(() {
        _isSuperAdmin = isSuper;
      });
    }
  }

  Future<void> _loadConfig() async {
    try {
      final configDoc =
          await _firestore.collection('app_config').doc('global').get();
      
      // Ambil versi dari pubspec.yaml buat default kalau di firestore masih null
      final packageInfo = await PackageInfo.fromPlatform();
      final currentAppVersion = packageInfo.version;

      if (configDoc.exists) {
        final data = configDoc.data()!;
        setState(() {
          _maintenanceMode = data['isMaintenance'] ?? false;
          _minVersionController.text = data['minVersion'] ?? currentAppVersion;
          _latestVersionController.text = data['latestVersion'] ?? currentAppVersion;
          _downloadUrlController.text = data['downloadUrl'] ?? '';
          _isForceUpdate = data['isForceUpdate'] ?? false;

          // AI Advisor Config
          _advisorEnabled = data['is_advisor_enabled'] ?? true;
          _advisorProvider = data['advisor_provider'] ?? 'gemini';
          _geminiKeys = List<String>.from(data['advisor_gemini_keys'] ?? []);
          _groqKeys = List<String>.from(data['advisor_groq_keys'] ?? []);

          // Migrasi old API ke format baru kalau ada
          final oldKey = data['advisor_api_key'] ?? '';
          if (oldKey.toString().isNotEmpty) {
            if (oldKey.toString().startsWith('gsk_') &&
                !_groqKeys.contains(oldKey)) _groqKeys.add(oldKey);
            if (oldKey.toString().startsWith('AIza') &&
                !_geminiKeys.contains(oldKey)) _geminiKeys.add(oldKey);
          }

          _advisorMinTransController.text =
              (data['advisor_min_transactions'] ?? 5).toString();
          _advisorCooldownController.text =
              (data['advisor_cooldown_hours'] ?? 24).toString();
          _maintenanceMsgController.text = data['maintenanceMessage'] ??
              'Aplikasi sedang dalam pemeliharaan rutin.';
          _startTime = (data['maintenanceStartTime'] as Timestamp?)?.toDate();
          _endTime = (data['maintenanceEndTime'] as Timestamp?)?.toDate();
        });
      }

      // Load Survey Config separately
      final surveyDoc =
          await _firestore.collection('app_config').doc('survey').get();
      if (surveyDoc.exists) {
        final sData = surveyDoc.data()!;
        setState(() {
          _surveyEnabled = sData['isAvailable'] ?? false;
          _surveyMinTransactionsController.text =
              (sData['minTransactions'] ?? 0).toString();
          _surveyMinAccountAgeController.text =
              (sData['minAccountAgeDays'] ?? 0).toString();
        });
      }
    } catch (e) {
      debugPrint("Gagal load config: $e");
    }
  }

  Future<void> _selectDateTime(bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          final dt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startTime = dt;
          } else {
            _endTime = dt;
          }
        });
      }
    }
  }

  Future<void> _saveConfig() async {
    final confirmed = await UIHelper.showConfirmDialog(
      context: context,
      title: 'Simpan Konfigurasi?',
      message:
          'Semua perubahan (Sistem, AI, & Survei) akan langsung diterapkan ke aplikasi dan tercatat di log.',
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);

    try {
      final batch = _firestore.batch();
      final configRef = _firestore.collection('app_config').doc('global');
      final surveyRef = _firestore.collection('app_config').doc('survey');
      final historyRef = configRef.collection('history').doc();

      // Check for log-worthy changes
      final prevDoc = await configRef.get();
      final prevData = prevDoc.data() ?? {};
      final prevSurveyDoc = await surveyRef.get();
      final prevSurveyData = prevSurveyDoc.data() ?? {};

      // 1. App Global Config
      final Map<String, dynamic> configData = {
        'isMaintenance': _maintenanceMode,
        'minVersion': _minVersionController.text,
        'latestVersion': _latestVersionController.text,
        'downloadUrl': _downloadUrlController.text,
        'isForceUpdate': _isForceUpdate,
        'maintenanceMessage': _maintenanceMsgController.text,
        'maintenanceStartTime':
            _startTime != null ? Timestamp.fromDate(_startTime!) : null,
        'maintenanceEndTime':
            _endTime != null ? Timestamp.fromDate(_endTime!) : null,
        'is_advisor_enabled': _advisorEnabled,
        'advisor_provider': _advisorProvider,
        'advisor_gemini_keys': _geminiKeys,
        'advisor_groq_keys': _groqKeys,
        'advisor_api_key': '',
        'advisor_min_transactions':
            int.tryParse(_advisorMinTransController.text) ?? 5,
        'advisor_cooldown_hours':
            int.tryParse(_advisorCooldownController.text) ?? 24,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      batch.set(configRef, configData, SetOptions(merge: true));

      // 2. Survey Config
      final Map<String, dynamic> surveyData = {
        'isAvailable': _surveyEnabled,
        'minTransactions':
            int.tryParse(_surveyMinTransactionsController.text) ?? 0,
        'minAccountAgeDays':
            int.tryParse(_surveyMinAccountAgeController.text) ?? 0,
      };
      batch.set(surveyRef, surveyData, SetOptions(merge: true));

      // 3. Create Specific History Logs
      final uid = _authService.auth.currentUser?.uid ?? 'system';

      // Log Survey Toggle specifically
      if (prevSurveyData['isAvailable'] != _surveyEnabled) {
        final surveyLogRef = configRef.collection('history').doc();
        batch.set(surveyLogRef, {
          'action': 'SURVEY_TOGGLED',
          'enabled': _surveyEnabled,
          'updatedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Log AI Status if changed
      if (prevData['is_advisor_enabled'] != _advisorEnabled) {
        final aiLogRef = configRef.collection('history').doc();
        batch.set(aiLogRef, {
          'action': 'AI_STATUS_CHANGED',
          'enabled': _advisorEnabled,
          'updatedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // General config update log
      batch.set(historyRef, {
        ...configData,
        'updatedAt': FieldValue.serverTimestamp(),
        'action': 'CONFIG_UPDATE',
        'updatedBy': uid,
      });

      await batch.commit();

      if (mounted) _showSuccessSheet();
    } catch (e) {
      if (mounted) {
        UIHelper.showErrorSnackBar(context, 'Gagal menyimpan: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearHistory({DocumentReference? singleDoc}) async {
    final isSingle = singleDoc != null;
    final confirmed = await UIHelper.showConfirmDialog(
      context: context,
      title: isSingle ? 'Hapus Histori Ini?' : 'Clear Semua History?',
      message: isSingle
          ? 'Data konfigurasi ini akan dihapus permanen.'
          : 'Hapus seluruh histori konfigurasi aplikasi? Tindakan ini tidak bisa dibatalkan.',
    );

    if (confirmed == true) {
      try {
        if (isSingle) {
          await singleDoc.delete();
          if (mounted) {
            UIHelper.showSuccessSnackBar(context, 'Item histori dihapus.');
          }
        } else {
          final snapshot = await _firestore
              .collection('app_config')
              .doc('global')
              .collection('history')
              .get();
          final batch = _firestore.batch();
          for (var doc in snapshot.docs) {
            final docData = doc.data();
            final action = docData['action'] ?? docData['type'] ?? '';
            if (action == 'CONFIG_UPDATE') {
              batch.delete(doc.reference);
            }
          }
          await batch.commit();
          if (mounted) {
            UIHelper.showSuccessSnackBar(context, 'Semua histori dihapus.');
          }
        }
      } catch (e) {
        if (mounted) {
          UIHelper.showErrorSnackBar(context, 'Gagal menghapus histori: $e');
        }
      }
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text('Config Updated!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                  'Semua perubahan berhasil disimpan dan tercatat di histori.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('SIP!'))),
            ],
          ),
        ),
      ),
    );
  }

  void _showTutorialDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 600),
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.rocket_launch_rounded,
                          color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Guide Update (A-Z)',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold))),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20)),
                  ],
                ),
                const Divider(height: 32),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _tutorialStep(1, "Login Firebase CLI",
                          "Buka Terminal (Ctrl + J) lalu ketik 'firebase login'. Pastikan akun Google-mu terhubung."),
                      _tutorialStep(2, "Build APK Rilis",
                          "Ketik 'flutter build apk --release'. Tunggu sampai selesai (hasilnya ada di folder build/app/...)"),
                      _tutorialStep(3, "Pindahkan APK",
                          "Cari file 'app-release.apk' tadi, copy & paste ke dalam folder 'public/' di folder project utama kamu."),
                      _tutorialStep(4, "Kirim ke Cloud",
                          "Di terminal, ketik 'firebase deploy --only hosting'. Tunggu sampai muncul URL sukses."),
                      _tutorialStep(5, "Update Firestore",
                          "Masuk ke Admin Panel, ganti 'Latest Version' ke versi baru (cek pubspec.yaml) dan klik tombol 'Gunakan Firebase Hosting URL'."),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Tentang vMin (Force Update):",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.brown)),
                                  Text(
                                      "Jika kamu isi vMin lebih tinggi dari versi yang dipakai user, user TIDAK BISA pakai aplikasi sebelum dia update (WAJIB UPDATE). Gunakan ini hanya untuk update kritikal!",
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.brown)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('PAHAM, LANJUTKAN!',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tutorialStep(int num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration:
                const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(num.toString(),
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.6),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Global Settings'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _showTutorialDialog,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Tutorial Update',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('System & Utility',
                Icons.settings_suggest_rounded, Colors.black),
            _buildPremiumCard(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _maintenanceMode
                          ? Colors.black
                          : Colors.blue.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _maintenanceMode
                            ? Colors.black
                            : Colors.blue.withOpacity(0.1),
                      ),
                      boxShadow: _maintenanceMode
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _maintenanceMode
                                ? Colors.white.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _maintenanceMode
                                ? Icons.construction_rounded
                                : Icons.check_circle_rounded,
                            color: _maintenanceMode
                                ? Colors.white
                                : Colors.blue.shade700,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _maintenanceMode
                                    ? 'Maintenance ON'
                                    : 'System Normal',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: _maintenanceMode
                                        ? Colors.white
                                        : Colors.black87,
                                    letterSpacing: -0.5),
                              ),
                              Text(
                                  _maintenanceMode
                                      ? 'Sistem sedang dibatasi.'
                                      : 'Sistem berjalan optimal.',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _maintenanceMode
                                          ? Colors.white70
                                          : Colors.blueGrey)),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _maintenanceMode,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.white24,
                          onChanged: (v) =>
                              setState(() => _maintenanceMode = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildModernTextField(
                    controller: _maintenanceMsgController,
                    label: 'Pesan Maintenance',
                    icon: Icons.message_rounded,
                    color: Colors.black,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePicker(
                          label: 'Mulai',
                          value: _startTime,
                          onTap: () => _selectDateTime(true),
                          onClear: () => setState(() => _startTime = null),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimePicker(
                          label: 'Selesai',
                          value: _endTime,
                          onTap: () => _selectDateTime(false),
                          onClear: () => setState(() => _endTime = null),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Versioning & Update',
                Icons.system_update_rounded, Colors.black),
            _buildPremiumCard(
              child: Column(
                children: [
                  _buildModernTextField(
                    controller: _minVersionController,
                    label: 'Force Update vMin',
                    icon: Icons.verified_rounded,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _latestVersionController,
                    label: 'Latest Version',
                    icon: Icons.new_releases_rounded,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 16),
                  _buildModernTextField(
                    controller: _downloadUrlController,
                    label: 'Download URL (Direct)',
                    icon: Icons.link_rounded,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _downloadUrlController.text =
                              'https://myduitgweh.web.app/app.bin';
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cloud_done_rounded,
                          size: 14, color: Colors.black54),
                      label: const Text('Use Firebase Hosting URL',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isForceUpdate
                          ? Colors.red.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isForceUpdate
                            ? Colors.red.withOpacity(0.2)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isForceUpdate
                              ? Icons.error_outline_rounded
                              : Icons.info_outline_rounded,
                          color: _isForceUpdate ? Colors.red : Colors.black54,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paksa Update (Force)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _isForceUpdate
                                      ? Colors.red
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                _isForceUpdate
                                    ? 'User tidak bisa mengabaikan update ini'
                                    : 'User masih bisa memilih "Nanti Saja"',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isForceUpdate,
                          onChanged: (v) => setState(() => _isForceUpdate = v),
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(
                'AI Financial Advisor', Icons.psychology_rounded, Colors.black),
            _buildPremiumCard(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _advisorEnabled
                          ? Colors.black
                          : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: _advisorEnabled
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _advisorEnabled
                                ? Colors.white.withOpacity(0.2)
                                : Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _advisorEnabled
                                ? Icons.psychology_rounded
                                : Icons.power_off_rounded,
                            color: _advisorEnabled ? Colors.white : Colors.red,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _advisorEnabled
                                    ? 'Engine Active'
                                    : 'Engine Suspended',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: _advisorEnabled
                                        ? Colors.white
                                        : Colors.black87,
                                    letterSpacing: -0.5),
                              ),
                              Text('Global toggle untuk AI Advisor',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _advisorEnabled
                                          ? Colors.white70
                                          : Colors.grey)),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _advisorEnabled,
                          activeColor: Colors.white,
                          activeTrackColor: Colors.white24,
                          onChanged: (v) => setState(() => _advisorEnabled = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _advisorProvider,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.02),
                      labelText: 'Engine Provider',
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withOpacity(0.6)),
                      prefixIcon: const Icon(Icons.hub_rounded,
                          color: Colors.black, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey),
                    items: const [
                      DropdownMenuItem(
                          value: 'gemini',
                          child: Text('Google Gemini',
                              style: TextStyle(fontWeight: FontWeight.w600))),
                      DropdownMenuItem(
                          value: 'groq',
                          child: Text('Groq API',
                              style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                    onChanged: (v) => setState(() => _advisorProvider = v!),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.vpn_key_rounded,
                          size: 18, color: Colors.black87),
                      label: const Text('MANAGE API KEYS',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      onPressed: _showAdvisorKeysManager,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.05),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                                color: Colors.black.withOpacity(0.1))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildModernTextField(
                          controller: _advisorMinTransController,
                          label: 'Trigger (Trans)',
                          helper: 'Min. tx baru',
                          icon: Icons.swap_horiz_rounded,
                          color: Colors.black,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModernTextField(
                          controller: _advisorCooldownController,
                          label: 'Cooldown (Jam)',
                          helper: 'Jeda analisa',
                          icon: Icons.hourglass_empty_rounded,
                          color: Colors.black,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('User Survey (Satisfaction)',
                Icons.thumbs_up_down_rounded, Colors.black),
            _buildPremiumCard(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surveyEnabled
                          ? Colors.black
                          : Colors.blueGrey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _surveyEnabled
                            ? Colors.black
                            : Colors.blueGrey.withOpacity(0.1),
                      ),
                      boxShadow: _surveyEnabled
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _surveyEnabled
                                ? Colors.white.withOpacity(0.2)
                                : Colors.blueGrey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.thumbs_up_down_rounded,
                            color:
                                _surveyEnabled ? Colors.white : Colors.blueGrey,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _surveyEnabled
                                    ? 'Survey Opened'
                                    : 'Survey Closed',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: _surveyEnabled
                                        ? Colors.white
                                        : Colors.black87,
                                    letterSpacing: -0.5),
                              ),
                              Text('Aktifkan survei kepuasan user',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: _surveyEnabled
                                          ? Colors.white70
                                          : Colors.blueGrey)),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _surveyEnabled,
                          activeColor: Colors.white,
                          activeTrackColor:
                              const Color.fromARGB(60, 255, 255, 255),
                          onChanged: (v) => setState(() => _surveyEnabled = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildConfigSlider(
                    label: 'Min. Transaksi',
                    value: double.tryParse(
                            _surveyMinTransactionsController.text) ??
                        0,
                    min: 0,
                    max: 50,
                    divisions: 10,
                    color: Colors.black,
                    onChanged: (val) => setState(() =>
                        _surveyMinTransactionsController.text =
                            val.toInt().toString()),
                  ),
                  const SizedBox(height: 16),
                  _buildConfigSlider(
                    label: 'Umur Akun (Hari)',
                    value:
                        double.tryParse(_surveyMinAccountAgeController.text) ??
                            0,
                    min: 0,
                    max: 30,
                    divisions: 30,
                    color: Colors.black,
                    onChanged: (val) => setState(() =>
                        _surveyMinAccountAgeController.text =
                            val.toInt().toString()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text(_isSaving ? 'Saving...' : 'Publish Configurations'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Change History',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 16),
            _buildHistoryList(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value.toInt().toString(),
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 12, color: color),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 8, elevation: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: color.withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    String? helper,
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.6)),
        helperText: helper,
        helperStyle: const TextStyle(fontSize: 10),
        prefixIcon: Icon(icon, color: color, size: 20),
        filled: true,
        fillColor: Colors.black.withOpacity(0.02),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color.withOpacity(0.5), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildPremiumCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8)),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: child,
    );
  }

  Widget _buildTimePicker({
    required String label,
    DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 14,
                          color:
                              value != null ? AppColors.primary : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        value != null
                            ? DateFormat('dd MMM, HH:mm').format(value)
                            : '--:--',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: value != null ? Colors.black : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Colors.redAccent),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('app_config')
          .doc('global')
          .collection('history')
          .orderBy('updatedAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        // Only show CONFIG_UPDATE entries in this screen's history
        final configDocs = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final action = d['action'] ?? d['type'] ?? '';
          return action == 'CONFIG_UPDATE';
        }).toList();

        if (configDocs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('Belum ada perubahan config.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: configDocs.length,
          itemBuilder: (context, index) {
            final doc = configDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final DateTime date =
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final start =
                (data['maintenanceStartTime'] as Timestamp?)?.toDate();
            final end = (data['maintenanceEndTime'] as Timestamp?)?.toDate();
            final maintenanceEnabled = data['isMaintenance'] ?? false;

            String status = 'INACTIVE';
            Color statusColor = Colors.grey;

            if (maintenanceEnabled) {
              final now = DateTime.now();
              if (start != null && end != null) {
                if (now.isBefore(start)) {
                  status = 'PENDING';
                  statusColor = Colors.orange;
                } else if (now.isAfter(end)) {
                  status = 'END';
                  statusColor = Colors.red;
                } else {
                  status = 'ONGOING';
                  statusColor = Colors.green;
                }
              } else if (start != null) {
                if (now.isBefore(start)) {
                  status = 'PENDING';
                  statusColor = Colors.orange;
                } else {
                  status = 'ONGOING';
                  statusColor = Colors.green;
                }
              } else {
                status = 'ONGOING';
                statusColor = Colors.green;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.settings_backup_restore_rounded,
                      size: 20, color: statusColor),
                ),
                title: Row(
                  children: [
                    Text('v${data['minVersion']}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(status,
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(data['maintenanceMessage'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(DateFormat('dd MMM HH:mm').format(date),
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
                trailing: _isSuperAdmin
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: Colors.redAccent),
                        onPressed: () =>
                            _clearHistory(singleDoc: doc.reference),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  void _showAdvisorKeysManager() {
    final TextEditingController newKeyController = TextEditingController();
    bool isAdding = false;
    String addType = 'gemini'; // 'gemini' or 'groq'

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Kelola API Keys Advisor',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ),
                  Expanded(
                      child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                        if (isAdding) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.black.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: addType,
                                        decoration: InputDecoration(
                                          labelText: 'Tipe Key',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'gemini',
                                              child: Text('Gemini')),
                                          DropdownMenuItem(
                                              value: 'groq',
                                              child: Text('Groq')),
                                        ],
                                        onChanged: (v) =>
                                            setModalState(() => addType = v!),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: newKeyController,
                                        decoration: InputDecoration(
                                          labelText: 'API Key',
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setModalState(() {
                                          isAdding = false;
                                          newKeyController.clear();
                                        });
                                      },
                                      child: const Text('Batal',
                                          style: TextStyle(color: Colors.grey)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () {
                                        final k = newKeyController.text.trim();
                                        if (k.isNotEmpty) {
                                          setState(() {
                                            if (addType == 'gemini' &&
                                                !_geminiKeys.contains(k)) {
                                              _geminiKeys.add(k);
                                            } else if (addType == 'groq' &&
                                                !_groqKeys.contains(k)) {
                                              _groqKeys.add(k);
                                            }
                                          });
                                          setModalState(() {
                                            isAdding = false;
                                            newKeyController.clear();
                                          });
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Simpan Key'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 32),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text('TAMBAH API KEY BARU',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5)),
                              onPressed: () =>
                                  setModalState(() => isAdding = true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Colors.black87),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text('Gemini API Keys',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (_geminiKeys.isEmpty)
                          const Text('Belum ada data.',
                              style: TextStyle(color: Colors.grey)),
                        ..._geminiKeys
                            .map((key) => _buildKeyItem(key, 'gemini', () {
                                  setState(() => _geminiKeys.remove(key));
                                  setModalState(() {});
                                })),
                        const SizedBox(height: 24),
                        const Text('Groq API Keys',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        if (_groqKeys.isEmpty)
                          const Text('Belum ada data.',
                              style: TextStyle(color: Colors.grey)),
                        ..._groqKeys
                            .map((key) => _buildKeyItem(key, 'groq', () {
                                  setState(() => _groqKeys.remove(key));
                                  setModalState(() {});
                                })),
                        const SizedBox(height: 100),
                      ]))
                ],
              ),
            );
          });
        });
  }

  Widget _buildKeyItem(String apiKey, String type, VoidCallback onDelete) {
    bool isTesting = false;
    String testResult = '';
    Color testColor = Colors.grey;

    return StatefulBuilder(builder: (context, setItemState) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(
                      apiKey,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )),
                    IconButton(
                      icon:
                          const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isTesting)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (testResult.isNotEmpty)
                      Expanded(
                        child: Text(
                          testResult,
                          style: TextStyle(
                              color: testColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      const Flexible(
                          child: Text('Belum dites',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12))),
                    SizedBox(
                      height: 30,
                      child: TextButton(
                        onPressed: isTesting
                            ? null
                            : () async {
                                setItemState(() {
                                  isTesting = true;
                                  testResult = 'Menghubungkan...';
                                  testColor = Colors.grey;
                                });

                                bool success = false;
                                String msg = '';
                                if (type == 'gemini') {
                                  final res = await _testGemini(apiKey);
                                  success = res.success;
                                  msg = res.message;
                                } else {
                                  final res = await _testGroq(apiKey);
                                  success = res.success;
                                  msg = res.message;
                                }

                                setItemState(() {
                                  isTesting = false;
                                  testResult =
                                      success ? 'Normal / Active' : msg;
                                  testColor =
                                      success ? Colors.green : Colors.red;
                                });
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('Cek Koneksi',
                            style: TextStyle(fontSize: 12)),
                      ),
                    )
                  ],
                )
              ],
            )),
      );
    });
  }

  Future<({bool success, String message})> _testGemini(String key) async {
    final fallbackModels = [
      'gemini-3.1-pro-preview',
      'gemini-2.5-flash',
      'gemini-2.0-flash'
    ];

    for (String m in fallbackModels) {
      try {
        final model = GenerativeModel(model: m, apiKey: key);
        await model.generateContent([Content.text('test')]);
        return (success: true, message: 'Valid ($m)');
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        bool isNotFound =
            errStr.contains('not found') || errStr.contains('404');
        if (isNotFound) continue; // Try next fallback model

        if (errStr.contains('api key not valid'))
          return (success: false, message: 'Invalid Key');
        if (errStr.contains('quota'))
          return (success: false, message: 'Quota Exceeded');
        if (errStr.contains('exhausted'))
          return (success: false, message: 'API Limit Exhausted');
        return (
          success: false,
          message: 'Error: ${e.toString().split('\n').first}'
        );
      }
    }
    return (success: false, message: 'Models Not Found / API Limit');
  }

  Future<({bool success, String message})> _testGroq(String key) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "user", "content": "hi"}
          ],
          "max_tokens": 10
        }), // very small max_tokens
      );

      if (res.statusCode == 200) {
        return (success: true, message: 'Valid');
      } else {
        final err = jsonDecode(res.body);
        if (err['error']?['code'] == 'invalid_api_key')
          return (success: false, message: 'Invalid Key');
        if (res.statusCode == 429)
          return (success: false, message: 'Rate Limit / Quota Exceeded');
        return (success: false, message: 'Error \${res.statusCode}');
      }
    } catch (e) {
      return (success: false, message: 'Failed to connect');
    }
  }
}
