import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTone { normal, genZ, milenial, boomer }

class ToneManager {
  static final ValueNotifier<AppTone> notifier = ValueNotifier(AppTone.normal);

  static Future<void> loadTone() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('app_tone_index') ?? 0;
    if (index >= 0 && index < AppTone.values.length) {
      notifier.value = AppTone.values[index];
    }
  }

  static Future<void> setTone(AppTone tone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_tone_index', tone.index);
    notifier.value = tone;
  }

  static const Map<String, Map<AppTone, String>> _dict = {
    // ---------------------------------------------------------
    // HOME SCREEN
    // ---------------------------------------------------------
    'home_balance': {
      AppTone.normal: 'Total Saldo',
      AppTone.genZ: 'Duit Gweh Sekarang 🤑',
      AppTone.milenial: 'Total Cashflow 💳',
      AppTone.boomer: 'Harta Titipan Illahi 🙏',
    },
    'home_income': {
      AppTone.normal: 'Pemasukan',
      AppTone.genZ: 'Cuan Masuk 💸',
      AppTone.milenial: 'Earning',
      AppTone.boomer: 'Alhamdulillah Rezeki',
    },
    'home_expense': {
      AppTone.normal: 'Pengeluaran',
      AppTone.genZ: 'Apes Boncos 📉',
      AppTone.milenial: 'Spending',
      AppTone.boomer: 'Astaghfirullah Keluar',
    },
    'home_recent': {
      AppTone.normal: 'Transaksi Tersimpan',
      AppTone.genZ: 'Riwayat Jajan Terakhir',
      AppTone.milenial: 'Recent Transactions',
      AppTone.boomer: 'Buku Kas Terakhir',
    },
    'home_empty': {
      AppTone.normal: 'Belum ada transaksi, yuk mulai catat!',
      AppTone.genZ: 'Sepi amat dompet lu, belum jajan ya?',
      AppTone.milenial: 'No transactions yet. Start tracking!',
      AppTone.boomer: 'Alhamdulillah, hari ini belum ada pengeluaran.',
    },
    
    // ---------------------------------------------------------
    // BOTTOM NAVIGATION
    // ---------------------------------------------------------
    'nav_home': {
      AppTone.normal: 'Beranda',
      AppTone.genZ: 'Home Gweh',
      AppTone.milenial: 'Dashboard',
      AppTone.boomer: 'Halaman Utama',
    },
    'nav_wallet': {
      AppTone.normal: 'Dompet',
      AppTone.genZ: 'Brankas',
      AppTone.milenial: 'Wallets',
      AppTone.boomer: 'Saku Celana',
    },
    'nav_report': {
      AppTone.normal: 'Laporan',
      AppTone.genZ: 'Rapor Boncos',
      AppTone.milenial: 'Analytics',
      AppTone.boomer: 'Buku Tabungan',
    },
    'nav_profile': {
      AppTone.normal: 'Profil',
      AppTone.genZ: 'Markas',
      AppTone.milenial: 'My Profile',
      AppTone.boomer: 'KTP Saya',
    },

    // ---------------------------------------------------------
    // PROFILE SCREEN
    // ---------------------------------------------------------
    'profile_title': {
      AppTone.normal: 'Profil Pemilik',
      AppTone.genZ: 'Markas Gweh 😎',
      AppTone.milenial: 'My Account',
      AppTone.boomer: 'Data Diri Anda',
    },
    'profile_tone': {
      AppTone.normal: 'Gaya Bahasa Aplikasi',
      AppTone.genZ: 'Vibe Bahasa Aplikasi ✌️',
      AppTone.milenial: 'Language Preferences',
      AppTone.boomer: 'Pilihan Tata Bahasa',
    },
    'profile_logout': {
      AppTone.normal: 'Keluar Akun',
      AppTone.genZ: 'Cabut Dulu Ah 🚪',
      AppTone.milenial: 'Sign Out',
      AppTone.boomer: 'Tutup Warung',
    },
    // ===== ALERTS & DIALOGS =====
    'dialog_yes': {
      AppTone.normal: 'Ya',
      AppTone.genZ: 'Gass',
      AppTone.milenial: 'Boleh',
      AppTone.boomer: 'Njeh',
    },
    'dialog_no': {
      AppTone.normal: 'Batal',
      AppTone.genZ: 'Skip Dulu',
      AppTone.milenial: 'Batal',
      AppTone.boomer: 'Ndak Usah',
    },
    'dialog_logout_title': {
      AppTone.normal: 'Keluar Akun?',
      AppTone.genZ: 'Beneran Mau Cabut?',
      AppTone.milenial: 'Sign Out?',
      AppTone.boomer: 'Ingin Keluar Akun?',
    },
    'dialog_logout_msg': {
      AppTone.normal: 'Pastikan kamu sudah mencatat semua transaksi hari ini ya.',
      AppTone.genZ: 'Udah kelar nge-track hari ini? Kalau belum ntar lupa lho.',
      AppTone.milenial: 'Make sure you have logged all today\'s activities.',
      AppTone.boomer: 'Pastikan semuanya sudah dicatat dengan benar hari ini.',
    },
    'dialog_del_wallet_title': {
      AppTone.normal: 'Hapus Dompet',
      AppTone.genZ: 'Mau Hapus',
      AppTone.milenial: 'Delete Wallet',
      AppTone.boomer: 'Hapus Dompet',
    },
    'dialog_del_wallet_msg': {
      AppTone.normal: 'Semua data transaksi di dompet ini akan ikut terhapus permanen.',
      AppTone.genZ: 'Yakin dompet ini dihempas? Duit dan datanya ilang permanen loh.',
      AppTone.milenial: 'Semua history transaksi akan didiscard secara permanen. Lanjut?',
      AppTone.boomer: 'Apakah anda yakin? Semua catatan akan terhapus selamanya.',
    },
    'dialog_leave_wallet_title': {
      AppTone.normal: 'Keluar Dompet',
      AppTone.genZ: 'Cabut Circle',
      AppTone.milenial: 'Leave Wallet',
      AppTone.boomer: 'Keluar Dari',
    },
    'dialog_leave_wallet_msg': {
      AppTone.normal: 'Kamu tidak akan bisa mencatat atau melihat transaksi di dompet ini lagi.',
      AppTone.genZ: 'Beneran mau out? Nggak bakal bisa stalking uang di sini lagi.',
      AppTone.milenial: 'You won\'t be able to access or track this wallet anymore.',
      AppTone.boomer: 'Anda tidak akan bisa melihat catatan di sini lagi setelah keluar.',
    },
    'dialog_del_tx_title': {
      AppTone.normal: 'Hapus Transaksi?',
      AppTone.genZ: 'Corek Transaksi?',
      AppTone.milenial: 'Delete Record?',
      AppTone.boomer: 'Hapus Catatan?',
    },
    'dialog_del_tx_msg': {
      AppTone.normal: 'Catatan transaksi ini akan dihapus permanen dari riwayat.',
      AppTone.genZ: 'Jejak yg ini bakal ilang selamanya. Beneran nih?',
      AppTone.milenial: 'This transaction record will be permanently deleted.',
      AppTone.boomer: 'Catatan pengeluaran ini akan dihapus permanen. Lanjutkan?',
    },
    'dialog_del_chat_title': {
      AppTone.normal: 'Hapus Chat?',
      AppTone.genZ: 'Buang Chat Ini?',
      AppTone.milenial: 'Delete Chat?',
      AppTone.boomer: 'Hapus Percakapan?',
    },
    'dialog_del_chat_msg': {
      AppTone.normal: 'Seluruh riwayat pesan di sesi ini akan dihapus permanen.',
      AppTone.genZ: 'Sesi curhat ini bakal ilang selamanya. Beneran nih?',
      AppTone.milenial: 'This chat history will be permanently deleted.',
      AppTone.boomer: 'Catatan percakapan ini akan dihapus permanen. Lanjutkan?',
    },
    'dialog_del_all_chat_title': {
      AppTone.normal: 'Hapus Semua Chat?',
      AppTone.genZ: 'Bersihin Semua Chat?',
      AppTone.milenial: 'Clear All Chats?',
      AppTone.boomer: 'Hapus Semua Riwayat?',
    },
    'dialog_del_all_chat_msg': {
      AppTone.normal: 'Seluruh riwayat chat kamu akan dikosongkan secara permanen.',
      AppTone.genZ: 'Semua jejak curhat di AI bakal ilang total. Mau bersih-bersih?',
      AppTone.milenial: 'All your chat history will be permanently wiped.',
      AppTone.boomer: 'Seluruh catatan percakapan anda akan dihapus selamanya. Lanjutkan?',
    },
    'dialog_api_title': {
      AppTone.normal: 'Manajemen API Key',
      AppTone.genZ: 'Atur Kunci Cuan 🔑',
      AppTone.milenial: 'Manage API Keys',
      AppTone.boomer: 'Pengaturan Kunci API',
    },
    'dialog_api_add': {
      AppTone.normal: 'Tambah Key Baru',
      AppTone.genZ: 'Input Key Baru',
      AppTone.milenial: 'Add New Key',
      AppTone.boomer: 'Tambah Kunci Baru',
    },
    'dialog_api_active': {
      AppTone.normal: 'Key Aktif',
      AppTone.genZ: 'Lagi Dipake 🚀',
      AppTone.milenial: 'Active',
      AppTone.boomer: 'Kunci Terpilih',
    },
    'dialog_api_limited': {
      AppTone.normal: 'Limit',
      AppTone.genZ: 'Limit 🛑',
      AppTone.milenial: 'Limited',
      AppTone.boomer: 'Terbatas',
    },
    'dialog_api_check': {
      AppTone.normal: 'Cek',
      AppTone.genZ: 'Cek',
      AppTone.milenial: 'Check',
      AppTone.boomer: 'Periksa',
    },
    'dialog_api_checking': {
      AppTone.normal: '...',
      AppTone.genZ: '...',
      AppTone.milenial: '...',
      AppTone.boomer: '...',
    },
    'snack_api_saved': {
      AppTone.normal: 'API Key berhasil disimpan!',
      AppTone.genZ: 'Key udah masuk, gass pol!',
      AppTone.milenial: 'API Key saved successfully.',
      AppTone.boomer: 'Kunci API sudah tersimpan dengan aman.',
    },
    'snack_api_deleted': {
      AppTone.normal: 'API Key dihapus.',
      AppTone.genZ: 'Key udah dihempas syantik.',
      AppTone.milenial: 'API Key removed.',
      AppTone.boomer: 'Kunci API telah dihapus.',
    },
    'snack_api_limit_detected': {
      AppTone.normal: 'Kuota API terlampaui. Coba kunci lain.',
      AppTone.genZ: 'Waduh, Key ini kena limit cuys. Coba key lain?',
      AppTone.milenial: 'API quota reached. Try another key?',
      AppTone.boomer: 'Mohon maaf, batas penggunaan tercapai. Silakan coba kunci lainnya.',
    },
    'snack_tx_success': {
      AppTone.normal: 'Transaksi berhasil disimpan!',
      AppTone.genZ: 'Tersimpan mantap poll bosqu!',
      AppTone.milenial: 'Done! Transaksi on-track',
      AppTone.boomer: 'Alhamdulillah sudah tercatat ya',
    },
    'snack_login_err': {
      AppTone.normal: 'Harap isi semua kolom!',
      AppTone.genZ: 'Isi datanya yang bener woi blm kelar!',
      AppTone.milenial: 'Mohon check input mandatory mu',
      AppTone.boomer: 'Tolong diisi semuanya yang teliti nak',
    },
  };

  // Helper function untuk menarik terjemahan seketika!
  static String t(String key) {
    if (_dict.containsKey(key)) {
      return _dict[key]?[notifier.value] ?? _dict[key]![AppTone.normal]!;
    }
    return key; 
  }
}
