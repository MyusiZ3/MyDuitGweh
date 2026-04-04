
# ═══════════════════════════════════════════════════════════════════
#  🦅 EAGLE EYE — Admin Analytics Dashboard
#  Implementation Plan v2.0
#  Project: MyDuitGweh — Live Insights Upgrade
# ═══════════════════════════════════════════════════════════════════

## 📋 RINGKASAN PROYEK

Target: Mengubah layar `GlobalInsightsScreen` (Live Insights) dari dashboard
statistik sederhana menjadi pusat komando analitik "Eagle Eye" dengan
6 fitur baru, pemisahan hak akses Admin vs SuperAdmin, dan integrasi AI.

Status Saat Ini:
  - GlobalInsightsScreen: StatelessWidget dengan metrik dasar
  - Role system: sudah ada (user/admin/superadmin) via AuthService
  - fl_chart: sudah terinstall
  - AI service: sudah ada, API key dari app_settings/ai_config

---

## 🔐 HAK AKSES: ADMIN vs SUPERADMIN

Sistem role sudah tersedia di `AuthService`:
  - `isAdmin()` → true jika role == 'admin' ATAU 'superadmin'
  - `isSuperAdmin()` → true HANYA jika role == 'superadmin'

```
┌─────────────────────────────────────────┬───────────┬──────────────┐
│ FITUR                                   │   ADMIN   │  SUPERADMIN  │
├─────────────────────────────────────────┼───────────┼──────────────┤
│ Dashboard Metrics (existing)            │    ✅     │      ✅      │
│ Total Liquidity, User Count, dll        │           │              │
├─────────────────────────────────────────┼───────────┼──────────────┤
│ 📈 #1 Global Cash Flow Chart           │    ✅     │      ✅      │
│ Line chart Income vs Expense seluruh    │           │              │
│ user. Data agregat, tidak per-individu. │           │              │
│ ALASAN ADMIN OK: Data anonim/agregat.   │           │              │
├─────────────────────────────────────────┼───────────┼──────────────┤
│ 🏆 #2 Top Spending Categories          │    ✅     │      ✅      │
│ Pie Chart kategori pengeluaran          │           │              │
│ terpopuler seluruh platform.            │           │              │
│ ALASAN ADMIN OK: Data agregat kategori. │           │              │
├─────────────────────────────────────────┼───────────┼──────────────┤
│ 📅 #5 User Activity Heatmap            │    ✅     │      ✅      │
│ Hari & jam transaksi terpopuler.        │           │              │
│ ALASAN ADMIN OK: Data pola waktu,       │           │              │
│ tidak ada informasi personal.           │           │              │
├─────────────────────────────────────────┼───────────┼──────────────┤
│ 🆕 #6 New User Growth Chart            │    ✅     │      ✅      │
│ Grafik pendaftaran baru per minggu.     │           │              │
│ ALASAN ADMIN OK: Hanya jumlah, tanpa    │           │              │
│ identitas user.                         │           │              │
├─────────────────────────────────────────┼───────────┼──────────────┤
│ ⚠️ #3 Leaderboard (Nama + Nominal)     │    ❌     │      ✅      │
│ Top Earners & Big Spenders dengan       │ 🔒LOCKED │   UNLOCKED   │
│ nama asli user + total nominal.         │           │              │
│ ALASAN RESTRICTED: Data keuangan        │           │              │
│ individual user → sangat sensitif.      │           │              │
├─────────────────────────────────────────┼───────────┼──────────────┤
│ ⚠️ #4 AI Trend Analysis                │    ❌     │      ✅      │
│ Kirim data agregat ke Gemini/Groq       │ 🔒LOCKED │   UNLOCKED   │
│ untuk analisis tren otomatis.           │           │              │
│ ALASAN RESTRICTED: Setiap klik          │           │              │
│ MEMBAKAR kuota API Key yang mahal.      │           │              │
│ API Key diambil dari App Config         │           │              │
│ (app_settings/ai_config).               │           │              │
└─────────────────────────────────────────┴───────────┴──────────────┘
```

Logika Implementasi Lock:
```dart
// Di GlobalInsightsScreen, terima parameter:
final bool isSuperAdmin;

// Di widget build:
if (isSuperAdmin) {
  _buildLeaderboard();    // Tampil penuh
  _buildAIAnalysis();     // Tampil penuh
} else {
  _buildLockedSection(    // Card 🔒 "Akses Terbatas"
    title: 'Leaderboard',
    reason: 'Hanya SuperAdmin yang dapat melihat data keuangan per-user.'
  );
}
```

---

## 📊 DETAIL 6 FITUR

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### FASE 1: GRAFIK INTI (Admin + SuperAdmin)
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#### FITUR #1: 📈 Global Cash Flow Line Chart

```
AKSES  : Admin ✅ | SuperAdmin ✅
PACKAGE: fl_chart (sudah terinstall)
RISIKO : Rendah — data agregat anonim

DESKRIPSI:
  Line chart 2 garis menampilkan total Income (hijau) vs
  Expense (merah) SELURUH user, dikelompokkan per hari.
  Admin bisa langsung lihat: ekonomi user sedang surplus atau defisit?

DATA SOURCE:
  Collection: transactions (semua, tanpa filter wallet)
  Query baru di firestore_service.dart:

    Future<List<TransactionModel>> getGlobalTransactions({
      required DateTime startDate,
      required DateTime endDate,
    })

  Client-side processing:
    - Group by: tanggal (date field)
    - Sum: amount per hari, pisah berdasarkan type (income/expense)
    - Output: Map<DateTime, {income: double, expense: double}>

UI WIREFRAME:
  ┌─ Tren Keuangan Global ─────────────────┐
  │                                          │
  │  [ 7 Hari ] [ 30 Hari ] [ 6 Bulan ]   │  ← Toggle filter
  │                                          │
  │      ╱╲      ╱╲                         │
  │     ╱  ╲    ╱  ╲   ← Income (hijau)    │
  │    ╱    ╲  ╱    ╲                       │
  │ ──╱──────╲╱──────╲── Expense (merah)   │
  │                                          │
  │  Tooltip: "12 Mar — +Rp500K / -Rp300K" │
  └──────────────────────────────────────────┘

DETAIL UI:
  - 2 LineChartBarData: hijau gradient (income), merah gradient (expense)
  - Area fill di bawah garis: 10% opacity
  - Toggle chip: ChoiceChip (7d / 30d / 6m)
  - Tooltip on-tap: tanggal + income + expense
  - Empty state: "Belum ada data transaksi"
  - Loading: Shimmer placeholder berbentuk chart
```

#### FITUR #2: 🏆 Top Spending Categories (Pie Chart)

```
AKSES  : Admin ✅ | SuperAdmin ✅
PACKAGE: fl_chart (sudah terinstall)
RISIKO : Rendah — data agregat kategori

DESKRIPSI:
  Interactive Pie Chart menampilkan 5 kategori expense terpopuler
  di seluruh platform (Makanan, Transport, Belanja, dll).
  Admin langsung tahu kebiasaan belanja user secara kolektif.

DATA SOURCE:
  Reuse hasil query dari Fitur #1 (getGlobalTransactions)
  Client-side processing:
    - Filter: hanya type == 'expense'
    - Group by: category field
    - Sum: amount per kategori
    - Sort descending, ambil Top 5
    - Sisanya digabung ke "Lainnya"

UI WIREFRAME:
  ┌─ Distribusi Pengeluaran Platform ──────┐
  │                                          │
  │         ╭───────╮                       │
  │        ╱  40%    ╲    Makanan           │
  │       │   Total   │   Transport         │
  │       │  Rp 12jt  │   Belanja           │
  │        ╲  28%    ╱    Tagihan           │
  │         ╰───────╯    Lainnya            │
  │                                          │
  │  🍔 Makanan      40%   Rp 4.800.000    │
  │  🚗 Transport    25%   Rp 3.000.000    │
  │  🛍️ Belanja      15%   Rp 1.800.000    │
  │  📱 Tagihan      12%   Rp 1.440.000    │
  │  📦 Lainnya       8%   Rp   960.000    │
  └──────────────────────────────────────────┘

DETAIL UI:
  - PieChart dari fl_chart
  - Center label: "Total Pengeluaran" + formatted amount
  - On-tap section: highlight + tampilkan nama kategori
  - Legend di bawah chart: ikon + nama + persen + nominal
  - Ikon dari TransactionCategory.getIconForCategory() (sudah ada)
  - Warna: primary, purple, orange, red, teal, grey
```

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### FASE 2: SENSITIF — SUPERADMIN ONLY (🔒)
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#### FITUR #3: 💰 Top Earners & Big Spenders Leaderboard

```
AKSES  : Admin ❌ LOCKED | SuperAdmin ✅
PACKAGE: Tidak perlu package baru
RISIKO : TINGGI — menampilkan data finansial per-individu

ALASAN SUPERADMIN ONLY:
  Menampilkan NAMA ASLI user + total nominal keuangan personal.
  Ini data sangat sensitif. Hanya SuperAdmin (Owner) yang boleh
  mengakses informasi finansial individual user.

DESKRIPSI:
  Daftar 5 user pengeluaran terbesar dan 5 user penghasilan
  terbesar BULAN INI. Nama asli ditampilkan langsung (bukan inisial)
  karena ini layar SuperAdmin-only.

DATA SOURCE:
  Reuse hasil query getGlobalTransactions (bulan ini)
  Client-side processing:
    - Group by: createdBy (UID)
    - Sum: amount per UID, pisah income dan expense
    - Sort descending per kategori
    - Ambil Top 5 per tab
    - Cross-reference UID ke users/{uid} untuk displayName

UI WIREFRAME:
  ┌─ 🔒 LEADERBOARD ──────────────────────┐
  │                                          │
  │  [🔥 Big Spenders]  [💰 Top Earners]  │  ← Tab toggle
  │                                          │
  │  🥇  Muhammad Rizky       Rp 5.200.000 │
  │  🥈  Siti Aisyah          Rp 3.800.000 │
  │  🥉  Budi Santoso         Rp 2.100.000 │
  │  4.  Dewi Lestari         Rp 1.500.000 │
  │  5.  Ahmad Fauzi          Rp   900.000 │
  │                                          │
  │  ⚠️ Data ini bersifat rahasia          │
  └──────────────────────────────────────────┘

ADMIN MELIHAT:
  ┌─ 🔒 LEADERBOARD ──────────────────────┐
  │                                          │
  │        🔒 Akses Terbatas               │
  │                                          │
  │  Fitur ini hanya tersedia untuk         │
  │  SuperAdmin/Owner. Data keuangan        │
  │  individual user bersifat rahasia.      │
  │                                          │
  └──────────────────────────────────────────┘

DETAIL:
  - Tab: DefaultTabController + TabBar
  - List: ListView.builder, 5 item per tab
  - Badge: 🥇🥈🥉 untuk Top 3
  - Avatar: CircleAvatar dengan inisial nama + warna random
  - Nama: displayName langsung (bukan inisial/samaran)
  - Nominal: CurrencyFormatter.formatCurrency()
```

#### FITUR #4: 🤖 AI Trend Analysis

```
AKSES  : Admin ❌ LOCKED | SuperAdmin ✅
PACKAGE: google_generative_ai + http (sudah terinstall)
RISIKO : TINGGI — membakar kuota API Key setiap klik

ALASAN SUPERADMIN ONLY:
  Setiap kali tombol "Analisis AI" ditekan, akan MEMBAKAR kuota
  API Key Gemini/Groq. Ini biaya nyata. Hanya SuperAdmin yang
  boleh memicu pengeluaran API.

API KEY SOURCE:
  Diambil dari: app_settings/ai_config (Firestore)
  Field: gemini_keys[] / groq_keys[]
  Method: AIService.getIntegratedApiKeysAsync()
  → Sama persis dengan API key yang diinput lewat menu App Config
  → TIDAK ada API key baru yang diperlukan

DESKRIPSI:
  Tombol yang mengumpulkan semua data agregat platform, mengirimnya
  ke Gemini/Groq, dan menampilkan ringkasan tren dalam bahasa
  manusia berformat Markdown.

DATA YANG DIKUMPULKAN & DIKIRIM KE AI:
  {
    total_income_bulan_ini: Rp 45.000.000,
    total_expense_bulan_ini: Rp 38.000.000,
    rasio_surplus_defisit: +18.4%,
    top_3_kategori_expense: ["Makanan (40%)", "Transport (25%)", "Belanja (15%)"],
    jumlah_user_aktif: 127,
    rata_rata_saldo_wallet: Rp 850.000,
    user_baru_bulan_ini: 12,
    total_wallets_aktif: 89,
    hari_paling_aktif: "Senin, 12:00-18:00"
  }

SYSTEM PROMPT:
  """
  Kamu adalah "Archen Analytics", analis ekonomi internal untuk
  platform keuangan MyDuitGweh. Analisis data agregat berikut dan berikan
  insight singkat (WAJIB Markdown, max 150 kata, Bahasa Indonesia):

  [DATA AGREGAT]

  Format jawaban:
  ## 📊 Ringkasan Tren
  [1 paragraf]

  ## ⚠️ Anomali Terdeteksi
  [poin-poin jika ada, atau "Tidak ada anomali signifikan"]

  ## 💡 Rekomendasi untuk Admin
  [2-3 poin aksi konkret yang bisa dilakukan admin]
  """

UI WIREFRAME:
  ┌─ 🤖 Analisis Tren AI ─────────────────┐
  │                                          │
  │  ┌────────────────────────────────────┐ │
  │  │  ## 📊 Ringkasan Tren             │ │
  │  │  Pengeluaran bulan ini naik 15%    │ │
  │  │  didominasi kategori Makanan...    │ │
  │  │                                    │ │
  │  │  ## ⚠️ Anomali Terdeteksi         │ │
  │  │  • User spending 300% di atas...   │ │
  │  │                                    │ │
  │  │  ## 💡 Rekomendasi Admin          │ │
  │  │  1. Kirim broadcast tips hemat..   │ │
  │  │  2. Cek user dengan spending...    │ │
  │  └────────────────────────────────────┘ │
  │                                          │
  │  [🔄 Analisis Ulang]  Powered by AI ✨ │
  └──────────────────────────────────────────┘

DETAIL:
  - Tombol trigger: ElevatedButton gradient (biru→ungu)
  - Loading: Shimmer card + "Archen sedang menganalisis..."
  - Hasil: Markdown rendered via flutter_markdown
  - Card: border gradient (biru→ungu) + ikon AI
  - Refresh: tombol "🔄 Analisis Ulang" — debounce 30 detik
  - Cache: hasil tersimpan di memory (hilang saat keluar layar)
  - Error handling: fallback ke "Gagal menganalisis. Coba lagi."
```

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### FASE 3: DEEP ANALYTICS (Admin + SuperAdmin)
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#### FITUR #5: 📅 User Activity Heatmap

```
AKSES  : Admin ✅ | SuperAdmin ✅
PACKAGE: Tidak perlu package baru (custom widget)
RISIKO : Rendah — data pola waktu agregat

DESKRIPSI:
  Grid visual menunjukkan kapan user paling aktif bertransaksi
  selama 30 hari terakhir. Berguna untuk menentukan waktu terbaik
  kirim Broadcast/Notifikasi ke user.

DATA SOURCE:
  Reuse hasil query getGlobalTransactions (30 hari)
  Client-side processing:
    - Extract dayOfWeek (1=Senin..7=Minggu) dari date field
    - Extract hourOfDay (0-23) dari date field
    - Bucket jam ke 4 slot: Pagi(06-12), Siang(12-17), Sore(17-21), Malam(21-06)
    - Count transaksi per sel
    - Normalisasi 0-1 untuk intensitas warna

UI WIREFRAME:
  ┌─ Aktivitas User ───────────────────────┐
  │                                          │
  │  🔥 Peak Activity: Senin Siang (12-17) │
  │                                          │
  │         Pagi    Siang    Sore    Malam  │
  │  Sen    ██▓▓    ████     ██░░    ░░░░   │
  │  Sel    ██░░    ██▓▓     ████    ░░░░   │
  │  Rab    ░░░░    ██░░     ██░░    ░░░░   │
  │  Kam    ██░░    ██▓▓     ██░░    ░░░░   │
  │  Jum    ██▓▓    ████     ██▓▓    ██░░   │
  │  Sab    ░░░░    ██░░     ██▓▓    ░░░░   │
  │  Min    ░░░░    ░░░░     ░░░░    ░░░░   │
  │                                          │
  │  ░ Rendah  ▓ Sedang  █ Tinggi          │
  └──────────────────────────────────────────┘

DETAIL:
  - Widget: GridView.builder, 7 rows × 4 columns
  - Cell: Container dengan BorderRadius(8)
  - Heat gradient: Colors.grey[100] → Colors.amber → Colors.deepOrange
  - Header: teks otomatis menentukan peak berdasarkan count tertinggi
  - Legend: row di bawah grid
```

#### FITUR #6: 🆕 New User Growth Chart

```
AKSES  : Admin ✅ | SuperAdmin ✅
PACKAGE: fl_chart (sudah terinstall)
RISIKO : Rendah — hanya jumlah, tanpa identitas

DESKRIPSI:
  Bar chart menunjukkan jumlah pendaftaran user baru per minggu
  selama 8 minggu terakhir. Menggantikan estimasi statis
  yang saat ini hardcoded sebagai `userCount * 0.05`.

DATA SOURCE:
  Query baru di firestore_service.dart:

    Future<List<Map<String, dynamic>>> getUserRegistrations({
      required int daysBack,
    })

  Client-side processing:
    - Group by: minggu (week number dari createdAt)
    - Count: jumlah user per minggu
    - Output: List<{week: String, count: int}>

UI WIREFRAME:
  ┌─ Pertumbuhan User Baru ────────────────┐
  │                                          │
  │  Total: 42 user baru (8 minggu)        │
  │                                          │
  │        ┌──┐                              │
  │  ┌──┐  │  │  ┌──┐  ┌──┐                │
  │  │  │  │  │  │  │  │██│  ┌──┐          │
  │  │░░│  │██│  │▓▓│  │██│  │██│          │
  │  │░░│  │██│  │▓▓│  │██│  │██│  ┌──┐   │
  │  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘   │
  │  W1    W2    W3    W4    W5    W6      │
  │                                          │
  └──────────────────────────────────────────┘

DETAIL:
  - BarChart dari fl_chart
  - 8 bars, label X: "W1"..."W8" (terbaru di kanan)
  - Warna: gradient dari Colors.indigo[200] → Colors.indigo[600]
  - Tooltip on-tap: "Minggu 3 — 8 user baru"
  - Header: "Total User Baru (8 Minggu): XX"
  - Fallback: jika user.createdAt == null, skip (user lama pra-migrasi)
```

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### FASE 4: USER VOICE & AI INSIGHTS (Survei Feedback)
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#### FITUR #7: 📝 In-App User Feedback System

```
AKSES  : User (Mengisi) | Admin ✅ | SuperAdmin ✅ (Melihat)
PACKAGE: Tidak perlu package baru
RISIKO : Rendah — meningkatkan interaksi user

DESKRIPSI:
  Sistem feedback internal untuk menggantikan Google Form. 
  Memungkinkan user memberikan rating (bintang) dan saran fitur 
  langsung dari dalam aplikasi.

DATA SOURCE (Firestore):
  Collection: user_feedbacks/{feedbackId}
  Schema:
    {
      userId: "UID",
      rating: 4,                  // 1-5 Bintang
      category: "Performance",    // UI, Fitur, Bug, Performa
      comment: "Aplikasi agak lag pas buka riwayat",
      appVersion: "1.2.0",
      deviceInfo: "Android 13, Samsung S22",
      createdAt: Timestamp
    }

TRIGGER SURVEI (Logic):
  - User sudah login > 3 hari.
  - Sudah melakukan > 10 transaksi (High engagement user).
  - Tampilkan 1x saja (save flag di `users/surveyDone: true`).

UI WIREFRAME (User Side):
  ┌─ Bagaimana Pengalaman Anda? ──────────┐
  │                                          │
  │      ⭐ ⭐ ⭐ ⭐ ✩                       │
  │   [ Puas dengan MyDuitGweh? ]            │
  │                                          │
  │  Kategori: [ Performance ▾ ]             │
  │  [ Kotak saran fitur/keluhan...    ]     │
  │                                          │
  │  [ KIRIM FEEDBACK ]                      │
  └──────────────────────────────────────────┘
```

#### FITUR #8: 🧠 AI Sentiment Aggregator (Admin Only)

```
AKSES  : Admin ❌ LOCKED | SuperAdmin ✅
PACKAGE: google_generative_ai (Reuse)

DESKRIPSI:
  Tombol "Analisis Suara User" di dashboard Eagle Eye. 
  AI akan merangkum RATUSAN feedback user menjadi 3 poin ringkas:
  1. Masalah utama yang paling banyak dikeluhkan.
  2. Fitur yang paling banyak diminta.
  3. Skor sentimen rata-rata (Positif/Negatif).

PROMPT AI:
  """
  Berikut adalah daftar feedback dari user MyDuitGweh:
  [LIST FEEDBACK]
  
  Tugasmu:
  1. Rangkum sentimen umum user.
  2. Identifikasi 3 masalah performa/UI paling sering muncul.
  3. Beri rekomendasi prioritas fitur yang harus didevelop selanjutnya.
  """

UI (Admin Dashboard):
  ┌─ 🧠 AI Sentiment Analysis ────────────┐
  │                                          │
  │  😊 Sentimen Umum: 85% Positif           │
  │  • User mengeluhkan loading awal...      │
  │  • Keinginan fitur scan struk AI tinggi..│
  │                                          │
  │  [ 🤖 Jalankan Analisis AI ]             │
  └──────────────────────────────────────────┘
```

---

## 🏗️ ARSITEKTUR TEKNIS

### Sumber Data (Sudah Ada di Firestore)
```
Firestore
├── users/{userId}
│   ├── displayName      ← Untuk leaderboard (nama asli)
│   ├── email
│   ├── role             ← "user" | "admin" | "superadmin"
│   └── createdAt        ← Untuk growth chart
│
├── wallets/{walletId}
│   ├── balance          ← Sudah dipakai metrik existing
│   ├── members[]
│   └── type
│
├── transactions/{txId}
│   ├── walletId
│   ├── amount           ← Untuk chart + pie + leaderboard
│   ├── type             ← "income" | "expense"
│   ├── category         ← Untuk pie chart
│   ├── createdBy        ← UID, untuk leaderboard
│   ├── createdByName    ← Nama, backup untuk leaderboard
│   └── date             ← Timestamp, untuk semua chart
│
└── app_settings/
    └── ai_config
        ├── gemini_keys[]  ← API key untuk AI analysis
        ├── groq_keys[]    ← Fallback API key
        └── is_ai_enabled  ← Kill switch
```

### Method Baru di firestore_service.dart
```dart
// 1. Query SEMUA transaksi global (tanpa filter wallet)
Future<List<TransactionModel>> getGlobalTransactions({
  required DateTime startDate,
  required DateTime endDate,
}) async {
  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
  final snap = await _firestore
      .collection('transactions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
      .orderBy('date', descending: true)
      .limit(2000)  // Safety limit
      .get();
  return snap.docs
      .map((doc) => TransactionModel.fromJson(doc.data(), docId: doc.id))
      .toList();
}

// 2. Query registrasi user baru
Future<List<Map<String, dynamic>>> getUserRegistrations({
  required int daysBack,
}) async {
  final cutoff = DateTime.now().subtract(Duration(days: daysBack));
  final snap = await _firestore
      .collection('users')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
      .orderBy('createdAt')
      .get();
  return snap.docs.map((doc) {
    final data = doc.data();
    data['uid'] = doc.id;
    return data;
  }).toList();
}
```

---

## 📐 STRUKTUR UI LAYAR BARU (Scroll Order)

```
┌─────────────────────────────────────────────┐
│         LIVE INSIGHTS                        │
│      REAL-TIME SYSTEM MONITOR                │
├─────────────────────────────────────────────┤
│                                              │
│  [1] Total System Liquidity         EXISTING │
│  [2] Metrics Row (Users, Growth,    EXISTING │
│      Avg Wallet, Active Wallets)             │
│                                              │
│  ═══ BARU MULAI DARI SINI ══════════════   │
│                                              │
│  [3] Period Filter Toggle            NEW #0  │
│      [ 7 Hari ] [ 30 Hari ] [ 6 Bulan ]    │
│                                              │
│  [4] 📈 Global Cash Flow Chart      NEW #1  │
│      Line chart Income vs Expense            │
│      Admin ✅ | SuperAdmin ✅               │
│                                              │
│  [5] 🏆 Top Spending Categories     NEW #2  │
│      Pie chart 5 kategori terpopuler         │
│      Admin ✅ | SuperAdmin ✅               │
│                                              │
│  [6] 📅 User Activity Heatmap       NEW #5  │
│      Grid intensitas waktu                   │
│      Admin ✅ | SuperAdmin ✅               │
│                                              │
│  [7] 🆕 New User Growth Chart       NEW #6  │
│      Bar chart pendaftaran baru              │
│      Admin ✅ | SuperAdmin ✅               │
│                                              │
│  ═══ ZONA SUPERADMIN ONLY ══════════════   │
│                                              │
│  [8] 💰 Leaderboard                 NEW #3  │
│      Big Spenders + Top Earners              │
│      Admin ❌ | SuperAdmin ✅               │
│                                              │
│  [9] 🤖 AI Trend Analysis           NEW #4  │
│      Analisis tren oleh Gemini/Groq          │
│      Admin ❌ | SuperAdmin ✅               │
│                                              │
│  [10] Economy Health Index          EXISTING │
│       (akan di-update jadi dynamic)          │
│                                              │
└─────────────────────────────────────────────┘
```

---

## 📁 FILE YANG DIMODIFIKASI

```
MODIFY  lib/services/firestore_service.dart
        + getGlobalTransactions()
        + getUserRegistrations()

MODIFY  lib/screens/admin/global_insights_screen.dart
        ~ StatelessWidget → StatefulWidget
        ~ Tambah constructor parameter: isSuperAdmin (bool)
        + _buildPeriodFilter()         → Toggle 7d / 30d / 6m
        + _buildCashFlowChart()        → Line chart (Fitur #1)
        + _buildCategoryPieChart()     → Pie chart (Fitur #2)
        + _buildLeaderboard()          → Tab spenders/earners (Fitur #3) 🔒
        + _buildAIAnalysis()           → Card AI trend (Fitur #4) 🔒
        + _buildActivityHeatmap()      → Grid heatmap (Fitur #5)
        + _buildUserGrowthChart()      → Bar chart (Fitur #6)
        + _buildLockedSection()        → Widget 🔒 untuk admin non-super

MODIFY  lib/screens/admin/admin_tools_screen.dart
        ~ Navigasi ke GlobalInsightsScreen → kirim isSuperAdmin
        BEFORE: builder: (_) => GlobalInsightsScreen()
        AFTER:  builder: (_) => GlobalInsightsScreen(isSuperAdmin: _isSuperAdmin)

MODIFY  lib/screens/admin/admin_dashboard_screen.dart
        ~ Sama — kirim parameter isSuperAdmin

MODIFY  firestore.rules (opsional, bisa sekarang atau nanti)
        ~ Perketat transactions agar hanya admin read semua
```

---

## ⚙️ DEPENDENSI

```
SUDAH TERINSTALL (Tidak perlu tambah package baru):
  ✅ fl_chart               → Line Chart, Pie Chart, Bar Chart
  ✅ flutter_markdown        → Render hasil AI Analysis
  ✅ cloud_firestore         → Query data
  ✅ intl                    → Format tanggal & currency
  ✅ http                    → API call ke Groq
  ✅ google_generative_ai    → API call ke Gemini

TOTAL PACKAGE BARU: 0 (nol)
```

---

## 🚀 FASE EKSEKUSI

```
FASE 1 — Foundation Charts (Admin + SuperAdmin OK)
  Estimasi: ~1 session
  ┌───┬─────────────────────────────────────────────────┐
  │ 1 │ Refactor GlobalInsightsScreen → StatefulWidget  │
  │   │ + terima parameter isSuperAdmin                 │
  ├───┼─────────────────────────────────────────────────┤
  │ 2 │ Tambah getGlobalTransactions() ke               │
  │   │ firestore_service.dart                          │
  ├───┼─────────────────────────────────────────────────┤
  │ 3 │ Build Period Filter Toggle (7d / 30d / 6m)     │
  ├───┼─────────────────────────────────────────────────┤
  │ 4 │ Build Global Cash Flow Line Chart (Fitur #1)   │
  ├───┼─────────────────────────────────────────────────┤
  │ 5 │ Build Top Spending Categories Pie (Fitur #2)   │
  ├───┼─────────────────────────────────────────────────┤
  │ 6 │ Update navigasi di admin_tools_screen.dart &    │
  │   │ admin_dashboard_screen.dart                     │
  └───┴─────────────────────────────────────────────────┘

FASE 2 — SuperAdmin Zone (🔒 Restricted)
  Estimasi: ~1 session
  ┌───┬─────────────────────────────────────────────────┐
  │ 7 │ Build _buildLockedSection() untuk admin biasa   │
  ├───┼─────────────────────────────────────────────────┤
  │ 8 │ Build Leaderboard + tab toggle (Fitur #3)       │
  ├───┼─────────────────────────────────────────────────┤
  │ 9 │ Build AI Trend Analysis + integrasi AIService   │
  │   │ (Fitur #4) — API dari App Config                │
  ├───┼─────────────────────────────────────────────────┤
  │10 │ Tambah getUserRegistrations() ke                │
  │   │ firestore_service.dart                          │
  └───┴─────────────────────────────────────────────────┘

FASE 3 — Deep Analytics (Admin + SuperAdmin)
  Estimasi: ~1 session
  ┌───┬─────────────────────────────────────────────────┐
  │11 │ Build User Activity Heatmap (Fitur #5)         │
  ├───┼─────────────────────────────────────────────────┤
  │12 │ Build New User Growth Bar Chart (Fitur #6)     │
  ├───┼─────────────────────────────────────────────────┤
  │13 │ Update Economy Health Index → dynamic           │
  │   │ (bukan lagi hardcoded)                          │
  ├───┼─────────────────────────────────────────────────┤
  │14 │ Update firestore.rules (opsional)               │
  ├───┼─────────────────────────────────────────────────┤
  │15 │ Polish, testing, & optimasi performa scroll     │
  └───┴─────────────────────────────────────────────────┘

FASE 4 — User Voice & AI Insights (Feedback In-App)
  Estimasi: ~1 session
  ┌───┬─────────────────────────────────────────────────┐
  │16 │ Create FeedbackModel & submitFeedback()         │
  ├───┼─────────────────────────────────────────────────┤
  │17 │ Build ExperienceSurveySheet (Bottom Sheet)      │
  ├───┼─────────────────────────────────────────────────┤
  │18 │ Logika Trigger Survey (New User / High Use)     │
  ├───┼─────────────────────────────────────────────────┤
  │19 │ Build Admin Feedback Monitor di Eagle Eye       │
  ├───┼─────────────────────────────────────────────────┤
  │20 │ Build "AI Sentiment Aggregator" (Summarizer)    │
  └───┴─────────────────────────────────────────────────┘
```

---

## ⚠️ RISIKO & MITIGASI

```
┌──────────────────────────────┬──────────────────────────────────────┐
│ RISIKO                       │ MITIGASI                             │
├──────────────────────────────┼──────────────────────────────────────┤
│ Query transaksi global bisa  │ Limit query ke 2000 docs.            │
│ lambat jika data ribuan.     │ Loading shimmer. Pagination nanti.   │
├──────────────────────────────┼──────────────────────────────────────┤
│ AI Analysis membakar kuota   │ SuperAdmin only. Cache di memory.    │
│ API Key.                     │ Debounce tombol 30 detik.            │
├──────────────────────────────┼──────────────────────────────────────┤
│ Layar terlalu panjang jika   │ Lazy loading per section.            │
│ semua fitur dimuat sekaligus.│ Load data saat scroll mendekati.     │
├──────────────────────────────┼──────────────────────────────────────┤
│ createdAt null untuk user    │ Fallback: skip user tanpa createdAt  │
│ lama (pra-migrasi).          │ dari growth chart. Tidak crash.      │
├──────────────────────────────┼──────────────────────────────────────┤
│ Admin biasa bisa lihat data  │ Gunakan _buildLockedSection() yang   │
│ sensitif lewat Firestore     │ menampilkan card 🔒 dengan alasan    │
│ direct query.                │ jelas. Rules optional diperkuat.     │
└──────────────────────────────┴──────────────────────────────────────┘
```

---

## ✅ VERIFICATION PLAN

### Build Verification
  - flutter build apk --debug → No compile error
  - flutter analyze → No critical warnings

### Manual Testing
  1. Login sebagai ADMIN → buka Live Insights
     → Verifikasi: Chart #1, #2, #5, #6 tampil ✅
     → Verifikasi: Leaderboard #3 & AI #4 → 🔒 Locked card ✅
  2. Login sebagai SUPERADMIN → buka Live Insights
     → Verifikasi: SEMUA 6 fitur tampil ✅
     → Verifikasi: Leaderboard tampil nama asli + nominal ✅
     → Verifikasi: AI Analysis → klik → loading → hasil muncul ✅
  3. Toggle filter 7d/30d/6m → chart berubah sesuai periode ✅
  4. Test di HP real (flutter run) → scroll halus, tidak lag ✅

---

Dokumen ini dibuat untuk proyek MyDuitGweh.
Versi: 2.0 | Tanggal: 2026-04-04
