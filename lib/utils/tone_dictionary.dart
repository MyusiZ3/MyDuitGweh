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
      AppTone.genZ: 'Duit Gweh',
      AppTone.milenial: 'Total Cashflow',
      AppTone.boomer: 'Harta Titipan',
      AppTone.pasangan: 'Uang Kita',
    },
    'home_income': {
      AppTone.normal: 'Pemasukan',
      AppTone.genZ: 'Uang Masuk',
      AppTone.milenial: 'Earning',
      AppTone.boomer: 'Rezeki',
      AppTone.pasangan: 'Uang Masuk',
    },
    'home_expense': {
      AppTone.normal: 'Pengeluaran',
      AppTone.genZ: 'Pengeluaran',
      AppTone.milenial: 'Spending',
      AppTone.boomer: 'Astaghfirullah Keluar',
      AppTone.pasangan: 'Belanja Bareng',
    },
    'home_recent': {
      AppTone.normal: 'Transaksi Tersimpan',
      AppTone.genZ: 'Riwayat Terakhir',
      AppTone.milenial: 'Recent Transactions',
      AppTone.boomer: 'Buku Kas Terakhir',
      AppTone.pasangan: 'Jejak Belanja Kita',
    },
    'home_empty_title': {
      AppTone.normal: 'Satu catatan, satu perubahan!',
      AppTone.genZ: 'Dompet Lu Anteng Banget!',
      AppTone.milenial: 'Clean Slate, Zero Spend.',
      AppTone.boomer: 'Alhamdulillah, Buku Kas Bersih.',
      AppTone.pasangan: 'Belum ada pengeluaran nih sayang~',
    },
    'home_empty_msg': {
      AppTone.normal: 'Belum ada transaksi, yuk mulai catat sekarang!',
      AppTone.genZ: 'Sepi amat, belom jajan ya? Click + yuk!',
      AppTone.milenial: 'No transactions yet. Start tracking your cashflow!',
      AppTone.boomer: 'Hari ini tidak ada pengumuman belanja.',
      AppTone.pasangan: 'Yuk catat belanja kita hari ini 💗',
    },
    'greeting_pagi': {
      AppTone.normal: 'Selamat Pagi',
      AppTone.genZ: 'Pagi Skid',
      AppTone.milenial: 'Morning vibes',
      AppTone.boomer: 'Selamat Pagi',
      AppTone.pasangan: 'Meowning ^_^',
    },
    'greeting_siang': {
      AppTone.normal: 'Selamat Siang',
      AppTone.genZ: 'Siang Kak',
      AppTone.milenial: 'Happy Lunch Time',
      AppTone.boomer: 'Selamat Siang',
      AppTone.pasangan: 'Siang Sayang..',
    },
    'greeting_sore': {
      AppTone.normal: 'Selamat Sore',
      AppTone.genZ: 'Sore Kak',
      AppTone.milenial: 'Good Afternoon',
      AppTone.boomer: 'Selamat Sore',
      AppTone.pasangan: 'Sore Sayang',
    },
    'greeting_malam': {
      AppTone.normal: 'Selamat Malam',
      AppTone.genZ: 'Malem Kak',
      AppTone.milenial: 'Good Evening',
      AppTone.boomer: 'Selamat Malam',
      AppTone.pasangan: 'Met Malemm..',
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
      AppTone.genZ: 'Gweh Fineshyt',
      AppTone.milenial: 'My Account',
      AppTone.boomer: 'Data Diri Anda',
      AppTone.pasangan: 'Profil Sayangku',
    },
    'profile_tone': {
      AppTone.normal: 'Gaya Bahasa Aplikasi',
      AppTone.genZ: 'Vibe Bahasa Aplikasi',
      AppTone.milenial: 'Language Preferences',
      AppTone.boomer: 'Pilihan Tata Bahasa',
      AppTone.pasangan: 'Gaya Bicara',
    },
    'profile_logout': {
      AppTone.normal: 'Keluar Akun',
      AppTone.genZ: 'Cabut Dulu Ah',
      AppTone.milenial: 'Sign Out',
      AppTone.boomer: 'Tutup Warung',
      AppTone.pasangan: 'Pamit Dulu Yaa',
    },
    // ===== ALERTS & DIALOGS =====
    'dialog_yes': {
      AppTone.normal: 'Ya',
      AppTone.genZ: 'Gass',
      AppTone.milenial: 'Boleh',
      AppTone.boomer: 'Njeh',
      AppTone.pasangan: 'Iyahh',
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
      AppTone.genZ: 'Beneran Luhh?',
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
          'Jangan lupa catat dulu ya sebelum pergi, nanti aku kangen lho~',
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
          'Yakin mau hapus sayang? Semua kenangan transaksi kita hilang lho~ ＞︿＜',
    },
    'dialog_leave_wallet_title': {
      AppTone.normal: 'Keluar Dompet',
      AppTone.genZ: 'Cabut Circle',
      AppTone.milenial: 'Leave Wallet',
      AppTone.boomer: 'Keluar Dari',
      AppTone.pasangan: 'Tinggalin ?',
    },
    'dialog_leave_wallet_msg': {
      AppTone.normal:
          'Kamu tidak akan bisa mencatat atau melihat transaksi di dompet ini lagi.',
      AppTone.genZ:
          'Beneran lu mau out? Nggak bakal bisa stalking uang di sini lagi loh ya cik.',
      AppTone.milenial:
          'You won\'t be able to access or track this wallet anymore.',
      AppTone.boomer:
          'Anda tidak akan bisa melihat catatan di sini lagi setelah keluar.',
      AppTone.pasangan:
          'Kamu gak bisa lihat dompet ini lagi lho sayang, beneran nih? ~(>_<。)＼',
    },
    'dialog_del_tx_title': {
      AppTone.normal: 'Hapus Transaksi?',
      AppTone.genZ: 'Apus Transaksi?',
      AppTone.milenial: 'Delete Record?',
      AppTone.boomer: 'Hapus Catatan?',
      AppTone.pasangan: 'Hapus Ini?',
    },
    'dialog_del_tx_msg': {
      AppTone.normal:
          'Catatan transaksi ini akan dihapus permanen dari riwayat.',
      AppTone.genZ: 'Jejak yg ini bakal ilang selamanya. Beneran nih?',
      AppTone.milenial: 'This transaction record will be permanently deleted.',
      AppTone.boomer:
          'Catatan pengeluaran ini akan dihapus permanen. Lanjutkan?',
      AppTone.pasangan: 'Catatan ini bakal hilang selamanya lho, yakin kamu?',
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
      AppTone.pasangan: 'Obrolan mesra kita bakal ilang nih, yakin kamu? ╯︿╰',
    },
    'dialog_del_all_chat_title': {
      AppTone.normal: 'Hapus Semua Chat?',
      AppTone.genZ: 'Bersihin Semua Chat?',
      AppTone.milenial: 'Clear All Chats?',
      AppTone.boomer: 'Hapus Semua Riwayat?',
      AppTone.pasangan: 'Hapus Semua Kenangan Chat? ಥ_ಥ',
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
          'Semua obrolan mesra kita bakal hilang selamanya nih sayang~ ಥ_ಥ',
    },
    'dialog_api_title': {
      AppTone.normal: 'Manajemen API Key',
      AppTone.genZ: 'Atur API Key',
      AppTone.milenial: 'Manage API Keys',
      AppTone.boomer: 'Pengaturan Kunci API',
      AppTone.pasangan: 'Atur Kunci',
    },
    'dialog_api_add': {
      AppTone.normal: 'Tambah Key Baru',
      AppTone.genZ: 'Input Key Baru',
      AppTone.milenial: 'Add New Key',
      AppTone.boomer: 'Tambah Kunci Baru',
      AppTone.pasangan: 'Tambah Kunci Baru',
    },
    'dialog_api_active': {
      AppTone.normal: 'Key Aktif',
      AppTone.genZ: 'Lagi Dipake',
      AppTone.milenial: 'Active',
      AppTone.boomer: 'Kunci Terpilih',
      AppTone.pasangan: 'Yang Dipake ^_^',
    },
    'dialog_api_limited': {
      AppTone.normal: 'Limit',
      AppTone.genZ: 'Limit jirr',
      AppTone.milenial: 'Limited',
      AppTone.boomer: 'Terbatas',
      AppTone.pasangan: 'Habis Sayang :D',
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
      AppTone.pasangan: 'Udah tersimpan yahh..!',
    },
    'snack_api_deleted': {
      AppTone.normal: 'API Key dihapus.',
      AppTone.genZ: 'Key udah dihytamkan.',
      AppTone.milenial: 'API Key removed.',
      AppTone.boomer: 'Kunci API telah dihapus.',
      AppTone.pasangan: 'Udah dihapus yahh~',
    },
    'snack_api_limit_detected': {
      AppTone.normal: 'Kuota API terlampaui. Coba kunci lain.',
      AppTone.genZ: 'Waduh, Key-nya kena limit jir. Coba key lain?',
      AppTone.milenial: 'API quota reached. Try another key?',
      AppTone.boomer:
          'Mohon maaf, batas penggunaan tercapai. Silakan coba kunci lainnya.',
      AppTone.pasangan: 'Aduh sayang, kuncinya capek nih. Coba yang lain ya~',
    },
    'snack_tx_success': {
      AppTone.normal: 'Transaksi berhasil disimpan!',
      AppTone.genZ: 'Tersimpan mantap poll bosqu!',
      AppTone.milenial: 'Done! Transaksi on-track',
      AppTone.boomer: 'Alhamdulillah sudah tercatat ya',
      AppTone.pasangan: 'Udah tercatat ya sayangku! Pinter deh :3',
    },
    'snack_login_err': {
      AppTone.normal: 'Harap isi semua kolom!',
      AppTone.genZ: 'Isi datanya yang bener woi blm kelar!',
      AppTone.milenial: 'Mohon check input mandatory mu',
      AppTone.boomer: 'Tolong diisi semuanya yang teliti nak',
      AppTone.pasangan: 'Sayang, isi dulu semua kolomnya yaa~ ',
    },
    'dialog_kick_member_title': {
      AppTone.normal: 'Keluarkan Anggota?',
      AppTone.genZ: 'Kick Member Ini?',
      AppTone.milenial: 'Remove member?',
      AppTone.boomer: 'Keluarkan orang ini?',
      AppTone.pasangan: 'Keluarkan dia sayang? 🥺',
    },
    'dialog_kick_member_msg': {
      AppTone.normal: 'Anggota ini tidak akan bisa lagi mengakses dompet ini.',
      AppTone.genZ: 'Beneran mau kick? Dia nggak bakal bisa liat dompet ini lagi.',
      AppTone.milenial: 'This member will lose access to this wallet permanently.',
      AppTone.boomer: 'Orang ini tidak akan bisa melihat catatan di sini lagi.',
      AppTone.pasangan: 'Dia gak bakal bisa join lagi lho sayang, beneran? ~(>_<)',
    },
    // ---------------------------------------------------------
    // WALLET SCREEN EMPTY STATES
    // ---------------------------------------------------------
    'wallet_empty_title': {
      AppTone.normal: 'Belum ada dompet',
      AppTone.genZ: 'Dompet Lu Masih Kosong Melompong',
      AppTone.milenial: 'No Wallets Yet',
      AppTone.boomer: 'Dompet Masih Kosong',
      AppTone.pasangan: 'Belum Ada Dompet Kita 🥺',
    },
    'wallet_empty_msg': {
      AppTone.normal: 'Yuk buat dompet pertama kamu untuk mulai mencatat!',
      AppTone.genZ: 'Bikin dompet dulu skid, biar kaga boncos mulu!',
      AppTone.milenial: 'Create your first wallet to start tracking financial health.',
      AppTone.boomer: 'Silakan buat dompet dulu untuk mencatat rezeki hari ini.',
      AppTone.pasangan: 'Sayang, buat dompet dulu yuk biar kita bisa nabung bareng~ 💖',
    },
    'colab_empty_title': {
      AppTone.normal: 'Belum ada dompet kolaborasi',
      AppTone.genZ: 'Circle Lu Belum Punya Brankas',
      AppTone.milenial: 'No Collaborative Wallets',
      AppTone.boomer: 'Belum Ada Dompet Bersama',
      AppTone.pasangan: 'Belum Ada Brankas Cinta Kita 💖',
    },
    'colab_empty_msg': {
      AppTone.normal: 'Buat dompet colab di tab Wallet untuk patungan bareng teman!',
      AppTone.genZ: 'Ajak sirkel lu patungan di sini, biar kaga ada yang ngutang mulu!',
      AppTone.milenial: 'Collaborate with items or partners here. Create one in Wallet tab!',
      AppTone.boomer: 'Silakan buat dompet bersama untuk keperluan keluarga di menu Dompet.',
      AppTone.pasangan: 'Cari brankas kita di sini ya sayang, biar rahasia keuangan kita aman~ 💑',
    },
    'error_not_creator_delete': {
      AppTone.normal: 'Kamu hanya bisa menghapus transaksimu sendiri! 🚫',
      AppTone.genZ: 'Eits, bukan lu yang input ini! Jangan main apus aja! 😡',
      AppTone.milenial: 'You can only delete transactions you created.',
      AppTone.boomer: 'Hanya bisa menghapus catatan milik sendiri ya.',
      AppTone.pasangan: 'Jangan hapus punya aku dong sayang.. ihh 😠',
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
