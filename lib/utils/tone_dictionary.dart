import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTone { normal, genZ, milenial, boomer, pasangan }

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
      AppTone.pasangan: 'Duit Kita Berdua 💕',
    },
    'home_income': {
      AppTone.normal: 'Pemasukan',
      AppTone.genZ: 'Cuan Masuk 💸',
      AppTone.milenial: 'Earning',
      AppTone.boomer: 'Alhamdulillah Rezeki',
      AppTone.pasangan: 'Rezeki Sayang 💖',
    },
    'home_expense': {
      AppTone.normal: 'Pengeluaran',
      AppTone.genZ: 'Apes Boncos 📉',
      AppTone.milenial: 'Spending',
      AppTone.boomer: 'Astaghfirullah Keluar',
      AppTone.pasangan: 'Belanja Bareng 🛍️',
    },
    'home_recent': {
      AppTone.normal: 'Transaksi Tersimpan',
      AppTone.genZ: 'Riwayat Jajan Terakhir',
      AppTone.milenial: 'Recent Transactions',
      AppTone.boomer: 'Buku Kas Terakhir',
      AppTone.pasangan: 'Jejak Belanja Kita 💑',
    },
    'home_empty': {
      AppTone.normal: 'Belum ada transaksi, yuk mulai catat!',
      AppTone.genZ: 'Sepi amat dompet lu, belum jajan ya?',
      AppTone.milenial: 'No transactions yet. Start tracking!',
      AppTone.boomer: 'Alhamdulillah, hari ini belum ada pengeluaran.',
      AppTone.pasangan:
          'Belum ada catatan hari ini, yuk catat bareng sayang~ 💗',
    },

    // ---------------------------------------------------------
    // BOTTOM NAVIGATION
    // ---------------------------------------------------------
    'nav_home': {
      AppTone.normal: 'Beranda',
      AppTone.genZ: 'Home Gweh',
      AppTone.milenial: 'Dashboard',
      AppTone.boomer: 'Halaman Utama',
      AppTone.pasangan: 'Rumah Kita',
    },
    'nav_wallet': {
      AppTone.normal: 'Dompet',
      AppTone.genZ: 'Brankas',
      AppTone.milenial: 'Wallets',
      AppTone.boomer: 'Saku Celana',
      AppTone.pasangan: 'Dompet Kita',
    },
    'nav_report': {
      AppTone.normal: 'Laporan',
      AppTone.genZ: 'Rapor Boncos',
      AppTone.milenial: 'Analytics',
      AppTone.boomer: 'Buku Tabungan',
      AppTone.pasangan: 'Catatan Kita',
    },
    'nav_profile': {
      AppTone.normal: 'Profil',
      AppTone.genZ: 'Markas',
      AppTone.milenial: 'My Profile',
      AppTone.boomer: 'KTP Saya',
      AppTone.pasangan: 'Sayangku',
    },

    // ---------------------------------------------------------
    // PROFILE SCREEN
    // ---------------------------------------------------------
    'profile_title': {
      AppTone.normal: 'Profil Pemilik',
      AppTone.genZ: 'Markas Gweh 😎',
      AppTone.milenial: 'My Account',
      AppTone.boomer: 'Data Diri Anda',
      AppTone.pasangan: 'Profil Sayangku 💕',
    },
    'profile_tone': {
      AppTone.normal: 'Gaya Bahasa Aplikasi',
      AppTone.genZ: 'Vibe Bahasa Aplikasi ✌️',
      AppTone.milenial: 'Language Preferences',
      AppTone.boomer: 'Pilihan Tata Bahasa',
      AppTone.pasangan: 'Gaya Bicara Kita 💬',
    },
    'profile_logout': {
      AppTone.normal: 'Keluar Akun',
      AppTone.genZ: 'Cabut Dulu Ah 🚪',
      AppTone.milenial: 'Sign Out',
      AppTone.boomer: 'Tutup Warung',
      AppTone.pasangan: 'Pamit Dulu Ya 😘',
    },
    // ===== ALERTS & DIALOGS =====
    'dialog_yes': {
      AppTone.normal: 'Ya',
      AppTone.genZ: 'Gass',
      AppTone.milenial: 'Boleh',
      AppTone.boomer: 'Njeh',
      AppTone.pasangan: 'Iya Sayang 💗',
    },
    'dialog_no': {
      AppTone.normal: 'Batal',
      AppTone.genZ: 'Skip Dulu',
      AppTone.milenial: 'Batal',
      AppTone.boomer: 'Ndak Usah',
      AppTone.pasangan: 'Jangan Deh~',
    },
    'dialog_logout_title': {
      AppTone.normal: 'Keluar Akun?',
      AppTone.genZ: 'Beneran Mau Cabut?',
      AppTone.milenial: 'Sign Out?',
      AppTone.boomer: 'Ingin Keluar Akun?',
      AppTone.pasangan: 'Mau Pergi Dulu? 🥺',
    },
    'dialog_logout_msg': {
      AppTone.normal:
          'Pastikan kamu sudah mencatat semua transaksi hari ini ya.',
      AppTone.genZ: 'Udah kelar nge-track hari ini? Kalau belum ntar lupa lho.',
      AppTone.milenial: 'Make sure you have logged all today\'s activities.',
      AppTone.boomer: 'Pastikan semuanya sudah dicatat dengan benar hari ini.',
      AppTone.pasangan:
          'Jangan lupa catat dulu ya sebelum pergi, nanti aku kangen lho~ 💋',
    },
    'dialog_del_wallet_title': {
      AppTone.normal: 'Hapus Dompet',
      AppTone.genZ: 'Mau Hapus',
      AppTone.milenial: 'Delete Wallet',
      AppTone.boomer: 'Hapus Dompet',
      AppTone.pasangan: 'Hapus Dompet Kita? 😢',
    },
    'dialog_del_wallet_msg': {
      AppTone.normal:
          'Semua data transaksi di dompet ini akan ikut terhapus permanen.',
      AppTone.genZ:
          'Yakin dompet ini dihempas? Duit dan datanya ilang permanen loh.',
      AppTone.milenial:
          'Semua history transaksi akan didiscard secara permanen. Lanjut?',
      AppTone.boomer:
          'Apakah anda yakin? Semua catatan akan terhapus selamanya.',
      AppTone.pasangan:
          'Yakin mau hapus sayang? Semua kenangan transaksi kita hilang lho~ 💔',
    },
    'dialog_leave_wallet_title': {
      AppTone.normal: 'Keluar Dompet',
      AppTone.genZ: 'Cabut Circle',
      AppTone.milenial: 'Leave Wallet',
      AppTone.boomer: 'Keluar Dari',
      AppTone.pasangan: 'Tinggalin Dompet Kita?',
    },
    'dialog_leave_wallet_msg': {
      AppTone.normal:
          'Kamu tidak akan bisa mencatat atau melihat transaksi di dompet ini lagi.',
      AppTone.genZ:
          'Beneran mau out? Nggak bakal bisa stalking uang di sini lagi.',
      AppTone.milenial:
          'You won\'t be able to access or track this wallet anymore.',
      AppTone.boomer:
          'Anda tidak akan bisa melihat catatan di sini lagi setelah keluar.',
      AppTone.pasangan:
          'Kamu gak bisa lihat dompet ini lagi lho sayang, beneran nih? 🥺',
    },
    'dialog_del_tx_title': {
      AppTone.normal: 'Hapus Transaksi?',
      AppTone.genZ: 'Corek Transaksi?',
      AppTone.milenial: 'Delete Record?',
      AppTone.boomer: 'Hapus Catatan?',
      AppTone.pasangan: 'Hapus Catatan Ini Sayang?',
    },
    'dialog_del_tx_msg': {
      AppTone.normal:
          'Catatan transaksi ini akan dihapus permanen dari riwayat.',
      AppTone.genZ: 'Jejak yg ini bakal ilang selamanya. Beneran nih?',
      AppTone.milenial: 'This transaction record will be permanently deleted.',
      AppTone.boomer:
          'Catatan pengeluaran ini akan dihapus permanen. Lanjutkan?',
      AppTone.pasangan: 'Catatan ini bakal hilang selamanya lho, yakin sayang?',
    },
    'dialog_del_chat_title': {
      AppTone.normal: 'Hapus Chat?',
      AppTone.genZ: 'Buang Chat Ini?',
      AppTone.milenial: 'Delete Chat?',
      AppTone.boomer: 'Hapus Percakapan?',
      AppTone.pasangan: 'Hapus Obrolan Kita? 💬',
    },
    'dialog_del_chat_msg': {
      AppTone.normal:
          'Seluruh riwayat pesan di sesi ini akan dihapus permanen.',
      AppTone.genZ: 'Sesi curhat ini bakal ilang selamanya. Beneran nih?',
      AppTone.milenial: 'This chat history will be permanently deleted.',
      AppTone.boomer:
          'Catatan percakapan ini akan dihapus permanen. Lanjutkan?',
      AppTone.pasangan: 'Obrolan mesra kita bakal ilang nih, yakin sayang? 😢',
    },
    'dialog_del_all_chat_title': {
      AppTone.normal: 'Hapus Semua Chat?',
      AppTone.genZ: 'Bersihin Semua Chat?',
      AppTone.milenial: 'Clear All Chats?',
      AppTone.boomer: 'Hapus Semua Riwayat?',
      AppTone.pasangan: 'Hapus Semua Kenangan Chat? 💔',
    },
    'dialog_del_all_chat_msg': {
      AppTone.normal:
          'Seluruh riwayat chat kamu akan dikosongkan secara permanen.',
      AppTone.genZ:
          'Semua jejak curhat di AI bakal ilang total. Mau bersih-bersih?',
      AppTone.milenial: 'All your chat history will be permanently wiped.',
      AppTone.boomer:
          'Seluruh catatan percakapan anda akan dihapus selamanya. Lanjutkan?',
      AppTone.pasangan:
          'Semua obrolan mesra kita bakal hilang selamanya nih sayang~ 😢',
    },
    'dialog_api_title': {
      AppTone.normal: 'Manajemen API Key',
      AppTone.genZ: 'Atur Kunci Cuan 🔑',
      AppTone.milenial: 'Manage API Keys',
      AppTone.boomer: 'Pengaturan Kunci API',
      AppTone.pasangan: 'Atur Kunci Bersama 🔑💕',
    },
    'dialog_api_add': {
      AppTone.normal: 'Tambah Key Baru',
      AppTone.genZ: 'Input Key Baru',
      AppTone.milenial: 'Add New Key',
      AppTone.boomer: 'Tambah Kunci Baru',
      AppTone.pasangan: 'Tambah Kunci Baru Sayang',
    },
    'dialog_api_active': {
      AppTone.normal: 'Key Aktif',
      AppTone.genZ: 'Lagi Dipake 🚀',
      AppTone.milenial: 'Active',
      AppTone.boomer: 'Kunci Terpilih',
      AppTone.pasangan: 'Yang Dipake 💖',
    },
    'dialog_api_limited': {
      AppTone.normal: 'Limit',
      AppTone.genZ: 'Limit 🛑',
      AppTone.milenial: 'Limited',
      AppTone.boomer: 'Terbatas',
      AppTone.pasangan: 'Habis Sayang 🥺',
    },
    'dialog_api_check': {
      AppTone.normal: 'Cek',
      AppTone.genZ: 'Cek',
      AppTone.milenial: 'Check',
      AppTone.boomer: 'Periksa',
      AppTone.pasangan: 'Cek',
    },
    'dialog_api_checking': {
      AppTone.normal: '...',
      AppTone.genZ: '...',
      AppTone.milenial: '...',
      AppTone.boomer: '...',
      AppTone.pasangan: '...',
    },
    'snack_api_saved': {
      AppTone.normal: 'API Key berhasil disimpan!',
      AppTone.genZ: 'Key udah masuk, gass pol!',
      AppTone.milenial: 'API Key saved successfully.',
      AppTone.boomer: 'Kunci API sudah tersimpan dengan aman.',
      AppTone.pasangan: 'Udah tersimpan ya sayang! 💕',
    },
    'snack_api_deleted': {
      AppTone.normal: 'API Key dihapus.',
      AppTone.genZ: 'Key udah dihempas syantik.',
      AppTone.milenial: 'API Key removed.',
      AppTone.boomer: 'Kunci API telah dihapus.',
      AppTone.pasangan: 'Udah dihapus ya sayang~',
    },
    'snack_api_limit_detected': {
      AppTone.normal: 'Kuota API terlampaui. Coba kunci lain.',
      AppTone.genZ: 'Waduh, Key ini kena limit cuys. Coba key lain?',
      AppTone.milenial: 'API quota reached. Try another key?',
      AppTone.boomer:
          'Mohon maaf, batas penggunaan tercapai. Silakan coba kunci lainnya.',
      AppTone.pasangan:
          'Aduh sayang, kuncinya capek nih. Coba yang lain ya~ 🥺',
    },
    'snack_tx_success': {
      AppTone.normal: 'Transaksi berhasil disimpan!',
      AppTone.genZ: 'Tersimpan mantap poll bosqu!',
      AppTone.milenial: 'Done! Transaksi on-track',
      AppTone.boomer: 'Alhamdulillah sudah tercatat ya',
      AppTone.pasangan: 'Udah tercatat ya sayangku! Pinter deh 😘',
    },
    'snack_login_err': {
      AppTone.normal: 'Harap isi semua kolom!',
      AppTone.genZ: 'Isi datanya yang bener woi blm kelar!',
      AppTone.milenial: 'Mohon check input mandatory mu',
      AppTone.boomer: 'Tolong diisi semuanya yang teliti nak',
      AppTone.pasangan: 'Sayang, isi dulu semua kolomnya ya~ 💕',
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
