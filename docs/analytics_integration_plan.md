# ═══════════════════════════════════════════════════════════════════
#  📝 USER VOICE & AI INSIGHTS — In-App Feedback System
#  Implementation Plan v1.0
#  Project: MyDuitGweh — Fase 4: Deep Analytics Integration
# ═══════════════════════════════════════════════════════════════════

## 📋 RINGKASAN PROYEK

Target: Menggantikan pengumpulan feedback eksternal (Google Form) menjadi sistem survei internal "In-App" yang terintegrasi dengan Eagle Eye Dashboard. Admin dapat mengontrol kemunculan survei secara real-time dan menganalisis sentimen user menggunakan AI.

Status Saat Ini:
  - User Side: Belum ada menu feedback internal.
  - Admin Side: Eagle Eye sudah memiliki AI Macros & Leaderboard.
  - AI Service: Sudah mendukung multi-key (Gemini/Groq).

---

## 🔐 HAK AKSES: USER vs ADMIN vs SUPERADMIN

```
┌─────────────────────────────────────────┬──────────┬──────────┬──────────────┐
# │ FITUR                                   │   USER   │  ADMIN   │  SUPERADMIN  │
# ├─────────────────────────────────────────┼──────────┼──────────┼──────────────┤
# │ Mengisi Survei (BottomSheet)            │    ✅    │    ✅    │      ✅      │
# ├─────────────────────────────────────────┼──────────┼──────────┼──────────────┤
# │ Melihat List Feedback Masuk             │    ❌    │    ✅    │      ✅      │
# ├─────────────────────────────────────────┼──────────┼──────────┼──────────────┤
# │ 🤖 AI Sentiment Analysis API            │    ❌    │    ❌    │      ✅      │
# │ (Reuse Key dari Macros Analysis)        │          │          │   UNLOCKED   │
# ├─────────────────────────────────────────┼──────────┼──────────┼──────────────┤
# │ ⚙️ Survey Remote Control Panel         │    ❌    │    ❌    │      ✅      │
# │ (Enable/Disable & Threshold Setup)      │          │          │   UNLOCKED   │
# └─────────────────────────────────────────┴──────────┴──────────┴──────────────┘
```

---

## 📊 DETAIL FITUR FASE 4

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### FASE 4.1: USER EXPERIENCE (Entry Point & Form)
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#### FITUR #7: 📝 In-App User Feedback System

```
AKSES  : Semua User
PACKAGE: Tidak ada package baru
LOKASI : ProfileScreen → Di bawah menu "Tentang Aplikasi"

DESKRIPSI:
  Sebuah menu permanen di profil dan trigger otomatis di Home
  untuk mengumpulkan feedback berkualitas tinggi.

DATA SOURCE (Firestore):
  Collection: `user_feedbacks/{feedbackId}`
  Schema:
    {
      userId: "UID",
      rating: 5,                  // Star rating 1-5
      category: "Performance",    // UI, Fitur, Bug, Performa
      comment: "Aplikasi lancar..", // Teks bebas
      appVersion: "1.2.0",        // String
      deviceInfo: "Android 13..", // Model HP & OS
      createdAt: Timestamp
    }

UI WIREFRAME (User Form):
  ┌─ Bagaimana Pengalaman Anda? ──────────┐
  │                                          │
  │      ⭐ ⭐ ⭐ ⭐ ⭐                       │
  │   [ Sangat Puas ]                        │
  │                                          │
  │  Mengenai: [ 🚀 Performance ▾ ]          │
  │                                          │
  │  [ Ceritakan lebih detail...       ]     │
  │                                          │
  │  [ KIRIM FEEDBACK ]                      │
  └──────────────────────────────────────────┘

DETAIL UI:
  - BottomSheet dengan blur background (Glassmorphism).
  - Lottie animation untuk "Success" setelah kirim.
  - Menu di Profile diletakkan tepat di bawah "Tentang Aplikasi".
```

### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
### FASE 4.2: ADMINISTRATIVE CONTROL (SuperAdmin Only)
### ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#### FITUR #8: ⚙️ Survey Remote Control Panel

```
AKSES  : SuperAdmin ✅
RISIKO : Tinggi — Mengontrol interaksi seluruh user

DESKRIPSI:
  Panel kontrol untuk mengatur strategi pengumpulan feedback
  tanpa perlu melakukan update aplikasi (Remote Config).

PENGATURAN TEKNIS:
  - is_survey_enabled (bool): Saklar ON/OFF survei.
  - min_transactions (int): User baru bisa isi jika Tx >= X.
  - min_account_age_days (int): User baru bisa isi jika Umur Akun >= X.

AUDIT LOGGING:
  Setiap kali SuperAdmin mengubah setting, akan dicatat ke:
  `app_config/global/history`
  Format: "[Admin Name] mengubah status survei menjadi [Open/Closed]"
```

#### FITUR #9: 🧠 AI Sentiment Aggregator

```
AKSES  : SuperAdmin ✅
API KEY: SAMA dengan AI Macros Analysis (Reuse kuota)

DESKRIPSI:
  Menganalisis tumpukan feedback user menggunakan AI untuk 
  menemukan pola keluhan atau fitur yang paling diinginkan.

UI WIREFRAME (Eagle Eye):
  ┌─ 🧠 AI Sentiment Analysis ────────────┐
  │                                          │
  │  [ 🤖 Jalankan Analisis Archen ]         │
  │                                          │
  │  ## 📊 Rekap Sentimen                   │
  │  Sentimen umum 90% Positif...            │
  │                                          │
  │  ## 💡 Rekomendasi Fitur                │
  │  1. Tambah Dashboard Laporan Bulanan     │
  │  2. Optimasi loading scan struk...       │
  └──────────────────────────────────────────┘
```

---

## 🏗️ ARSITEKTUR TEKNIS (REMOTE CONFIG)

### Firestore Structure
```
Firestore
├── user_feedbacks/{id}        ← Data survei user
│
└── app_config/survey          ← Konfigurasi survei
    ├── is_available: true
    ├── min_tx: 5
    └── min_days: 3
```

### Logika Trigger Notifikasi
Saat Admin mengubah status survei dari `OFF` → `ON`, sistem akan mengirimkan fungsi pemicu Popup/SnackBar di sisi user menggunakan state listener pada `getSurveyConfig()`.

---

## 🚀 FASE EKSEKUSI

```
FASE 4a — Data Foundation
  1. Buat FeedbackModel & SurveyConfigModel.
  2. Implementasi submitFeedback() di FirestoreService.
  3. Implementasi getSurveyConfigStream() untuk Remote Config.

FASE 4b — User Interface
  4. Buat menu "Survei Kepuasan" di ProfileScreen (bawah Tentang Aplikasi).
  5. Buat Form Survei (BottomSheet) + Metadata capture.
  6. Tambahkan logika trigger otomatis di HomeScreen.

FASE 4c — Admin & AI Integration
  7. Buat Survey Control Panel di Dashboard Eagle Eye.
  8. Tambahkan Audit Logging ke Global Activity History.
  9. Integrasi AI Sentiment Analysis (Reuse Key Macros).
```

---

## ✅ VERIFICATION PLAN

1. **Placement Test**: Buka Profile -> Verifikasi menu survei ada di bawah "Tentang Aplikasi".
2. **Remote Toggle**: Turn OFF survei dari Eagle Eye -> Cek di profil user apakah menu hilang/berubah status.
3. **Audit Log**: Ubah setting -> Cek layar `Admin Dash > Activity Log` -> Judul log muncul.
4. **AI Key Sync**: Pastikan analisis survei TIDAK meminta API Key baru jika Macros Analysis sudah aktif.
