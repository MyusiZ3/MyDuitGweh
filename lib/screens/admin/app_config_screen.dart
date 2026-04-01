import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';

class AppConfigScreen extends StatefulWidget {
  const AppConfigScreen({super.key});

  @override
  State<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends State<AppConfigScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _maintenanceMode = false;
  final TextEditingController _minVersionController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _firestore.collection('app_config').doc('global').get();
      if (doc.exists) {
        setState(() {
          _maintenanceMode = doc.data()?['maintenanceMode'] ?? false;
          _minVersionController.text = doc.data()?['minVersion'] ?? '1.0.0';
        });
      }
    } catch (e) {
      debugPrint("Gagal load config: $e");
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    
    final batch = _firestore.batch();
    final configRef = _firestore.collection('app_config').doc('global');
    final historyRef = configRef.collection('history').doc();

    batch.set(configRef, {
      'maintenanceMode': _maintenanceMode,
      'minVersion': _minVersionController.text,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(historyRef, {
      'updatedAt': FieldValue.serverTimestamp(),
      'maintenanceMode': _maintenanceMode,
      'minVersion': _minVersionController.text,
      'type': 'CONFIG_UPDATE'
    });

    await batch.commit();

    setState(() => _isSaving = false);
    if (mounted) {
      _showSuccessSheet();
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text('Config Updated!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Semua perubahan berhasil disimpan dan tercatat di histori.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('SIP!'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('App Config'), centerTitle: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Parameters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1)),
            const SizedBox(height: 24),
            _buildConfigTile(),
            const SizedBox(height: 32),
            const Text('Change History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 16),
            _buildHistoryList(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSaving 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                : const Text('SAVE CONFIG', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigTile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surfaceVariant.withOpacity(0.5), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('User gak bisa masuk app jika aktif.', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ])),
              Switch.adaptive(value: _maintenanceMode, onChanged: (v) => setState(() => _maintenanceMode = v)),
            ],
          ),
          const Divider(height: 32),
          TextField(
            controller: _minVersionController,
            decoration: const InputDecoration(labelText: 'Min Version', hintText: '1.0.0', prefixIcon: Icon(Icons.verified_rounded)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('app_config').doc('global').collection('history').orderBy('updatedAt', descending: true).limit(10).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final DateTime date = (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return ListTile(
              leading: const Icon(Icons.history_rounded, size: 20),
              title: Text('v${data['minVersion']} | Maintenance: ${data['maintenanceMode']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(DateFormat('dd MMM HH:mm').format(date), style: const TextStyle(fontSize: 11)),
            );
          },
        );
      },
    );
  }
}
