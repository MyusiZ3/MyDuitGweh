import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primary = AppColors.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Bantuan & Dukungan'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const Text('Bagaimana kami bisa membantu?',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  )),
          const SizedBox(height: 24),
          _buildHelpCard(
            context,
            'Cara Menambahkan Transaksi',
            'Buka tab Home, klik tombol "+" di navigasi tengah, isi jumlah dan kategori, lalu simpan.',
            Icons.add_box_rounded,
          ),
          _buildHelpCard(
            context,
            'Apa itu Dompet Kolaborasi?',
            'Dompet yang dapat diakses oleh banyak anggota dengan saldo bersama yang transparan.',
            Icons.groups_rounded,
          ),
          _buildHelpCard(
            context,
            'Cara Menggunakan Kode Undangan',
            'Bagikan kode undangan 6 digit ke teman agar mereka dapat bergabung di dompet yang Anda miliki.',
            Icons.vpn_key_rounded,
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          const Text('Masih ada pertanyaan?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 12),
          Text(
              'Hubungi tim dukungan kami melalui email jika Anda mengalami kendala teknis.',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, height: 1.5)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.email_outlined),
              label: const Text('Kirim Email ke Support'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context, String title, String desc, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                Text(desc,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 14,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
