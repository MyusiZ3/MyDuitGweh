import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Security Monitor', 
            style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.titleLarge?.color)),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildMaintenanceQuickPanel(),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(CupertinoIcons.timer, size: 20, color: Colors.grey),
                SizedBox(width: 8),
                Text('SECURITY LOGS', 
                    style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w900, 
                        color: Theme.of(context).textTheme.bodySmall?.color,
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
                        Icon(CupertinoIcons.shield_lefthalf_fill, size: 64, color: Colors.grey[300]),
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
            color: isMaintenance ? Colors.red[900] : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isMaintenance ? Colors.redAccent.withOpacity(0.3) : Theme.of(context).dividerColor.withOpacity(0.05),
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
                  CupertinoIcons.power,
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
                        color: isMaintenance ? Colors.white : Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    Text(
                      isMaintenance ? 'Mode Pemeliharaan AKTIF' : 'Semua Berjalan Normal',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMaintenance ? Colors.white70 : Theme.of(context).textTheme.bodySmall?.color,
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
        color: isRead ? Theme.of(context).cardColor : severityColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRead ? Theme.of(context).dividerColor.withOpacity(0.1) : severityColor.withOpacity(0.2),
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
                style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w600, 
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
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
      case 'AUTH_FAILURE': return CupertinoIcons.person_badge_minus;
      case 'EMERGENCY_ACTION': return CupertinoIcons.exclamationmark_triangle_fill;
      case 'DDOS_SUSPECT': return CupertinoIcons.antenna_radiowaves_left_right;
      default: return CupertinoIcons.shield_fill;
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
