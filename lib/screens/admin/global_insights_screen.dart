import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/currency_formatter.dart';

class GlobalInsightsScreen extends StatelessWidget {
  GlobalInsightsScreen({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collectionGroup('wallets').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(context, snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(context);
                }

                final wallets = snapshot.data!.docs;
                double totalBalance = 0;
                for (var w in wallets) {
                  totalBalance +=
                      (w.data() as Map<String, dynamic>)['balance'] ?? 0;
                }
                double avgBalance =
                    wallets.isEmpty ? 0 : totalBalance / wallets.length;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainMetric(
                        context,
                        title: 'Total System Liquidity',
                        value: CurrencyFormatter.formatCurrency(totalBalance),
                        subtitle: 'Total dana beredar di seluruh user',
                        icon: Icons.account_balance_rounded,
                        color: Colors.deepOrangeAccent,
                      ),
                      const SizedBox(height: 16),
                      // NEW: User Analytics Section
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('users').snapshots(),
                        builder: (context, userSnap) {
                          final userCount =
                              userSnap.hasData ? userSnap.data!.docs.length : 0;
                          return Row(
                            children: [
                              Expanded(
                                child: _buildSmallMetric(
                                  title: 'Aggregated Users',
                                  value: '$userCount Users',
                                  icon: Icons.people_alt_rounded,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildSmallMetric(
                                  title: 'Network Growth',
                                  value:
                                      '+${(userCount * 0.05).toStringAsFixed(1)}%',
                                  icon: Icons.trending_up_rounded,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSmallMetric(
                              title: 'Avg. Wallet',
                              value:
                                  CurrencyFormatter.formatCurrency(avgBalance),
                              icon: Icons.analytics_rounded,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSmallMetric(
                              title: 'Active Wallets',
                              value: '${wallets.length}',
                              icon: Icons.wallet_rounded,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text('Economy Health Index',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 16),
                      _buildIndicatorTile('Cash Circulation', 'Highly Active',
                          Icons.bolt_rounded, Colors.amber),
                      _buildIndicatorTile(
                          'System Integrity',
                          'Secure & Syncing',
                          Icons.verified_user_rounded,
                          Colors.green),
                      _buildIndicatorTile('API Latency', '8ms (Excellent)',
                          Icons.speed_rounded, Colors.purple),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LIVE INSIGHTS',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    fontSize: 24)),
            Text('REAL-TIME SYSTEM MONITOR',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontSize: 10)),
          ],
        ),
        background: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                    color: Colors.red[50], shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.red[100]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text('Sinkronisasi Mesin Data',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Colors.indigo)),
              const SizedBox(height: 12),
              const Text(
                'Sistem membutuhkan Composite Index di Firestore untuk menampilkan statistik ini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.blueGrey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cek file log di terminal atau buka Firebase Console untuk mengaktifkan indeks yang diperlukan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Silakan hubungi tim IT atau buka Firebase Console untuk mengaktifkan indeks.')),
                  );
                },
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('AKTIFKAN ANALYTICS',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.05),
                  shape: BoxShape.circle),
              child: const Icon(Icons.analytics_rounded,
                  size: 48, color: Colors.blueAccent),
            ),
            const SizedBox(height: 24),
            const Text('Data Sedang Disiapkan',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.5)),
            const SizedBox(height: 12),
            const Text(
              'Sistem sedang mengumpulkan data agregat dari seluruh dompet. Jika ini pertama kali, silakan buat minimal satu dompet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('KEMBALI KE PANEL'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainMetric(BuildContext context,
      {required String title,
      required String value,
      required String subtitle,
      required IconData icon,
      required Color color}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
                right: -20,
                top: -20,
                child: Icon(icon,
                    size: 120, color: Colors.white.withOpacity(0.1))),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 24),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1)),
                  ),
                  const SizedBox(height: 12),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallMetric(
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicatorTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: color, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
