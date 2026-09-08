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

  static AppTone get currentTone => notifier.value;

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
      AppTone.pasangan: 'Riwayat Terakhir',
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
      AppTone.pasangan: 'Yuk catat belanja kita hari ini ^_^',
    },
    'greeting_pagi': {
      AppTone.normal: 'Selamat Pagi',
      AppTone.genZ: 'Pagi Skid',
      AppTone.milenial: 'Morning vibes',
      AppTone.boomer: 'Selamat Pagi',
      AppTone.pasangan: 'Meowniing ^_^',
    },
    'greeting_siang': {
      AppTone.normal: 'Selamat Siang',
      AppTone.genZ: 'Siang Kak',
      AppTone.milenial: 'Happy Lunch Time',
      AppTone.boomer: 'Selamat Siang',
      AppTone.pasangan: 'Siang Sayaang..',
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
      AppTone.pasangan: 'Met Maleem..',
    },
    'home_net_worth': {
      AppTone.normal: 'Saldo Bersih',
      AppTone.genZ: 'Saldo Bersih',
      AppTone.milenial: 'Net Worth',
      AppTone.boomer: 'Saldo Bersih',
      AppTone.pasangan: 'Saldo Bersih',
    },

    // ---------------------------------------------------------
    // BOTTOM NAVIGATION
    // ---------------------------------------------------------
    'nav_home': {
      AppTone.normal: 'Home',
      AppTone.genZ: 'Home',
      AppTone.milenial: 'Home',
      AppTone.boomer: 'Home',
      AppTone.pasangan: 'Home',
    },
    'nav_wallet': {
      AppTone.normal: 'Wallets',
      AppTone.genZ: 'Wallets',
      AppTone.milenial: 'Wallets',
      AppTone.boomer: 'Wallets',
      AppTone.pasangan: 'Wallets',
    },
    'add_card': {
      AppTone.normal: 'Add Card',
      AppTone.genZ: 'Add Card',
      AppTone.milenial: 'Add Card',
      AppTone.boomer: 'Add Card',
      AppTone.pasangan: 'Add Card',
    },
    'add_wallet': {
      AppTone.normal: 'Add Wallet',
      AppTone.genZ: 'Add Wallet',
      AppTone.milenial: 'Add Wallet',
      AppTone.boomer: 'Add Wallet',
      AppTone.pasangan: 'Add Wallet',
    },
    'nav_colab': {
      AppTone.normal: 'Collab',
      AppTone.genZ: 'Collab',
      AppTone.milenial: 'Collab',
      AppTone.boomer: 'Collab',
      AppTone.pasangan: 'Collab',
    },
    'nav_report': {
      AppTone.normal: 'Report',
      AppTone.genZ: 'Report',
      AppTone.milenial: 'Report',
      AppTone.boomer: 'Report',
      AppTone.pasangan: 'Report',
    },
    'wallet_list_title': {
      AppTone.normal: 'Daftar Dompet',
      AppTone.genZ: 'Brankas Gweh',
      AppTone.milenial: 'My Wallets',
      AppTone.boomer: 'Daftar Simpanan',
      AppTone.pasangan: 'List Dompet',
    },
    'wallet_search_hint': {
      AppTone.normal: 'Cari dompet ...',
      AppTone.genZ: 'Cari ...',
      AppTone.milenial: 'Search wallets...',
      AppTone.boomer: 'Cari catatan...',
      AppTone.pasangan: 'Cari dompet ...',
    },
    'tab_pribadi': {
      AppTone.normal: 'Pribadi',
      AppTone.genZ: 'Private',
      AppTone.milenial: 'Personal',
      AppTone.boomer: 'Pribadi',
      AppTone.pasangan: 'Pribadi',
    },
    'tab_bersama': {
      AppTone.normal: 'Bersama',
      AppTone.genZ: 'Circle',
      AppTone.milenial: 'Collab',
      AppTone.boomer: 'Bersama',
      AppTone.pasangan: 'Collab',
    },
    'tab_hutang': {
      AppTone.normal: 'Hutang',
      AppTone.genZ: 'Hutang',
      AppTone.milenial: 'Hutang',
      AppTone.boomer: 'Hutang',
      AppTone.pasangan: 'Hutang',
    },
    'report_title': {
      AppTone.normal: 'Laporan Keuangan',
      AppTone.genZ: 'Laporan Keuangan',
      AppTone.milenial: 'Laporan Keuangan',
      AppTone.boomer: 'Laporan Keuangan',
      AppTone.pasangan: 'Laporan Keuangan',
    },
    'arch_ai_button': {
      AppTone.normal: 'Arch AI',
      AppTone.genZ: 'Arch AI',
      AppTone.milenial: 'Arch AI',
      AppTone.boomer: 'Arch AI',
      AppTone.pasangan: 'Arch AI',
    },
    'nav_scan': {
      AppTone.normal: 'Scan Struk (AI)',
      AppTone.genZ: 'Scan Struk (AI)',
      AppTone.milenial: 'Scan Struk (AI)',
      AppTone.boomer: 'Scan Struk (AI)',
      AppTone.pasangan: 'Scan Struk (AI)',
    },
    'nav_manual': {
      AppTone.normal: 'Input Manual',
      AppTone.genZ: 'Input Manual',
      AppTone.milenial: 'Input Manual',
      AppTone.boomer: 'Input Manual',
      AppTone.pasangan: 'Input Manual',
    },
    'nav_profile': {
      AppTone.normal: 'Profil',
      AppTone.genZ: 'Markas',
      AppTone.milenial: 'My Profile',
      AppTone.boomer: 'KTP Saya',
      AppTone.pasangan: 'Sayangku',
    },
    'badge_admin': {
      AppTone.normal: 'ADMIN',
      AppTone.genZ: 'ADMIN',
      AppTone.milenial: 'ADMIN',
      AppTone.boomer: 'ADMIN',
      AppTone.pasangan: 'ADMIN',
    },
    'badge_owner': {
      AppTone.normal: 'OWNER',
      AppTone.genZ: 'OWNER',
      AppTone.milenial: 'OWNER',
      AppTone.boomer: 'OWNER',
      AppTone.pasangan: 'OWNER',
    },

    // ---------------------------------------------------------
    // PROFILE SCREEN
    // ---------------------------------------------------------
    'profile_title': {
      AppTone.normal: 'Profil',
      AppTone.genZ: 'Profil',
      AppTone.milenial: 'Profil',
      AppTone.boomer: 'Profil',
      AppTone.pasangan: 'Profil',
    },
    'profile_edit_btn': {
      AppTone.normal: 'Edit',
      AppTone.genZ: 'Edit',
      AppTone.milenial: 'Edit',
      AppTone.boomer: 'Edit',
      AppTone.pasangan: 'Edit',
    },
    'profile_cancel_btn': {
      AppTone.normal: 'Batal',
      AppTone.genZ: 'Gak Jadi',
      AppTone.milenial: 'Discard',
      AppTone.boomer: 'Batalkan',
      AppTone.pasangan: 'Batal',
    },
    'profile_save_btn': {
      AppTone.normal: 'Simpan Perubahan',
      AppTone.genZ: 'Simpan',
      AppTone.milenial: 'Save Changes',
      AppTone.boomer: 'Simpan Data',
      AppTone.pasangan: 'Simpan',
    },
    'profile_label_name': {
      AppTone.normal: 'Nama',
      AppTone.genZ: 'Nama',
      AppTone.milenial: 'Nama',
      AppTone.boomer: 'Nama',
      AppTone.pasangan: 'Nama',
    },
    'profile_label_gender': {
      AppTone.normal: 'Gender',
      AppTone.genZ: 'Jenis Kelamin',
      AppTone.milenial: 'Gender',
      AppTone.boomer: 'Jenis Kelamin',
      AppTone.pasangan: 'Gender',
    },
    'profile_label_dob': {
      AppTone.normal: 'Tanggal Lahir',
      AppTone.genZ: 'Day of Spawn',
      AppTone.milenial: 'Date of Birth',
      AppTone.boomer: 'Tgl Lahir Sesuai KTP',
      AppTone.pasangan: 'Ulang Tahun Kamu',
    },
    'profile_label_job': {
      AppTone.normal: 'Pekerjaan',
      AppTone.genZ: 'Pekerjaan',
      AppTone.milenial: 'Occupation',
      AppTone.boomer: 'Pekerjaan',
      AppTone.pasangan: 'Pekerjaan',
    },
    'profile_hint_name': {
      AppTone.normal: 'Masukkan Nama',
      AppTone.genZ: 'Masukkan Nama',
      AppTone.milenial: 'Input Name',
      AppTone.boomer: 'Tulis Nama Lengkap',
      AppTone.pasangan: 'Masukkan Nama',
    },
    'profile_hint_job': {
      AppTone.normal: 'EX: Mahasiswa',
      AppTone.genZ: 'EX: Mahasiswa',
      AppTone.milenial: 'EX: Mahasiswa',
      AppTone.boomer: 'EX: Pegawai',
      AppTone.pasangan: 'EX: Mahasiswa',
    },
    'profile_hint_dob': {
      AppTone.normal: 'Pilih Tanggal',
      AppTone.genZ: 'Kapan Spawn?',
      AppTone.milenial: 'Select Date',
      AppTone.boomer: 'Pilih Tanggal Lahirnya',
      AppTone.pasangan: 'Kapan Lahirnya Sayang?',
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
      AppTone.pasangan: 'Mau Pergi? ಥ_ಥ',
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
      AppTone.pasangan: 'Hapus Dompet? ＞︿＜',
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
      AppTone.pasangan: 'Tinggalin? ＞︿＜',
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
          'Kamu gak bisa lihat dompet ini lagi lho sayang, beneran nih? ~(>_<。)',
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
      AppTone.pasangan: 'Hapus Obrolan Kita? ಥ_ಥ',
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
      AppTone.genZ: 'Key udah masuk, ikuzooo!',
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
      AppTone.genZ: 'Tersimpan mantap kak!',
      AppTone.milenial: 'Done! Transaksi on-track',
      AppTone.boomer: 'Alhamdulillah sudah tercatat ya',
      AppTone.pasangan: 'Udah tercatat yaahh! Pinter deh :3',
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
      AppTone.genZ: 'Kick Ni Orang?',
      AppTone.milenial: 'Remove member?',
      AppTone.boomer: 'Keluarkan orang ini?',
      AppTone.pasangan: 'Keluarin dia sayang? ≡(▔﹏▔)≡',
    },
    'dialog_kick_member_msg': {
      AppTone.normal: 'Anggota ini tidak akan bisa lagi mengakses dompet ini.',
      AppTone.genZ:
          'Beneran mau kick? Dia nggak bakal bisa liat dompet ini lagi.',
      AppTone.milenial:
          'This member will lose access to this wallet permanently.',
      AppTone.boomer: 'Orang ini tidak akan bisa melihat catatan di sini lagi.',
      AppTone.pasangan:
          'Dia gak bakal bisa join lagi lho sayang, beneran? ~(>_<)',
    },
    // ---------------------------------------------------------
    // WALLET SCREEN EMPTY STATES
    // ---------------------------------------------------------
    'wallet_empty_title': {
      AppTone.normal: 'Belum ada dompet',
      AppTone.genZ: 'Dompet Lu Masih Kosong Melompong',
      AppTone.milenial: 'No Wallets Yet',
      AppTone.boomer: 'Dompet Masih Kosong',
      AppTone.pasangan: 'Belum Ada Dompet ＞︿＜',
    },
    'wallet_empty_msg': {
      AppTone.normal: 'Yuk buat dompet pertama kamu untuk mulai mencatat!',
      AppTone.genZ: 'Bikin dompet dulu skid, biar kaga boncos mulu!',
      AppTone.milenial:
          'Create your first wallet to start tracking financial health.',
      AppTone.boomer:
          'Silakan buat dompet dulu untuk mencatat rezeki hari ini.',
      AppTone.pasangan:
          'Sayang, buat dompet dulu yuk biar kita bisa nabung bareng~ (✿◠‿◠)',
    },
    'colab_empty_title': {
      AppTone.normal: 'Belum ada dompet kolaborasi',
      AppTone.genZ: 'Circle Lu Belum Punya Brankas',
      AppTone.milenial: 'No Collaborative Wallets',
      AppTone.boomer: 'Belum Ada Dompet Bersama',
      AppTone.pasangan: 'Belum Ada Nihh..',
    },
    'colab_empty_msg': {
      AppTone.normal:
          'Buat dompet colab di tab Wallet untuk patungan bareng teman!',
      AppTone.genZ:
          'Ajak sirkel lu patungan di sini, biar kaga ada yang ngutang mulu!',
      AppTone.milenial:
          'Collaborate with items or partners here. Create one in Wallet tab!',
      AppTone.boomer:
          'Silakan buat dompet bersama untuk keperluan keluarga di menu Dompet.',
      AppTone.pasangan:
          'Cari brankas kita di sini ya sayang, biar rahasia keuangan kita aman~ (✿◠‿◠)',
    },
    'tab_tagihan': {
      AppTone.normal: 'Tagihan',
      AppTone.genZ: 'Tagihan',
      AppTone.milenial: 'Bills',
      AppTone.boomer: 'Tagihan',
      AppTone.pasangan: 'Tagihan',
    },
    'sub_empty_title': {
      AppTone.normal: 'Belum ada tagihan',
      AppTone.genZ: 'Belum ada tagihan nih skid',
      AppTone.milenial: 'No active bills',
      AppTone.boomer: 'Belum ada tagihan terdaftar',
      AppTone.pasangan: 'Belum ada tagihan sayang~ (✿◠‿◠)',
    },
    'sub_empty_msg': {
      AppTone.normal: 'Yuk buat tagihan rutin pertamamu agar terpantau!',
      AppTone.genZ: 'Catat tagihan rutin lu biar gak lupa bayar, cik!',
      AppTone.milenial:
          'Add a subscription or recurring bill to track your budget.',
      AppTone.boomer:
          'Silakan daftarkan tagihan rutin anda agar tidak telat bayar.',
      AppTone.pasangan:
          'Yuk tambahin tagihan rutin kita biar gak lupa bayar sayang~ ^_^',
    },
    'btn_add_sub': {
      AppTone.normal: 'Tambah',
      AppTone.genZ: 'Tambah',
      AppTone.milenial: 'Add Bill',
      AppTone.boomer: 'Tambah',
      AppTone.pasangan: 'Tambah',
    },
    'debt_empty_title': {
      AppTone.normal: 'Belum ada catatan hutang',
      AppTone.genZ: 'Sirkel Lu Aman dari Utang',
      AppTone.milenial: 'No active debts or loans',
      AppTone.boomer: 'Belum ada catatan hutang piutang',
      AppTone.pasangan: 'Belum ada hutang sayang~ ^_^',
    },
    'debt_empty_msg': {
      AppTone.normal:
          'Yuk catat hutang atau piutangmu agar tidak lupa menagih atau membayar!',
      AppTone.genZ: 'Catat utang/piutang lu biar kaga lupa pas ditagih!',
      AppTone.milenial:
          'Track money you owe or are owed to stay on top of your finances.',
      AppTone.boomer:
          'Silakan catat hutang piutang anda di sini demi ketertiban bersama.',
      AppTone.pasangan: 'Yuk catat hutang kita biar cepat lunas sayang~',
    },
    'error_not_creator_delete': {
      AppTone.normal: 'Kamu hanya bisa menghapus transaksimu sendiri!',
      AppTone.genZ: 'Eits, bukan lu yang input ini! Jangan main apus aja!',
      AppTone.milenial: 'You can only delete transactions you created.',
      AppTone.boomer: 'Hanya bisa menghapus catatan milik sendiri ya.',
      AppTone.pasangan: 'Jangan hapus punya aku dong sayang.. ihh ￣へ￣',
    },
    'offline_mode_title': {
      AppTone.normal: 'Mode Luring',
      AppTone.genZ: 'Offlene Mode Cik',
      AppTone.milenial: 'Offline Mode',
      AppTone.boomer: 'Tanpa Koneksi',
      AppTone.pasangan: 'Gak Ada Sinyal Sayang..',
    },
    'offline_mode_msg': {
      AppTone.normal: 'Koneksi terputus. Data disimpan secara lokal.',
      AppTone.genZ: 'Sinyal ilang jirr. Tenang, data aman di hape.',
      AppTone.milenial: 'No connection. Data will be synced later.',
      AppTone.boomer: 'Mohon maaf, internet terputus. Data disimpan di memori.',
      AppTone.pasangan: 'Sinyalnya kabur nih, aku simpenin dulu ya datanya~',
    },
    'online_mode_msg': {
      AppTone.normal: 'Koneksi kembali terhubung!',
      AppTone.genZ: 'Mantap, sinyal balik lagi!',
      AppTone.milenial: 'Back online!',
      AppTone.boomer: 'Alhamdulillah, koneksi sudah normal.',
      AppTone.pasangan: 'Hore, kita nyambung lagi sayang! ^_^',
    },
    'loading_msg': {
      AppTone.normal: 'Mohon tunggu...',
      AppTone.genZ: 'Sabar ya skid...',
      AppTone.milenial: 'Just a moment...',
      AppTone.boomer: 'Tunggu sebentar ya nak...',
      AppTone.pasangan: 'Sabar yaahh bntar lagi kok..',
    },
    'info_button': {
      AppTone.normal: 'Oke, Mengerti',
      AppTone.genZ: 'Iye paham',
      AppTone.milenial: 'Got it',
      AppTone.boomer: 'Baiklah',
      AppTone.pasangan: 'Iyaa Sayang..',
    },
    'ai_maint_title': {
      AppTone.normal: 'AI Beristirahat',
      AppTone.genZ: 'AI Lagi Molor',
      AppTone.milenial: 'AI Maintenance',
      AppTone.boomer: 'AI Sedang Jeda',
      AppTone.pasangan: 'AI Kita Lagi Bobo..',
    },
    'ai_maint_msg': {
      AppTone.normal: 'Layanan AI sedang dinonaktifkan sementara oleh admin.',
      AppTone.genZ: 'Admin lagi otak-atik AI-nya, sabar ya jir.',
      AppTone.milenial: 'The AI service is currently disabled by admin.',
      AppTone.boomer: 'Admin sedang merapikan sistem AI sebentar.',
      AppTone.pasangan: 'Admin lagi dandanin AI-nya sayang, nanti yaa..',
    },
    'ai_maint_button': {
      AppTone.normal: 'Siap, Tunggu Kabar!',
      AppTone.genZ: 'Okedeh gamasalah',
      AppTone.milenial: 'Notify me later',
      AppTone.boomer: 'Baik, saya tunggu.',
      AppTone.pasangan: 'Ok sayang, kabarin ya!',
    },
    'tone_selector_title': {
      AppTone.normal: 'Gaya Bahasa AI',
      AppTone.genZ: 'Vibe Bahasa AI',
      AppTone.milenial: 'AI Personality',
      AppTone.boomer: 'Pilihan Bahasa AI',
      AppTone.pasangan: 'Gaya Bicara Kita',
    },
    'tone_selector_subtitle': {
      AppTone.normal: 'Pilih kepribadian asistenmu',
      AppTone.genZ: 'Pilih vibe asisten luh',
      AppTone.milenial: 'Choose your assistant\'s personality',
      AppTone.boomer: 'Pilih tutur kata asisten anda',
      AppTone.pasangan: 'Pilih mau aku panggil apa sayang..',
    },
    'tone_desc_normal': {
      AppTone.normal: 'Profesional, singkat, dan padat.',
      AppTone.genZ: 'Biasa aja bosenin.',
      AppTone.milenial: 'Standard professional.',
      AppTone.boomer: 'Formal dan tertib.',
      AppTone.pasangan: 'Formal kayak orang asing.',
    },
    'tone_desc_genz': {
      AppTone.normal: 'Gaya Gen-Z yang santai dan seru.',
      AppTone.genZ: 'Gweh banget ini mah.',
      AppTone.milenial: 'Fun Gen-Z style.',
      AppTone.boomer: 'Gaya anak muda sekarang.',
      AppTone.pasangan: 'Seru kayak temen deket.',
    },
    'tone_desc_milenial': {
      AppTone.normal: 'Gaya Milenial yang dewasa tapi santai.',
      AppTone.genZ: 'Agak tua dikit lah.',
      AppTone.milenial: 'Relatable millennial.',
      AppTone.boomer: 'Sopan tapi santai.',
      AppTone.pasangan: 'Dewasa banget.',
    },
    'tone_desc_boomer': {
      AppTone.normal: 'Gaya orang tua yang bijak dan ramah.',
      AppTone.genZ: 'Kaya kakek gweh.',
      AppTone.milenial: 'Wise & polite.',
      AppTone.boomer: 'Sangat sopan dan bijak.',
      AppTone.pasangan: 'Kayak bapak sendiri.',
    },
    'tone_desc_pasangan': {
      AppTone.normal: 'Gaya pasangan yang sangat perhatian.',
      AppTone.genZ: 'Cringe jirr tapi asik.',
      AppTone.milenial: 'Sweet heart mode.',
      AppTone.boomer: 'Kurang sopan buat orang tua.',
      AppTone.pasangan: 'Aku yang paling sayang kamu! ❤️',
    },
    'budget_title': {
      AppTone.normal: 'Target Budget',
      AppTone.genZ: 'Batas Boncos',
      AppTone.milenial: 'Monthly Limit',
      AppTone.boomer: 'Batas Belanja',
      AppTone.pasangan: 'Batas Jajan Kita',
    },
    'budget_subtitle': {
      AppTone.normal: 'Atur batas pengeluaran bulananmu.',
      AppTone.genZ: 'Atur limit biar kaga kena hytam.',
      AppTone.milenial: 'Set your monthly spending cap.',
      AppTone.boomer: 'Tentukan batas belanja bulan ini.',
      AppTone.pasangan: 'Yuk atur jajan kita bulan ini sayang~',
    },
    'understood_button': {
      AppTone.normal: 'UNDERSTOOD',
      AppTone.genZ: 'OKEE GAS',
      AppTone.milenial: 'GOT IT',
      AppTone.boomer: 'MENGERTI',
      AppTone.pasangan: 'SIAAPP SAYANG',
    },
    'scan_loading_title': {
      AppTone.normal: 'Menganalisa Struk...',
      AppTone.genZ: 'Lagi Stalking Struk...',
      AppTone.milenial: 'Analyzing Receipt...',
      AppTone.boomer: 'Sedang Membaca Nota...',
      AppTone.pasangan: 'Bentar ya aku itungin struknya...',
    },
    'scan_loading_msg': {
      AppTone.normal: 'Sistem sedang merapikan data nota kamu secara otomatis',
      AppTone.genZ: 'Wait ya cik, sistem lagi ngerapiin bon luh.',
      AppTone.milenial: 'Organizing your receipt data automatically.',
      AppTone.boomer: 'Sistem sedang mencatat isi nota anda dengan rapi.',
      AppTone.pasangan:
          'Sabar ya sayang, aku lagi catetin belanjaan kamu tadi ^_^',
    },
    'survey_title': {
      AppTone.normal: 'Bagaimana Pengalamanmu?',
      AppTone.genZ: 'Suka Gak Sama App-nya?',
      AppTone.milenial: 'Rate Your Experience',
      AppTone.boomer: 'Bagaimana Kabar Aplikasi Ini?',
      AppTone.pasangan: 'Kamu Suka App-nya Sayang?',
    },
    'survey_subtitle': {
      AppTone.normal: 'Bantu Archen bikin MyDuitGweh makin sakti buat kamu!',
      AppTone.genZ: 'Bantu gweh bikin ini makin GG buat luh!',
      AppTone.milenial: 'Help us make MyDuitGweh better for you!',
      AppTone.boomer: 'Bantu kami memperbaiki pelayanan untuk anda.',
      AppTone.pasangan: 'Bantu aku biar app ini makin jago buat kita~',
    },
    'survey_impress_title': {
      AppTone.normal: 'Bagian apa yang paling berkesan?',
      AppTone.genZ: 'Mana yang Paling Epic?',
      AppTone.milenial: 'What impressed you most?',
      AppTone.boomer: 'Fitur mana yang anda suka?',
      AppTone.pasangan: 'Mana yang paling kamu suka sayang?',
    },
    'survey_detail_title': {
      AppTone.normal: 'Ceritakan lebih detail (Opsional)',
      AppTone.genZ: 'Spill dong detailnya (Opsional)',
      AppTone.milenial: 'Tell us more (Optional)',
      AppTone.boomer: 'Ceritakan saran anda (Jika ada)',
      AppTone.pasangan: 'Cerita ke aku dong sayang.. (Opsional)',
    },
    'survey_hint': {
      AppTone.normal: 'Saran, keluhan, atau pujian...',
      AppTone.genZ: 'Curhat di sini aja bang...',
      AppTone.milenial: 'Feedback, complains, or praises...',
      AppTone.boomer: 'Silakan tulis masukan anda...',
      AppTone.pasangan: 'Tulis apapun yang kamu mau sayang...',
    },
    'survey_button': {
      AppTone.normal: 'KIRIM FEEDBACK SEKARANG',
      AppTone.genZ: 'GASS KIRIM SEKARANG',
      AppTone.milenial: 'SUBMIT FEEDBACK',
      AppTone.boomer: 'KIRIM MASUKAN ANDA',
      AppTone.pasangan: 'KIRIM FEEDBACKNYA SAYANG',
    },
    'survey_rating_none': {
      AppTone.normal: 'Pilih Bintang-mu!',
      AppTone.genZ: 'Kasih Bintang Dong!',
      AppTone.milenial: 'Rate Us!',
      AppTone.boomer: 'Berikan Penilaian.',
      AppTone.pasangan: 'Kasih Bintangnya Sayang!',
    },
    'survey_rating_1': {
      AppTone.normal: 'Kurang memuaskan',
      AppTone.genZ: 'Ampun Bang',
      AppTone.milenial: 'Not Recommended',
      AppTone.boomer: 'Banyak Kekurangan',
      AppTone.pasangan: 'Sedih Deh..',
    },
    'survey_rating_2': {
      AppTone.normal: 'Butuh perbaikan',
      AppTone.genZ: 'Agak Laen',
      AppTone.milenial: 'Needs Improvement',
      AppTone.boomer: 'Perlu Dirapikan',
      AppTone.pasangan: 'Coba Lagi Ya..',
    },
    'survey_rating_3': {
      AppTone.normal: 'Cukup baik',
      AppTone.genZ: 'Boleh Lah',
      AppTone.milenial: 'Satisfactory',
      AppTone.boomer: 'Lumayan Bagus',
      AppTone.pasangan: 'Oke Kok Sayang',
    },
    'survey_rating_4': {
      AppTone.normal: 'Memuaskan',
      AppTone.genZ: 'Mantap Cik',
      AppTone.milenial: 'Great Job',
      AppTone.boomer: 'Sangat Baik',
      AppTone.pasangan: 'Puas Banget!',
    },
    'survey_rating_5': {
      AppTone.normal: 'Luar biasa',
      AppTone.genZ: 'Gila Epic!',
      AppTone.milenial: 'Outstanding!',
      AppTone.boomer: 'Sempurna Nak',
      AppTone.pasangan: 'SAYANG BANGET!',
    },
    'success_update_profile': {
      AppTone.normal: 'Profil berhasil diperbarui!',
      AppTone.genZ: 'Mantap, profil lu udah diupdate!',
      AppTone.milenial: 'Profile updated successfully!',
      AppTone.boomer: 'Data profil sudah bapak simpan ya nak.',
      AppTone.pasangan: 'Profil kamu dah diupdate yahh~ ^_^',
    },
    'category_not_found': {
      AppTone.normal: 'Kategori tidak ditemukan',
      AppTone.genZ: 'Kaga nemu jirr, typo kali?',
      AppTone.milenial: 'Oops, category not found!',
      AppTone.boomer: 'Maaf nak, kategorinya tidak ada.',
      AppTone.pasangan: 'Gak ada itu sayang, coba yang lain ya.. (✿◠‿◠)',
    },
    'wallet_not_found': {
      AppTone.normal: 'Dompet tidak ditemukan',
      AppTone.genZ: 'Asli, kaga ada nih dompet!',
      AppTone.milenial: 'Wallet not found, check again?',
      AppTone.boomer: 'Bapak ga nemu dompet itu.',
      AppTone.pasangan: 'Dompet kita yang ini gak ada sayang.. ┌( ಠ_ಠ)┘',
    },

    // ---------------------------------------------------------
    // DEBT MANAGEMENT
    // ---------------------------------------------------------
    'debt_increase_title': {
      AppTone.normal: 'Tambah Nominal {type}',
      AppTone.genZ: 'Mau Ngutang/Pinjemin Lagi?',
      AppTone.milenial: 'Increase {type} Amount',
      AppTone.boomer: 'Tambah Catatan {type}',
      AppTone.pasangan: 'Tambah {type} Kita Sayang',
    },
    'debt_increase_msg_utang': {
      AppTone.normal: 'Berapa nominal tambahan yang Anda pinjam?',
      AppTone.genZ: 'Berapa lagi utang yang lu tambah, cik?',
      AppTone.milenial: 'How much more are you borrowing?',
      AppTone.boomer: 'Berapa tambahan hutang yang anda ambil?',
      AppTone.pasangan: 'Kita nambah pinjeman berapa lagi nih sayang?',
    },
    'debt_increase_msg_piutang': {
      AppTone.normal: 'Berapa nominal tambahan yang Anda pinjamkan?',
      AppTone.genZ: 'Mau pinjemin berapa lagi ke dia?',
      AppTone.milenial: 'How much more are you lending?',
      AppTone.boomer: 'Berapa tambahan uang yang anda pinjamkan?',
      AppTone.pasangan: 'Kita mau pinjemin berapa lagi ke dia sayang?',
    },
    'debt_increase_label': {
      AppTone.normal: 'Nominal Tambahan',
      AppTone.genZ: 'Nambah Berapa?',
      AppTone.milenial: 'Additional Amount',
      AppTone.boomer: 'Jumlah Tambahan',
      AppTone.pasangan: 'Nambah Berapa Sayang?',
    },
    'debt_select_wallet': {
      AppTone.normal: 'Pilih Dompet',
      AppTone.genZ: 'Pake Dompet Mana?',
      AppTone.milenial: 'Select Source Wallet',
      AppTone.boomer: 'Gunakan Simpanan Mana?',
      AppTone.pasangan: 'Pake Uang yang Mana Sayang?',
    },
    'debt_error_incomplete': {
      AppTone.normal: 'Lengkapi data terlebih dahulu',
      AppTone.genZ: 'Isi dulu woi, jangan maen gass aja!',
      AppTone.milenial: 'Please complete the required fields.',
      AppTone.boomer: 'Tolong diisi dulu semuanya ya.',
      AppTone.pasangan: 'Isi dulu semuanya ya sayangku..',
    },
    'debt_success_increase': {
      AppTone.normal: 'Nominal {type} berhasil ditambah!',
      AppTone.genZ: 'Mantap, data utang lu udah nambah!',
      AppTone.milenial: 'Amount successfully added to your {type}.',
      AppTone.boomer: 'Alhamdulillah, catatan sudah diperbarui.',
      AppTone.pasangan: 'Udah nambah ya catatan kita sayang!',
    },
    'debt_edit_title': {
      AppTone.normal: 'Ubah Catatan {type}',
      AppTone.genZ: 'Edit Data {type}',
      AppTone.milenial: 'Edit {type} Record',
      AppTone.boomer: 'Koreksi Catatan {type}',
      AppTone.pasangan: 'Ubah Catatan {type} Kita',
    },
    'debt_label_title': {
      AppTone.normal: 'Nama / Keterangan',
      AppTone.genZ: 'Buat Apa / Siapa?',
      AppTone.milenial: 'Title / Description',
      AppTone.boomer: 'Keterangan Catatan',
      AppTone.pasangan: 'Keterangan Apa Sayang?',
    },
    'debt_history_table_title': {
      AppTone.normal: 'Nama / Keterangan',
      AppTone.genZ: 'Buat Apa / Siapa?',
      AppTone.milenial: 'Title / Description',
      AppTone.boomer: 'Keterangan Catatan',
      AppTone.pasangan: 'Keterangan Apa Sayang?',
    },
    'debt_label_total': {
      AppTone.normal: 'Total {type}',
      AppTone.genZ: 'Total {type}',
      AppTone.milenial: 'Total {type}',
      AppTone.boomer: 'Total {type}',
      AppTone.pasangan: 'Total {type} Kita',
    },
    'debt_select_due_date': {
      AppTone.normal: 'Pilih Jatuh Tempo (Opsional)',
      AppTone.genZ: 'Kapan Mau Kelar? (Opsional)',
      AppTone.milenial: 'Select Due Date (Optional)',
      AppTone.boomer: 'Pilih Tanggal Jatuh Tempo',
      AppTone.pasangan: 'Kapan Mau Lunas Sayang? (Opsional)',
    },
    'debt_due_date_set': {
      AppTone.normal: 'Jatuh Tempo: {date}',
      AppTone.genZ: 'Deadline: {date}',
      AppTone.milenial: 'Due on {date}',
      AppTone.boomer: 'Tanggal Lunas: {date}',
      AppTone.pasangan: 'Lunas tgl {date} ya sayang',
    },
    'debt_success_update': {
      AppTone.normal: 'Berhasil memperbarui catatan {type}',
      AppTone.genZ: 'Sip, datanya udah lu ubah!',
      AppTone.milenial: 'Successfully updated {type} record.',
      AppTone.boomer: 'Alhamdulillah, catatan sudah dikoreksi.',
      AppTone.pasangan: 'Udah aku ubah ya catatannya sayang!',
    },
    'debt_delete_confirm_title': {
      AppTone.normal: 'Hapus Catatan {type}?',
      AppTone.genZ: 'Apus Catatan {type}?',
      AppTone.milenial: 'Delete {type} Record?',
      AppTone.boomer: 'Hapus Catatan {type}?',
      AppTone.pasangan: 'Hapus Catatan {type} Kita?',
    },
    'debt_delete_confirm_msg': {
      AppTone.normal:
          'Apakah Anda yakin ingin menghapus catatan {type} "{title}"? Saldo dompet akan dikembalikan dan riwayat transaksi terkait akan dihapus.',
      AppTone.genZ:
          'Serius mau apus "{title}"? Ntar saldo balik lagi dan riwayat luh ilang semua lho.',
      AppTone.milenial:
          'Are you sure you want to delete "{title}"? Wallet balances will be reverted and transaction history will be cleared.',
      AppTone.boomer:
          'Apakah anda yakin menghapus catatan "{title}"? Semua hitungan akan dikembalikan seperti semula.',
      AppTone.pasangan:
          'Beneran mau hapus "{title}" sayang? Nanti saldonya balik lagi lho.. yakin?',
    },
    'debt_success_delete': {
      AppTone.normal: 'Catatan {type} berhasil dihapus',
      AppTone.genZ: 'Hehe, data {type}-nya udah ilang!',
      AppTone.milenial: '{type} record deleted successfully.',
      AppTone.boomer: 'Catatan {type} sudah dihapus.',
      AppTone.pasangan: 'Udah aku hapus ya catatannya sayang~',
    },
    'btn_add_nominal': {
      AppTone.normal: 'Tambah Nominal',
      AppTone.genZ: 'Gas Tambah',
      AppTone.milenial: 'Add Amount',
      AppTone.boomer: 'Tambahkan',
      AppTone.pasangan: 'Tambah Sayang',
    },
    'debt_payment_title': {
      AppTone.normal: 'Pembayaran: {title}',
      AppTone.genZ: 'Bayar {title}',
      AppTone.milenial: 'Payment: {title}',
      AppTone.boomer: 'Bayar Cicilan {title}',
      AppTone.pasangan: 'Bayar {title} Kita',
    },
    'debt_remaining_label': {
      AppTone.normal: 'Sisa {type}: {amount}',
      AppTone.genZ: 'Sisa: {amount}',
      AppTone.milenial: 'Remaining: {amount}',
      AppTone.boomer: 'Sisa Tunggakan: {amount}',
      AppTone.pasangan: 'Sisa {type} Kita: {amount}',
    },
    'debt_payment_wallet_hint': {
      AppTone.normal: 'Pilih Dompet Sumber/Tujuan',
      AppTone.genZ: 'Pake Duit Mana?',
      AppTone.milenial: 'Select Account',
      AppTone.boomer: 'Ambil Dari Simpanan',
      AppTone.pasangan: 'Pilih Dompetnya Sayang',
    },
    'debt_payment_note_hint': {
      AppTone.normal: 'Catatan (Opsional)',
      AppTone.genZ: 'Curhat dikit (Opsional)',
      AppTone.milenial: 'Note (Optional)',
      AppTone.boomer: 'Keterangan Tambahan',
      AppTone.pasangan: 'Catatan Sayang (Opsional)',
    },
    'debt_payment_error_incomplete': {
      AppTone.normal: 'Pilih dompet dan masukkan nominal',
      AppTone.genZ: 'Duitnya berapa? Dompetnya mana?',
      AppTone.milenial: 'Select wallet & input amount',
      AppTone.boomer: 'Tolong pilih dompet dan isi nominalnya.',
      AppTone.pasangan: 'Pilih dompet sama nominalnya dulu sayang..',
    },
    'debt_payment_error_exceed': {
      AppTone.normal: 'Nominal melebihi sisa {type}!',
      AppTone.genZ: 'Kegedean cik, lebih dari sisa!',
      AppTone.milenial: 'Amount exceeds remaining balance!',
      AppTone.boomer: 'Nominal tidak boleh melebihi sisa.',
      AppTone.pasangan: 'Kebanyakan sayang, sisa kita gak segitu..',
    },
    'debt_payment_success': {
      AppTone.normal: 'Pembayaran berhasil dicatat!',
      AppTone.genZ: 'Lunas dikit, mantaap!',
      AppTone.milenial: 'Payment recorded successfully!',
      AppTone.boomer: 'Alhamdulillah, cicilan sudah dibayar.',
      AppTone.pasangan: 'Udah terbayar ya sayang! Semangat nabung!',
    },
    'debt_tx_edit_title': {
      AppTone.normal: 'Ubah Nominal',
      AppTone.genZ: 'Edit Angka',
      AppTone.milenial: 'Edit Amount',
      AppTone.boomer: 'Koreksi Nominal',
      AppTone.pasangan: 'Ubah Nominal',
    },
    'debt_tx_edit_msg': {
      AppTone.normal: 'Masukkan nominal transaksi yang benar:',
      AppTone.genZ: 'Harusnya berapa nominalnya?',
      AppTone.milenial: 'Enter the correct amount:',
      AppTone.boomer: 'Tuliskan nominal yang seharusnya.',
      AppTone.pasangan: 'Nominal yang bener berapa sayang?',
    },
    'debt_tx_success_update': {
      AppTone.normal: 'Berhasil memperbarui nominal',
      AppTone.genZ: 'Angkanya udah bener sekarang!',
      AppTone.milenial: 'Amount updated successfully.',
      AppTone.boomer: 'Nominal sudah dikoreksi.',
      AppTone.pasangan: 'Udah aku benerin ya nominalnya sayang!',
    },
    'debt_tx_delete_title': {
      AppTone.normal: 'Hapus Transaksi',
      AppTone.genZ: 'Apus Riwayat Ini?',
      AppTone.milenial: 'Delete Transaction',
      AppTone.boomer: 'Hapus Riwayat Catatan',
      AppTone.pasangan: 'Hapus Riwayat Ini?',
    },
    'debt_tx_delete_msg': {
      AppTone.normal:
          'Apakah Anda yakin ingin menghapus riwayat transaksi ini? Saldo dompet dan sisa {type} akan disesuaikan.',
      AppTone.genZ: 'Mau apus riwayat ini? Ntar saldo balik lagi lho.',
      AppTone.milenial:
          'Delete this transaction history? Wallet balance and remaining {type} will be adjusted.',
      AppTone.boomer:
          'Apakah anda yakin menghapus riwayat ini? Saldo akan dikembalikan.',
      AppTone.pasangan:
          'Yakin mau hapus riwayat ini sayang? Saldo kita bakal balik lho..',
    },
    'debt_tx_success_delete': {
      AppTone.normal: 'Riwayat transaksi berhasil dihapus',
      AppTone.genZ: 'Jejak transaksi udah ilang!',
      AppTone.milenial: 'Transaction history deleted.',
      AppTone.boomer: 'Riwayat sudah dihapus.',
      AppTone.pasangan: 'Udah aku hapus ya riwayatnya sayang!',
    },
    'debt_history_edit_title': {
      AppTone.normal: 'Ubah Nominal Transaksi',
      AppTone.genZ: 'Edit Angka Transaksi',
      AppTone.milenial: 'Edit Transaction Amount',
      AppTone.boomer: 'Koreksi Nominal Riwayat',
      AppTone.pasangan: 'Ubah Nominal Transaksi Kita Sayang',
    },
    'debt_history_table_amount': {
      AppTone.normal: 'Nominal Baru',
      AppTone.genZ: 'Angka Baru',
      AppTone.milenial: 'New Amount',
      AppTone.boomer: 'Nominal Koreksi',
      AppTone.pasangan: 'Nominal Barunya Sayang',
    },
    'date_today': {
      AppTone.normal: 'Hari Ini',
      AppTone.genZ: 'Hari Ini',
      AppTone.milenial: 'Today',
      AppTone.boomer: 'Dinten Iki',
      AppTone.pasangan: 'Hari Ini',
    },
    'btn_confirm': {
      AppTone.normal: 'Siap, Laksanakan!',
      AppTone.genZ: 'Oke Gass!',
      AppTone.milenial: 'Got it!',
      AppTone.boomer: 'Nggih, Matur Nuwun.',
      AppTone.pasangan: 'Baik, Sayang',
    },
    'date_yesterday': {
      AppTone.normal: 'Kemarin',
      AppTone.genZ: 'Kemarin',
      AppTone.milenial: 'Yesterday',
      AppTone.boomer: 'Wingi',
      AppTone.pasangan: 'Kemarin Sayang',
    },
    'tips_1': {
      AppTone.normal: 'Sisihkan 20% penghasilan untuk tabungan.',
      AppTone.genZ: 'Sering self-reward boleh, tapi tabungan jangan lupa ges!',
      AppTone.milenial: 'Investasikan sisa saldo ke dana darurat.',
      AppTone.boomer: 'Hemat pangkal kaya, jangan boros ya.',
      AppTone.pasangan: 'Tabung dikit-dikit buat masa depan kita ya sayang.',
    },
    'tips_2': {
      AppTone.normal: 'Catat setiap pengeluaran kecil agar terpantau.',
      AppTone.genZ: 'Jangan sampai bon jebol gara-gara kopi susu 40rb!',
      AppTone.milenial: 'Daily monitoring is the key to financial freedom.',
      AppTone.boomer: 'Catat semua biar nggak bingung uangnya ke mana.',
      AppTone.pasangan: 'Jangan lupa catat belanjaannya ya sayang.',
    },
    'tips_3': {
      AppTone.normal: 'Bandingkan harga sebelum membeli barang besar.',
      AppTone.genZ: 'Cek diskon dulu sebelum check out keranjang!',
      AppTone.milenial: 'Always look for better value before spending.',
      AppTone.boomer: 'Teliti sebelum membeli, jangan asal bayar.',
      AppTone.pasangan: 'Tanya aku dulu kalau mau beli yang mahal ya sayang.',
    },
  };

  // Helper function untuk menarik terjemahan seketika!
  static String t(String key) {
    if (_dict.containsKey(key)) {
      return _dict[key]?[notifier.value] ?? _dict[key]![AppTone.normal]!;
    }
    return key;
  }

  // SMART TIPS CATEGORIES
  static const Map<String, Map<AppTone, List<String>>> _smartTips = {
    'saving': {
      AppTone.normal: [
        'Pertahankan pola hematmu!',
        'Tabunganmu akan berterima kasih.',
        'Hari yang sangat produktif secara finansial.'
      ],
      AppTone.genZ: [
        'Gokil, hemat parah hari ini!',
        'Duit aman, mental tenang.',
        'Slay! Jago banget manage duit.'
      ],
      AppTone.milenial: [
        'Good job! Neraca hari ini surplus.',
        'Disiplin adalah kunci freedom.',
        'Lanjutin gaya hidup minimalisnya.'
      ],
      AppTone.boomer: [
        'Bagus, rajin menabung pangkal kaya.',
        'Sangat bijak dalam belanja.',
        'Contoh yang baik untuk keluarga.'
      ],
      AppTone.pasangan: [
        'Asik, bisa buat tabungan liburan bareng!',
        'Kita hebat bisa hemat hari ini.',
        'Sayang pinter banget atur uang.'
      ],
    },
    'overspending': {
      AppTone.normal: [
        'Pengeluaran hari ini cukup tinggi.',
        'Coba review lagi belanjamu.',
        'Mulai batasi pengeluaran non-primer.'
      ],
      AppTone.genZ: [
        'Waduh, hari ini boncos ya?',
        'Self-reward tapi jangan bikin bangkrut.',
        'Rem dikit jajan starling-nya.'
      ],
      AppTone.milenial: [
        'Cek lagi urgensi belanja tadi.',
        'Hati-hati, lifestyle creep mulai terasa.',
        'Investasi lebih penting dari jajan.'
      ],
      AppTone.boomer: [
        'Boros itu kawan setan.',
        'Jangan besar pasak daripada tiang.',
        'Ingat kebutuhan masa depan.'
      ],
      AppTone.pasangan: [
        'Duh, jajan apa aja tadi sayang?',
        'Pelan-pelan ya belanjanya biar aman.',
        'Ingat cicilan rumah/tabungan nikah!'
      ],
    },
    'urgent': {
      AppTone.normal: [
        'Budget menipis! Segera stop jajan.',
        'Kondisi keuangan kritis.',
        'Fokus hanya pada kebutuhan pokok.'
      ],
      AppTone.genZ: [
        'SIAGA 1! Saldo udah sekarat.',
        'Makan indomie dulu yuk sampe gajian.',
        'Gak usah nongkrong dulu, skip!'
      ],
      AppTone.milenial: [
        'Emergency protocol active!',
        'Budget bulanan hampir jebol.',
        'Evaluasi total pengeluaranmu.'
      ],
      AppTone.boomer: [
        'Waspada, kondisi keuangan mengkhawatirkan.',
        'Hemat pangkal kaya, boros pangkal melarat.',
        'Segera ikat ikat pinggang.'
      ],
      AppTone.pasangan: [
        'Sayang, kita harus super hemat minggu ini.',
        'Budget kita hampir habis, sabar dulu ya.',
        'Tahan dulu keinginan belanjanya.'
      ],
    },
    'general': {
      AppTone.normal: [
        'Catat setiap rupiah yang keluar.',
        'Jangan lupa bayar tagihan tepat waktu.',
        'Dana darurat itu wajib punya.'
      ],
      AppTone.genZ: [
        'Investasi dari sekarang biar cepet pensiun.',
        'Pilih butuh apa cuma pengen?',
        'No money, no party? Gak juga.'
      ],
      AppTone.milenial: [
        'Passive income lebih penting dari gaya.',
        'Jangan lupa cek portofolio investasimu.',
        'Belajar bilang tidak pada diskon.'
      ],
      AppTone.boomer: [
        'Sedekah tidak mengurangi harta.',
        'Selalu bersyukur atas rezeki hari ini.',
        'Hidup sederhana itu mulia.'
      ],
      AppTone.pasangan: [
        'Ayo diskusiin budget bareng pasangan.',
        'Transparan soal uang bikin hubungan awet.',
        'Mimpi kita butuh tabungan yang kuat.'
      ],
    },
  };

  static String getSmartTip({
    required double todaySpent,
    required double monthlyBudget,
    required double totalMonthlySpent,
  }) {
    final tone = currentTone;
    final List<String> pool;

    if (monthlyBudget > 0 && totalMonthlySpent / monthlyBudget > 0.9) {
      pool =
          _smartTips['urgent']![tone] ?? _smartTips['urgent']![AppTone.normal]!;
    } else if (monthlyBudget > 0 && todaySpent > (monthlyBudget / 15)) {
      pool = _smartTips['overspending']![tone] ??
          _smartTips['overspending']![AppTone.normal]!;
    } else if (todaySpent == 0 && DateTime.now().hour > 12) {
      pool =
          _smartTips['saving']![tone] ?? _smartTips['saving']![AppTone.normal]!;
    } else {
      pool = _smartTips['general']![tone] ??
          _smartTips['general']![AppTone.normal]!;
    }

    final randomIdx =
        (DateTime.now().hour * 60 + DateTime.now().minute) % pool.length;
    return pool[randomIdx];
  }

  static String getRandomTip() {
    final tone = currentTone;
    final pool =
        _smartTips['general']![tone] ?? _smartTips['general']![AppTone.normal]!;
    return pool[DateTime.now().second % pool.length];
  }
}
