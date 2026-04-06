# 📱 Notification Listener Feature — Flutter (Dart) Implementation Plan

## 🎯 Tujuan

Menyusun rencana implementasi fitur **Notification Listener** untuk pembelajaran:

- Membaca notifikasi secara selektif
- Menyimpan sementara (queue lokal)
- Mengirim data terstruktur ke Firebase Firestore
- Menggunakan scheduling yang efisien & aman baterai

---

# 🧩 1. Scope & Batasan

## ✅ Scope

- Ambil notifikasi dari app tertentu (WhatsApp / Instagram / TikTok / Twitter / Facebook / SMS dan app sosmed lain)
- Simpan data minimal (title, text, timestamp, package)
- Upload batch ke Firestore
- Buat menu khusus di dalam Admin Control Panel (khusus superadmin) dengan nama Notification Listener di bagian System & Utility, di bawah Maintenance Mode (yg muncul di superadmin doang)
- Di dalam menu tersebut (Notification Listener) ada tombol untuk mengaktifkan dan menonaktifkan fitur ini, dan juga ada tombol untuk melihat log notifikasi yg sudah masuk (yg sudah tersimpan di database lokal)
- Ada juga tombol untuk menghapus log notifikasi yg sudah masuk (yg sudah tersimpan di database lokal)
- Ada juga tombol untuk melihat log notifikasi yg sudah masuk (yg sudah tersimpan di database lokal)
- Ada juga fungsi untuk mengatur waktu pengiriman notifikasi ke Firestore (misal 1 jam sekali, 2 jam sekali, dst) custom

## ❌ Non-scope (untuk tahap awal)

- Media (image/attachment)
- Auto-reply / action trigger
- Real-time streaming

---

## 🎯 Tujuan

Dokumen ini adalah versi khusus Flutter dari sistem Notification Listener:

- Integrasi Flutter (Dart) + Android Native (Kotlin)
- Menyimpan data ke SQLite (sqflite/drift)
- Upload ke Firebase Firestore
- Menggunakan WorkManager untuk background task

---

# 🧠 1. Arsitektur Hybrid (Flutter + Native)

```
[Android Notification Listener (Kotlin)]
            ↓
      [MethodChannel]
            ↓
      [Flutter (Dart)]
            ↓
   [Local DB (SQLite)]
            ↓
   [Workmanager]
            ↓
   [Firestore]
```

---

# ⚙️ 2. Stack Teknologi

## 📱 Flutter (Dart)

- sqflite / drift (local database)
- workmanager (background task)
- cloud_firestore (Firebase)

## 🤖 Android Native (Kotlin)

- NotificationListenerService
- MethodChannel bridge

---

# 🧩 3. Komponen Sistem

## 🔹 1. Android Native Layer

### Fungsi:

- Menangkap notifikasi
- Filtering awal (optional)
- Kirim ke Flutter

### Output ke Flutter:

```json
{
  "package": "com.whatsapp",
  "title": "Budi",
  "text": "Halo",
  "timestamp": 1712233445
}
```

---

## 🔹 2. Flutter Layer

### Fungsi:

- Menerima data dari MethodChannel
- Menyimpan ke SQLite
- Menjalankan scheduler
- Upload ke Firestore

---

# 💾 4. Local Database (Flutter)

## 🔹 Gunakan:

- sqflite (simple)
- atau drift (recommended untuk scalable)

## 🔹 Struktur Table:

```sql
notifications (
  id TEXT PRIMARY KEY,
  package TEXT,
  title TEXT,
  text TEXT,
  timestamp INTEGER,
  is_synced INTEGER
)
```

---

# 🔄 5. Flow Implementasi

## Step 1 — Android Native

- Buat NotificationListenerService
- Override onNotificationPosted()

## Step 2 — Kirim ke Flutter

- Gunakan MethodChannel

## Step 3 — Flutter Receive

- Listen dari MethodChannel
- Convert ke model Dart

## Step 4 — Simpan ke SQLite

- Insert ke table notifications
- is_synced = 0

## Step 5 — Scheduler (Workmanager)

- Periodic task (15 menit+)
- Constraint: network available

## Step 6 — Upload ke Firestore

- Ambil data is_synced = 0
- Batch upload
- Update is_synced = 1

---

# ⏱️ 6. Scheduling Strategy

## 🔹 Workmanager Config

- PeriodicTask
- Interval minimal Android: 15 menit

## 🔹 Behavior

- Offline → delay otomatis
- Akan jalan saat internet tersedia

---

# ☁️ 7. Firestore Integration

## 🔹 Struktur Data

```
users/{userId}/notifications/{notifId}
```

## 🔹 Contoh Upload

```dart
await FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .collection('notifications')
  .add(data);
```

---

# 🔁 8. Error Handling

- Retry otomatis via Workmanager
- Gunakan backoff
- Hindari duplicate:
  - id = timestamp + hash

---

# 🔋 9. Optimasi

- Filter hanya app tertentu
- Limit queue (mis. 100 data)
- Gunakan batch upload

---

# ⚠️ 10. Tantangan Utama

## 🔴 Platform Channel

- Harus bikin bridge manual
- Debugging agak tricky

## 🔴 Background Execution

- Flutter bisa idle
- Harus rely ke Workmanager

## 🔴 Permission

- User harus enable manual Notification Access

---

# 🛡️ 11. Security & Ethics

- Jelaskan ke user kenapa butuh akses notif
- Hindari ambil data sensitif
- Gunakan untuk tujuan legitimate

---

# 🚀 12. Roadmap Implementasi

## Phase 1

- Setup Flutter project
- Setup Firebase

## Phase 2

- Implement Native Listener (Kotlin)
- Setup MethodChannel

## Phase 3

- Setup SQLite (sqflite/drift)

## Phase 4

- Setup Workmanager

## Phase 5

- Integrasi Firestore

## Phase 6

- Testing & optimasi

---

# 🎯 13. Checklist

- [ ] Notification listener jalan
- [ ] Data masuk ke Flutter
- [ ] Data tersimpan di SQLite
- [ ] Workmanager jalan
- [ ] Upload ke Firestore sukses

---

# 📌 Kesimpulan

Flutter membutuhkan pendekatan hybrid:

- Native Android untuk akses sistem
- Flutter untuk logic & UI

Pendekatan ini memastikan:

- Fleksibilitas
- Skalabilitas
- Maintainability

---

# ✨ Catatan

Fokus utama:

> bridge native ↔ flutter

Ini adalah bagian paling penting dalam implementasi.
