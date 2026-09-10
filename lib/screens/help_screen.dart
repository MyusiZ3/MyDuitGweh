import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const Color pastelBlue = Color(0xFF60A5FA);

  Future<void> _sendSupportEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support.myduitgweh@gmail.com',
      queryParameters: {
        'subject': 'Bantuan & Dukungan MyDuitGweh',
      },
    );

    try {
      final launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(emailUri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka aplikasi email: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Bantuan & Dukungan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: pastelBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER HERO CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pastelBlue.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: pastelBlue.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: pastelBlue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.question_circle_fill,
                      color: pastelBlue,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pusat Bantuan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Panduan lengkap penggunaan fitur aplikasi MyDuitGweh.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).hintColor,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SECTION TITLE
            Text(
              'Panduan Fitur',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 14),

            // INSTRUCTION CARDS
            _buildHelpCard(
              context,
              title: 'Cara Menambahkan Transaksi',
              desc: 'Ketuk ikon "+" pada bilah navigasi bawah. Pilih jenis transaksi (Pengeluaran, Pemasukan, atau Transfer), masukkan nominal dan deskripsi, lalu simpan.',
              icon: CupertinoIcons.plus_circle_fill,
              isDark: isDark,
            ),
            _buildHelpCard(
              context,
              title: 'Scan Struk Otomatis (AI)',
              desc: 'Gunakan tombol Scan untuk memfoto struk belanja Anda. Teknologi OCR AI kami akan otomatis mendeteksi total dan item belanjaan.',
              icon: CupertinoIcons.viewfinder,
              isDark: isDark,
            ),
            _buildHelpCard(
              context,
              title: 'Dompet Bersama & Kolaborasi',
              desc: 'Buat atau gabung dompet kolaborasi untuk mencatat transaksi secara transparan bersama pasangan, keluarga, atau rekan tim.',
              icon: CupertinoIcons.group_solid,
              isDark: isDark,
            ),
            _buildHelpCard(
              context,
              title: 'Kode Undangan 6-Digit',
              desc: 'Buka pengaturan dompet bersama Anda, salin kode unik 6-digit, lalu bagikan kepada anggota yang ingin Anda undang.',
              icon: CupertinoIcons.ticket_fill,
              isDark: isDark,
            ),
            _buildHelpCard(
              context,
              title: 'Kunci Sidik Jari / Wajah',
              desc: 'Aktifkan opsi Biometrik pada menu Profil untuk mengamankan akses aplikasi MyDuitGweh dari orang lain.',
              icon: CupertinoIcons.lock_shield_fill,
              isDark: isDark,
            ),

            const SizedBox(height: 28),

            // SUPPORT CONTACT CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(CupertinoIcons.mail_solid, color: pastelBlue, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Butuh Bantuan Lebih Lanjut?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tim dukungan kami siap membantu kendala teknis atau pertanyaan Anda terkait akun.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () => _sendSupportEmail(context),
                      icon: const Icon(CupertinoIcons.paperplane_fill, size: 18),
                      label: const Text(
                        'Kirim Email ke Support',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pastelBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpCard(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: pastelBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: pastelBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
