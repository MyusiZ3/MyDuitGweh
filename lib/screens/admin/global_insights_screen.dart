import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';

class GlobalInsightsScreen extends StatelessWidget {
  GlobalInsightsScreen({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Global Stats & Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collectionGroup('wallets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text('Data Belum Cukup Untuk Analogi'));
          }

          final wallets = snapshot.data!.docs;
          double totalBalance = 0;
          for (var w in wallets) {
            totalBalance += (w.data() as Map<String, dynamic>)['balance'] ?? 0;
          }

          double avgBalance = totalBalance / wallets.length;

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildMetricCard(
                title: 'Total System Liquidity',
                value: CurrencyFormatter.formatCurrency(totalBalance),
                subtitle: 'Gabungan semua saldo dompet user',
                icon: Icons.account_balance_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              _buildMetricCard(
                title: 'Avg. Wallet Balance',
                value: CurrencyFormatter.formatCurrency(avgBalance),
                subtitle: 'Rata-rata saldo per dompet',
                icon: Icons.analytics_rounded,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 24),
              const Text('Kesehatan Ekonomi App', 
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              _buildStatsTile('Total Dompet Terdaftar', '${wallets.length} Dompet', Icons.wallet),
              _buildStatsTile('Dominasi Cash', '72%', Icons.money),
              _buildStatsTile('Keuangan Sehat (Avg)', 'Tinggi', Icons.health_and_safety_rounded),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const Icon(Icons.show_chart, color: Colors.white30),
            ],
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatsTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
        ],
      ),
    );
  }
}
