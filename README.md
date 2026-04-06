<p align="center">
  <img src="assets/images/logo_app.png" alt="MyDuitGweh Logo" width="120" />
</p>

<h1 align="center">💰 MyDuitGweh</h1>

<p align="center">
  <strong>Smart Financial Tracker — Kelola keuangan dengan cerdas, kolaboratif, dan menyenangkan.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.6+-02569B?logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.6+-0175C2?logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" />
  <img src="https://img.shields.io/badge/License-Private-red" />
</p>

---

## 📖 Deskripsi

**MyDuitGweh** adalah aplikasi pencatatan keuangan pribadi berbasis Flutter yang dirancang untuk membantu pengguna mengelola pemasukan, pengeluaran, dan dompet secara real-time dengan antarmuka yang premium dan intuitif. Dilengkapi dengan AI Financial Advisor, sistem kolaborasi dompet bersama, scanner struk otomatis, dan kepribadian aplikasi yang dapat diubah sesuai gaya pengguna.

Dibangun di atas ekosistem **Firebase** (Authentication, Firestore, Hosting, Storage) dengan desain terinspirasi **iOS/Apple Design Language** — glassmorphism, smooth animations, dan Bento Card layout.

---

## ✨ Fitur Utama

### 🏠 Dashboard Beranda
- **Ringkasan Saldo Real-Time** — Total saldo, pemasukan, dan pengeluaran terupdate secara live dari Firestore.
- **Grafik Cepat** — Visualisasi pengeluaran harian dengan chart interaktif.
- **Riwayat Transaksi Terkini** — Daftar transaksi terbaru dengan swipe-to-delete.
- **Smart Greeting** — Sapaan dinamis berdasarkan waktu dan gaya bahasa yang dipilih.
- **Budget Alert** — Notifikasi jika pengeluaran mendekati atau melebihi batas anggaran bulanan.
- **Broadcast Center** — Pengumuman real-time dari admin langsung di dashboard.

### 💼 Manajemen Dompet
- **Multi-Wallet** — Buat dan kelola dompet tanpa batas (Pribadi, Bisnis, Tabungan, dll).
- **Tipe Dompet**: Solo, Kolaborasi (Colab), atau Tabungan.
- **Pencarian & Filter** — Cari dompet dengan search bar dan filter berdasarkan tipe.
- **Riwayat Transaksi Per Dompet** — Lihat seluruh riwayat transaksi berdasarkan dompet tertentu.
- **Undang Anggota** — Tambahkan teman lewat email untuk dompet kolaborasi.

### 📊 Laporan & Analitik
- **Pie Chart Interaktif** — Kategori pengeluaran divisualisasikan dalam chart yang bisa di-tap.
- **Tren Mingguan** — Grafik tren pengeluaran per minggu.
- **Filter Tanggal** — Pilih periode laporan keuangan dengan Date Range Picker.
- **Export PDF** — Download laporan keuangan dalam format PDF siap cetak.

### 🤖 Archen AI — Financial Advisor
- **Chat AI Interaktif** — Tanya jawab seputar kondisi keuangan secara real-time.
- **Multi-Platform AI** — Mendukung Gemini API dan Groq API.
- **Multi-Key Management** — Simpan dan kelola beberapa API Key sekaligus, dengan validasi status (OK/Limit/Invalid).
- **Kuota Gratis** — Integrated API keys dari server untuk pengguna tanpa API key pribadi.
- **Quota System** — Pembatasan penggunaan per jam (konfigurable oleh admin).
- **5 Mode Kepribadian** — Normal, Gen Z, Milenial, Boomer, dan Pasangan — masing-masing dengan gaya respon unik.
- **Multi-Session Chat** — Simpan banyak sesi chat dengan AI, lanjutkan kapan saja.

### 📸 Receipt Scanner (Scan Struk)
- **Kamera Custom** — Antarmuka kamera full-screen dengan scanner overlay futuristik (HUD corners, scan line animation).
- **OCR Recognition** — Ekstrak otomatis nominal, merchant, dan tanggal dari foto struk menggunakan Google ML Kit.
- **AI Mode** — Opsi analisis AI untuk mengenali struk yang lebih kompleks (membutuhkan API Key).
- **Galeri Support** — Pilih foto dari galeri sebagai alternatif.
- **Tap to Focus** — Ketuk layar untuk fokus ke area tertentu.

### 👥 Kolaborasi Dompet
- **Shared Wallet** — Dompet bersama untuk patungan, arisan, atau keuangan pasangan.
- **Chat Room Per Dompet** — Fitur chat real-time antar anggota dompet.
- **Notifikasi Unread** — Badge jumlah pesan belum dibaca di setiap dompet.
- **Member Management** — Owner dapat mengundang anggota baru atau mengeluarkan anggota.
- **Hak Akses** — Hanya kreator transaksi yang bisa menghapus transaksinya sendiri.

### 🔔 Sistem Notifikasi
- **Pengingat Jurnal Harian** — Pengingat otomatis untuk mencatat keuangan di waktu tertentu (konfigurable).
- **Push Notification** — Notifikasi lokal dengan prioritas tinggi (heads-up).
- **Auto-Magic Sync (Experimental)** — Pencatatan otomatis dari notifikasi keuangan (m-banking, e-wallet, dll).
  - Fitur ini memerlukan izin **Notification Listener Access**.
  - Notifikasi dari aplikasi keuangan diproses dan dideteksi secara otomatis.
  - Data transaksi hasil capture disimpan secara lokal dan bisa disinkronisasikan.

### 🔄 Update In-App
- **Deteksi Update Real-Time** — Sistem cek otomatis dari Firestore saat membuka aplikasi.
- **Manual Check** — Pengguna bisa cek update manual dari menu **About App**.
- **Download & Install Langsung** — APK terbaru didownload langsung dari server dan diinstal dari dalam aplikasi.
- **Force Update** — Admin dapat memaksa update untuk user yang menggunakan versi terlalu lama.
- **Progress Download** — Progress bar real-time saat proses download berlangsung.

### 🎨 Kepribadian Aplikasi (Tone System)
Seluruh teks UI berubah otomatis berdasarkan gaya bahasa yang dipilih:

| Mode | Deskripsi | Contoh Sapaan |
|------|-----------|---------------|
| 🔵 **Normal** | Formal & profesional | "Selamat Pagi" |
| 🟢 **Gen Z** | Slang, asik, frontal | "Pagi Skid" |
| 🟡 **Milenial** | Santai, campur Inggris | "Morning vibes" |
| 🟠 **Boomer** | Sopan, bijaksana | "Selamat Pagi" |
| 🩷 **Pasangan** | Romantis & mesra | "Meowniing ^_^" |

### 🛡️ Keamanan
- **Biometric Lock** — Kunci aplikasi dengan sidik jari atau Face ID.
- **Root/Jailbreak Detection** — Blokir akses dari perangkat yang di-root.
- **Firestore Security Rules** — Role-based access control (User, Admin, SuperAdmin).
- **Account Suspension** — Admin dapat menangguhkan akun pengguna.
- **Maintenance Mode** — Mode maintenance yang bisa diaktifkan dari server.

### 🔧 Admin Panel
Panel administrasi lengkap yang hanya dapat diakses oleh admin:
- **Dashboard** — Statistik pengguna, transaksi, dan dompet secara real-time.
- **User Management** — Kelola, suspend, atau ubah role pengguna.
- **App Config** — Konfigurasi global (versi, maintenance mode, force update, download URL).
- **AI Config** — Kelola API keys terintegrasi dan batas kuota AI.
- **Broadcast Center** — Kirim pengumuman ke seluruh pengguna.
- **Admin Logs** — Pantau semua aktivitas perubahan konfigurasi.
- **Global Insights** — Analisis tren penggunaan aplikasi secara agregat.
- **AI Trend Analysis** — Analisis tren berbasis AI dari data pengguna.
- **Notification Listener Config** — Konfigurasi fitur Auto-Magic Sync.

---

## 🏗️ Arsitektur Project

```
lib/
├── main.dart                          # Entry point & Firebase init
├── firebase_options.dart              # Auto-generated Firebase config
│
├── models/                            # Data Models
│   ├── transaction_model.dart         # Model Transaksi + Kategori
│   ├── wallet_model.dart              # Model Dompet
│   ├── user_model.dart                # Model User
│   ├── chat_message_model.dart        # Model Chat
│   ├── feedback_model.dart            # Model Feedback/Survey
│   └── survey_config_model.dart       # Model Konfigurasi Survey
│
├── screens/                           # UI Screens
│   ├── onboarding_screen.dart         # Onboarding flow
│   ├── login_screen.dart              # Login & Register
│   ├── main_nav.dart                  # Bottom Navigation Hub
│   ├── home_screen.dart               # Dashboard Beranda
│   ├── wallet_screen.dart             # Manajemen Dompet
│   ├── colab_screen.dart              # Dompet Kolaborasi
│   ├── report_screen.dart             # Laporan & AI Advisor
│   ├── add_transaction_screen.dart    # Form Tambah Transaksi
│   ├── receipt_scanner_screen.dart    # Scanner Struk
│   ├── wallet_chat_screen.dart        # Chat Dompet Kolaborasi
│   ├── notifications_screen.dart      # Pusat Notifikasi
│   ├── edit_profile_screen.dart       # Edit Profil
│   ├── about_screen.dart              # Tentang Aplikasi
│   ├── help_screen.dart               # Pusat Bantuan
│   ├── security_gate_screen.dart      # Gate Biometric
│   ├── maintenance_gate_screen.dart   # Gate Maintenance
│   ├── suspension_gate_screen.dart    # Gate Suspended Account
│   └── admin/                         # Admin Panel
│       ├── admin_dashboard_screen.dart
│       ├── admin_tools_screen.dart
│       ├── admin_logs_screen.dart
│       ├── app_config_screen.dart
│       ├── user_management_screen.dart
│       ├── broadcast_center_screen.dart
│       ├── global_insights_screen.dart
│       ├── ai_trend_analysis_screen.dart
│       └── notification_listener_admin_screen.dart
│
├── services/                          # Business Logic & APIs
│   ├── auth_service.dart              # Firebase Auth
│   ├── firestore_service.dart         # Firestore CRUD
│   ├── ai_service.dart                # Gemini & Groq AI
│   ├── notification_service.dart      # Local Notifications
│   ├── notif_listener_bridge.dart     # Notification Listener Bridge
│   ├── notif_local_db_service.dart    # SQLite untuk notif capture
│   ├── notif_recognition_service.dart # Parsing data dari notifikasi
│   ├── notif_sync_service.dart        # Background sync notifikasi
│   ├── pdf_service.dart               # PDF Export
│   ├── receipt_ocr_service.dart       # OCR Processing
│   ├── security_service.dart          # Biometric & Root Detection
│   └── update_service.dart            # In-App Update System
│
├── utils/                             # Utilities
│   ├── app_theme.dart                 # Design System & Colors
│   ├── currency_formatter.dart        # Format mata uang IDR
│   ├── debouncer.dart                 # Throttle/Debounce utility
│   ├── tone_dictionary.dart           # Sistem kepribadian bahasa
│   └── ui_helper.dart                 # Dialog, Snackbar, & Helpers
│
└── widgets/                           # Reusable Widgets
    ├── shimmer_loading.dart           # Skeleton loading
    ├── connection_badge.dart          # Status koneksi
    ├── loading_widget.dart            # Loading overlay
    └── ...
```

---

## ⚙️ Konfigurasi & Setup

### Prasyarat
- **Flutter SDK** `>= 3.6.0`
- **Dart SDK** `>= 3.6.0`
- **Android Studio** / **VS Code** dengan Flutter extension
- **Firebase Project** yang sudah dikonfigurasi
- **JDK 17** untuk build Android

### 1. Clone Repository

```bash
git clone https://github.com/MyusiZ3/MyDuitGweh.git
cd MyDuitGweh
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Konfigurasi Firebase

Pastikan file `firebase_options.dart` sudah ada di folder `lib/`. Jika belum:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login & Konfigurasi
firebase login
flutterfire configure
```

### 4. Konfigurasi Firestore

Buat collection dan dokumen berikut di Firestore:

#### `app_config/global`
```json
{
  "latestVersion": "1.0.5",
  "minVersion": "1.0.0",
  "downloadUrl": "https://your-download-url.com/app-release.apk",
  "isForceUpdate": false,
  "isMaintenance": false,
  "maintenanceMessage": ""
}
```

#### `app_settings/ai_config`
```json
{
  "is_ai_enabled": true,
  "max_chats_per_hour": 10,
  "reset_duration_minutes": 60,
  "gemini_keys": ["YOUR_GEMINI_API_KEY"],
  "groq_keys": ["YOUR_GROQ_API_KEY"]
}
```

#### `app_config/notification_listener`
```json
{
  "enabled": false
}
```

### 5. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 6. Jalankan Aplikasi

```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

---

## 📱 Build & Deploy

### Build APK Release

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

### Auto Deploy Script

Gunakan script `deploy_app.ps1` untuk otomasi penuh:

```powershell
.\deploy_app.ps1
```

Script ini akan:
1. ✅ Membaca versi dari `pubspec.yaml`
2. ✅ Build APK (skip jika versi sama)
3. ✅ Deploy ke Firebase Hosting
4. ✅ Membuat GitHub Release & upload APK

### Regenerasi Ikon Aplikasi

```bash
flutter pub run flutter_launcher_icons
```

---

## 🍴 Fork & Konfigurasi Proyek Sendiri

Panduan lengkap untuk mem-fork proyek ini dan menjalankannya dengan Firebase project kamu sendiri.

### 📋 Requirements (Wajib Diinstal)

| Tool | Versi Minimum | Link Download |
|------|---------------|---------------|
| **Flutter SDK** | `>= 3.6.0` | [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) |
| **Dart SDK** | `>= 3.6.0` | (Sudah termasuk di Flutter SDK) |
| **JDK** | `17` | [adoptium.net](https://adoptium.net/) |
| **Android Studio** | Latest | [developer.android.com/studio](https://developer.android.com/studio) |
| **Node.js** | `>= 18` | [nodejs.org](https://nodejs.org/) |
| **Firebase CLI** | Latest | `npm install -g firebase-tools` |
| **FlutterFire CLI** | Latest | `dart pub global activate flutterfire_cli` |
| **GitHub CLI** *(opsional)* | Latest | [cli.github.com](https://cli.github.com/) |
| **Git** | Latest | [git-scm.com](https://git-scm.com/) |

> **Catatan:** Pastikan `flutter doctor` tidak menunjukkan error sebelum lanjut.

### 🚀 Step-by-Step: Fork → Clone → Run

#### Step 1 — Fork Repository

```bash
# Fork repo dari GitHub (via browser atau CLI)
# Lalu clone hasil fork kamu:
git clone https://github.com/USERNAME_KAMU/MyDuitGweh.git
cd MyDuitGweh
```

#### Step 2 — Install Dependencies

```bash
flutter pub get
```

#### Step 3 — Buat Firebase Project Baru

```bash
# Login ke Firebase
firebase login

# Buat project baru (opsional, bisa juga via Firebase Console)
firebase projects:create nama-project-kamu

# Set project sebagai default
firebase use nama-project-kamu
```

Atau buat project langsung di [Firebase Console](https://console.firebase.google.com/):
1. Klik **Add Project**
2. Beri nama project → Klik **Continue**
3. Aktifkan/nonaktifkan Google Analytics → Klik **Create Project**

#### Step 4 — Hubungkan Flutter dengan Firebase

```bash
# Jalankan FlutterFire CLI untuk generate firebase_options.dart
flutterfire configure --project=nama-project-kamu
```

CLI ini akan otomatis:
- ✅ Membuat Firebase App (Android/iOS/Web)
- ✅ Mendownload `google-services.json` ke `android/app/`
- ✅ Meng-generate `lib/firebase_options.dart`

#### Step 5 — Aktifkan Firebase Authentication

Di [Firebase Console](https://console.firebase.google.com/) → project kamu:

1. Buka **Authentication** → **Sign-in Method**
2. Aktifkan **Email/Password**
3. *(Opsional)* Aktifkan **Google Sign-In**
   - Untuk Google Sign-In, tambahkan **SHA-1** dan **SHA-256** fingerprint:

```bash
# Ambil SHA key dari debug keystore
cd android
./gradlew signingReport
```

Copy SHA-1 & SHA-256 → Paste di **Firebase Console → Project Settings → Your Apps → Android → Add Fingerprint**

#### Step 6 — Aktifkan Cloud Firestore

1. Di Firebase Console → **Firestore Database** → **Create Database**
2. Pilih lokasi server (rekomendasi: `nam5` atau `asia-southeast1`)
3. Pilih **Start in Test Mode** (sementara)

#### Step 7 — Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

File `firestore.rules` di root project sudah berisi rules yang benar untuk role-based access.

#### Step 8 — Seed Data Firestore (Wajib!)

Buat dokumen berikut secara manual di Firestore Console:

**Collection `app_config` → Document `global`:**
```json
{
  "latestVersion": "1.0.0",
  "minVersion": "1.0.0",
  "downloadUrl": "",
  "isForceUpdate": false,
  "isMaintenance": false,
  "maintenanceMessage": ""
}
```

**Collection `app_settings` → Document `ai_config`:**
```json
{
  "is_ai_enabled": true,
  "max_chats_per_hour": 10,
  "reset_duration_minutes": 60,
  "gemini_keys": [],
  "groq_keys": []
}
```

**Collection `app_config` → Document `notification_listener`:**
```json
{
  "enabled": false
}
```

**Collection `app_config` → Document `survey`:**
```json
{
  "isActive": false,
  "title": "",
  "minVersion": "1.0.0"
}
```

#### Step 9 — Ganti Package Name & App Name (Android)

Ganti identitas aplikasi agar tidak bentrok dengan versi asli:

**1. `android/app/build.gradle` — Ganti `applicationId` dan `namespace`:**
```gradle
android {
    namespace = "com.namakamu.appkamu"
    // ...
    defaultConfig {
        applicationId = "com.namakamu.appkamu"
        // ...
    }
}
```

**2. `android/app/src/main/AndroidManifest.xml` — Ganti label:**
```xml
<application
    android:label="Nama App Kamu"
    ...>
```

**3. Rename folder Kotlin:**
```
# Rename folder:
android/app/src/main/kotlin/com/arch/myduitgweh/
# Menjadi:
android/app/src/main/kotlin/com/namakamu/appkamu/
```

**4. Update package name di semua file Kotlin (`MainActivity.kt`, `NotifListenerService.kt`):**
```kotlin
package com.namakamu.appkamu  // Baris pertama
```

**5. Update `AndroidManifest.xml` service reference (pastikan sesuai):**
```xml
<service
    android:name=".NotifListenerService"
    ...>
```

> ⚠️ Setelah ganti package name, **wajib jalankan ulang** `flutterfire configure` agar `google-services.json` diupdate!

#### Step 10 — Ganti Ikon Aplikasi

1. Ganti file `assets/images/logo_app.png` dengan logo kamu (rekomendasi: 1024x1024 PNG)
2. Jalankan:

```bash
flutter pub run flutter_launcher_icons
```

#### Step 11 — Jalankan Aplikasi

```bash
# Cek environment
flutter doctor

# Run di emulator atau device
flutter run

# Atau langsung release mode
flutter run --release
```

#### Step 12 — Set Akun Admin Pertama

1. Register/login akun pertama via aplikasi
2. Buka **Firestore Console** → Collection `users` → Cari dokumen user kamu
3. Tambahkan field `role` dengan value `superadmin`:
```json
{
  "role": "superadmin"
}
```
4. Restart aplikasi — menu Admin Panel akan muncul di halaman Home

---

### 🔧 Konfigurasi Lanjutan

#### Konfigurasi AI (Gemini / Groq)

Untuk mengaktifkan Archen AI Financial Advisor:

1. **Gemini API Key** — Dapatkan dari [aistudio.google.com](https://aistudio.google.com/apikey)
2. **Groq API Key** — Dapatkan dari [console.groq.com](https://console.groq.com/)
3. Masukkan key di Firestore `app_settings/ai_config` → field `gemini_keys` / `groq_keys`
4. Atau, user bisa memasukkan API key pribadi dari dalam aplikasi via menu **Manage API Key**

#### Konfigurasi Firebase Hosting (Landing Page)

```bash
# Deploy landing page
firebase deploy --only hosting
```

Landing page akan live di: `https://nama-project-kamu.web.app`

#### Konfigurasi In-App Update

1. Build APK release:
```bash
flutter build apk --release
```
2. Upload APK ke **Firebase Storage** atau server lain
3. Copy URL download APK
4. Update Firestore `app_config/global`:
```json
{
  "latestVersion": "1.0.1",
  "downloadUrl": "https://url-download-apk-kamu.com/app-release.apk"
}
```

#### Konfigurasi Auto Deploy Script

Edit `deploy_app.ps1` sesuai setup kamu:
- Pastikan `gh` (GitHub CLI) sudah login: `gh auth login`
- Pastikan `firebase` sudah login: `firebase login`
- Script otomatis membaca versi dari `pubspec.yaml`

```powershell
# Jalankan auto deploy
.\deploy_app.ps1
```

---

### 🐛 Troubleshooting

| Masalah | Solusi |
|---------|--------|
| `flutter pub get` gagal | Pastikan Flutter SDK dan Dart SDK versi `>= 3.6.0`. Jalankan `flutter upgrade` |
| `Gradle build failed` | Pastikan JDK 17 terinstal. Cek `JAVA_HOME` environment variable |
| `google-services.json not found` | Jalankan `flutterfire configure` ulang |
| `Notification Listener tidak aktif` | User harus grant izin di **Settings → Apps → Special Access → Notification Access** |
| `Firebase Auth error` | Pastikan SHA-1/SHA-256 sudah ditambahkan di Firebase Console |
| `Camera crash di Xiaomi` | Sudah ditangani otomatis — app memaksa Camera2 API (`AndroidCamera()`) |
| `Root detection blocking` | Matikan Magisk atau gunakan device non-root untuk testing |
| Build APK terlalu besar | Gunakan `flutter build apk --split-per-abi` untuk membagi per arsitektur |
| `minSdk` error | Pastikan `minSdk = 23` di `android/app/build.gradle` |

---

### 📁 File Penting yang Perlu Diperhatikan

| File | Fungsi | Perlu Diedit? |
|------|--------|---------------|
| `lib/firebase_options.dart` | Config Firebase (auto-generated) | ❌ Auto-generate via `flutterfire configure` |
| `android/app/google-services.json` | Firebase Android config | ❌ Auto-generate via `flutterfire configure` |
| `android/app/build.gradle` | Build config Android | ✅ Ganti `applicationId` & `namespace` |
| `android/app/src/main/AndroidManifest.xml` | Permissions & app label | ✅ Ganti `android:label` |
| `android/settings.gradle` | Plugin versions (Gradle, Kotlin, GMS) | ⚠️ Hanya jika perlu upgrade |
| `pubspec.yaml` | Dependencies & versi app | ✅ Ganti `version` saat rilis |
| `firestore.rules` | Security rules Firestore | ⚠️ Deploy setelah fork |
| `deploy_app.ps1` | Script auto deploy | ⚠️ Sesuaikan path & config |
| `assets/images/logo_app.png` | Logo aplikasi | ✅ Ganti dengan logo sendiri |

---

## 🗂️ Kategori Transaksi

### Pemasukan

`Gaji` · `Bonus` · `Investasi` · `Freelance` · `Hadiah` · `Penjualan` · `Transfer Masuk` · `Lainnya`

### Pengeluaran

`Makanan` · `Transportasi` · `Belanja` · `Cicilan` · `Hutang` · `Tagihan` · `Kesehatan` · `Pendidikan` · `Hobi` · `Pajak` · `Asuransi` · `Zakat/Donasi` · `Langganan` · `Hiburan` · `Transfer Keluar` · `Lainnya`

---

## 🔐 Role & Akses

| Role | Akses |
|------|-------|
| **User** | CRUD transaksi & dompet pribadi, chat AI, join colab |
| **Admin** | Semua akses User + Admin Panel, broadcast, kelola user |
| **SuperAdmin** | Semua akses Admin + hapus user, hapus feedback, full control |

---

## 📦 Dependensi Utama

| Library | Fungsi |
|---------|--------|
| `firebase_core` | Inisialisasi Firebase |
| `cloud_firestore` | Database real-time |
| `firebase_auth` | Autentikasi pengguna |
| `google_sign_in` | Login dengan Google |
| `flutter_local_notifications` | Notifikasi lokal |
| `google_generative_ai` | Gemini AI API |
| `fl_chart` | Grafik & Chart |
| `google_mlkit_text_recognition` | OCR untuk scan struk |
| `camera` | Kamera scanner |
| `dio` | HTTP client untuk download APK |
| `pdf` / `printing` | Pembuatan & cetak PDF |
| `local_auth` | Biometric authentication |
| `safe_device` | Deteksi root/jailbreak |
| `permission_handler` | Manajemen izin Android |
| `open_file_plus` | Buka & install APK |
| `package_info_plus` | Informasi versi aplikasi |
| `shared_preferences` | Penyimpanan lokal |
| `shimmer` | Skeleton loading effect |
| `connectivity_plus` | Deteksi koneksi internet |
| `workmanager` | Background task/sync |
| `sqflite` | Database lokal SQLite |

---

## 🌐 Infrastruktur Firebase

```text
Firebase Project
├── Authentication     → Email/Password + Google Sign-In
├── Cloud Firestore    → Database utama (users, wallets, transactions, config)
├── Firebase Hosting   → Landing page (myduitgweh.web.app)
└── Firebase Storage   → Distribusi file APK (opsional)
```

### Firestore Collections

| Collection | Deskripsi |
|-----------|-----------|
| `users/{uid}` | Data profil, role, kuota AI, preferensi |
| `users/{uid}/notifications` | Notifikasi per user |
| `users/{uid}/captured_notifications` | Notifikasi keuangan yang di-capture |
| `wallets/{walletId}` | Data dompet (owner, members, balance) |
| `transactions/{txnId}` | Data transaksi (terkoneksi ke walletId) |
| `app_config/global` | Konfigurasi global (versi, maintenance, update) |
| `app_config/survey` | Konfigurasi survey pengalaman pengguna |
| `app_settings/ai_config` | Konfigurasi AI (keys, quota, toggle) |
| `broadcasts/{id}` | Pengumuman dari admin |
| `user_feedbacks/{id}` | Feedback & hasil survey pengguna |

---

## 🚀 Alur Penggunaan

### Pengguna Baru
1. Buka aplikasi → **Onboarding** (3 halaman intro)
2. **Login** dengan Email/Password atau Google Sign-In
3. **Buat Dompet** pertama (Solo/Colab/Tabungan)
4. **Tambah Transaksi** — pilih kategori, nominal, dan catatan
5. **Lihat Laporan** — analisis keuangan di halaman Report
6. **Chat AI** — tanya Archen untuk saran keuangan personal

### Fitur Lanjutan
- Aktifkan **Biometric Lock** di Profil untuk keamanan ekstra
- Ubah **Gaya Bahasa** untuk pengalaman yang lebih personal
- Atur **Pengingat Harian** agar tidak lupa mencatat
- Aktifkan **Auto-Magic Sync** untuk pencatatan otomatis dari notifikasi m-banking
- Gunakan **Scan Struk** untuk mencatat transaksi dari struk belanja

---

## 📝 Changelog

### v1.0.5 (Latest)
- ✅ In-App Update System (manual check + force update)
- ✅ Receipt Scanner dengan AI Mode
- ✅ Multi-Platform AI (Gemini + Groq)
- ✅ Auto-Magic Sync (Experimental)
- ✅ Admin Panel lengkap
- ✅ Kepribadian Aplikasi 5 mode
- ✅ Kolaborasi Dompet + Chat Room
- ✅ Biometric & Security gates
- ✅ PDF Export
- ✅ Broadcast notification system

---

## 🤝 Kontributor

<table>
  <tr>
    <td align="center">
      <strong>Muhammad Archie</strong><br/>
      <em>Lead Developer & Designer</em>
    </td>
  </tr>
</table>

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah **MIT License**. Lihat file [LICENSE](LICENSE) untuk detail lebih lanjut.


---

<p align="center">
  <sub>Dibuat dengan ❤️ menggunakan Flutter & Firebase</sub><br/>
  <sub>© 2024-2026 MyDuitGweh. All rights reserved.</sub>
</p>
