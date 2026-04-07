import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../utils/ui_helper.dart';
import '../../services/security_service.dart';
import 'package:intl/intl.dart';

class SecurityMonitorScreen extends StatefulWidget {
  const SecurityMonitorScreen({super.key});

  @override
  State<SecurityMonitorScreen> createState() => _SecurityMonitorScreenState();
}

class _SecurityMonitorScreenState extends State<SecurityMonitorScreen> {
  final SecurityService _securityService = SecurityService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text('Security Monitor', 
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMaintenanceQuickPanel(),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, size: 20, color: Colors.grey),
                SizedBox(width: 8),
                Text('SECURITY LOGS', 
                    style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.grey,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _securityService.getAllLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_moon_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Belum ada log keamanan.', 
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildLogTile(data, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceQuickPanel() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('global')
          .snapshots(),
      builder: (context, snapshot) {
        bool isMaintenance = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          isMaintenance = snapshot.data!.get('isMaintenance') ?? false;
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isMaintenance ? Colors.red[900] : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isMaintenance ? Colors.redAccent.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMaintenance ? Colors.white24 : Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: isMaintenance ? Colors.white : Colors.orange[800],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Shutdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isMaintenance ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      isMaintenance ? 'Mode Pemeliharaan AKTIF' : 'Semua Berjalan Normal',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMaintenance ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isMaintenance,
                activeColor: Colors.white,
                activeTrackColor: Colors.redAccent,
                onChanged: (val) => _showConfirmMaintenance(context, val),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogTile(Map<String, dynamic> data, String docId) {
    final String type = data['type'] ?? 'UNKNOWN';
    final String severity = data['severity'] ?? 'low';
    final String message = data['message'] ?? '';
    final Timestamp? ts = data['timestamp'] as Timestamp?;
    final bool isRead = data['isRead'] ?? false;

    Color severityColor = Colors.blue;
    if (severity == 'medium') severityColor = Colors.orange;
    if (severity == 'high') severityColor = Colors.red;
    if (severity == 'critical') severityColor = Colors.red[900]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : severityColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRead ? Colors.grey.withOpacity(0.1) : severityColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconForType(type),
            color: severityColor,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(type, 
                style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 12, 
                    color: severityColor)),
            const Spacer(),
            if (ts != null)
              Text(
                DateFormat('HH:mm').format(ts.toDate()),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(message, 
                style: const TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: Colors.black87)),
            if (data['userEmail'] != 'N/A')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Email: ${data['userEmail']}', 
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
          ],
        ),
        onTap: () {
           FirebaseFirestore.instance.collection('security_logs').doc(docId).update({'isRead': true});
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'AUTH_FAILURE': return Icons.no_accounts_rounded;
      case 'EMERGENCY_ACTION': return Icons.emergency_rounded;
      case 'DDOS_SUSPECT': return Icons.radar_rounded;
      default: return Icons.security_rounded;
    }
  }

  void _showConfirmMaintenance(BuildContext context, bool enable) {
    UIHelper.showConfirmDialog(
      context: context,
      title: enable ? 'Aktifkan Mode Maintenance?' : 'Matikan Mode Maintenance?',
      message: enable 
          ? 'Ini akan memblokir akses seluruh pengguna ke aplikasi.' 
          : 'Akses aplikasi akan dibuka kembali untuk publik.',
      confirmText: enable ? 'AKTIFKAN' : 'MATIKAN',
      cancelText: 'BATAL',
      isDangerous: enable,
    ).then((confirmed) {
      if (confirmed == true) {
        _securityService.toggleGlobalMaintenance(enable);
      } else {
        // Reset switch status if cancelled
        setState(() {});
      }
    });
  }
}
