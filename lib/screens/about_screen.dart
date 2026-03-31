import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              'MyDuitGweh',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary),
            ),
            const Text(
              'Versi 1.0.0',
              style: TextStyle(color: AppColors.textHint),
            ),
            const SizedBox(height: 48),
            const Text(
              'Solusi pencatatan keuangan modern yang membantu Anda mengelola pemasukan, pengeluaran, dan dompet kolaborasi bersama teman atau keluarga dengan lebih mudah dan transparan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.6, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 48),
            const Divider(),
            const ListTile(
              title: Text('Dibuat dengan ❤️ oleh Antigravity'),
              subtitle: Text('Tim Advanced Agentic Coding @ Google Deepmind'),
            ),
          ],
        ),
      ),
    );
  }
}
