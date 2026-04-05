# Throttling & Rate Limiting — MyDuitGweh

Dokumen ini menguraikan rencana implementasi untuk melindungi aplikasi dari request berlebihan (spam klik, bot abuse, rogue user) di tiga lapisan berbeda.

---

## Latar Belakang

Saat ini MyDuitGweh memiliki beberapa titik lemah:

| Area | Masalah | Risiko |
|------|---------|--------|
| Tambah Transaksi | Error message masih pakai `ScaffoldMessenger` bukan `UIHelper`, tidak ada guard anti-spam klik di error path | Double-write ke Firestore |
| Firestore Rules | `/transactions` dan `/wallets` subcollection open `read, write` tanpa batasan burst | Rogue user bisa flood DB |
| Pull-to-Refresh | `RefreshIndicator` di `home_screen.dart` tidak ada cooldown, bisa dipanggil berkali-kali | Kuota Firestore reads membengkak |

---

## Scope Perubahan

### Layer 1 — Transaction Write Guard

#### [MODIFY] [add_transaction_screen.dart](file:///c:/Users/muham/Documents/Github/MyDuitGweh/lib/screens/add_transaction_screen.dart)

**Masalah**: `_isLoading` sudah ada dan tombol `Simpan` sudah di-disable saat loading (bagus!), tapi blok `catch` masih menggunakan `ScaffoldMessenger` standar, bukan `UIHelper`. Juga tidak ada guard tambahan jika `setState` dipanggil saat widget unmounted.

**Perubahan**:
1. Ganti `ScaffoldMessenger` di validasi awal dengan `UIHelper.showErrorSnackBar`.
2. Ganti `ScaffoldMessenger` di blok `catch` dengan `UIHelper.showErrorSnackBar`.
3. Tambahkan `_isLoading` guard di awal `_saveTransaction()` untuk mencegah double-call:

```dart
Future<void> _saveTransaction() async {
  if (_isLoading) return; // ← Guard anti-double call
  // ...
}
```

> **Catatan**: Secara teknis `isLoading` guard sudah ada via `onPressed: _isLoading ? null : _saveTransaction`, tapi guard eksplisit di awal method lebih aman sebagai defensive programming.

---

### Layer 2 — Firestore Security Rules Rate Limiting

#### [MODIFY] [firestore.rules](file:///c:/Users/muham/Documents/Github/MyDuitGweh/firestore.rules)

**Masalah**: Rule saat ini untuk transaksi dan wallet subcollection sangat terbuka:

```javascript
// SEKARANG - terlalu terbuka
match /transactions/{transactionId} {
  allow read, write, delete: if request.auth != null;
}

match /wallets/{walletId} {
  match /{allSubcollections=**} {
    allow read, write: if request.auth != null;
  }
}
```

**Strategi**: Implementasi **write-gap check** menggunakan field `lastTransactionAt` di dokumen user. Satu user hanya boleh menulis transaksi maksimal **1x per detik**.

> [!IMPORTANT]
> Firestore Security Rules **tidak mendukung state antar-request secara native** seperti Redis counter. Pendekatan yang digunakan adalah cek timestamp field di dokumen user untuk memastikan tidak ada burst write dalam window tertentu.

**Perubahan yang direncanakan**:

```javascript
// BARU - dengan rate limiting
function notWritingTooFast() {
  // Cek apakah field lastTransactionAt ada dan sudah > 1 detik yang lalu
  let userDoc = get(/databases/$(database)/documents/users/$(request.auth.uid));
  let lastWrite = userDoc.data.get('lastTransactionAt', null);
  return lastWrite == null || 
         request.time > lastWrite + duration.value(1, 's');
}

match /transactions/{transactionId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null && notWritingTooFast();
  allow update, delete: if request.auth != null && 
    request.auth.uid == resource.data.createdBy;
}
```

**Tambahan di Dart (FirestoreService)**: Setiap kali `addTransaction()` dipanggil, update field `lastTransactionAt` di dokumen user menggunakan `FieldValue.serverTimestamp()`.

---

### Layer 3 — Pull-to-Refresh Debouncer

#### [NEW] [debouncer.dart](file:///c:/Users/muham/Documents/Github/MyDuitGweh/lib/utils/debouncer.dart)

Buat utility class `Debouncer` dan `RefreshThrottle` untuk digunakan di semua screen yang memiliki refresh:

```dart
/// Throttle: Hanya izinkan satu panggilan dalam window waktu tertentu
class RefreshThrottle {
  final Duration cooldown;
  DateTime? _lastRefresh;

  RefreshThrottle({this.cooldown = const Duration(seconds: 5)});

  bool get canRefresh {
    if (_lastRefresh == null) return true;
    return DateTime.now().difference(_lastRefresh!) >= cooldown;
  }

  void markRefreshed() => _lastRefresh = DateTime.now();
}

/// Debouncer: Tunda eksekusi sampai tidak ada panggilan baru dalam window
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 500)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}
```

#### [MODIFY] [home_screen.dart](file:///c:/Users/muham/Documents/Github/MyDuitGweh/lib/screens/home_screen.dart)

Gunakan `RefreshThrottle` di `RefreshIndicator` yang ada di baris ~446:

```dart
// Di _HomeScreenState:
final _refreshThrottle = RefreshThrottle(cooldown: Duration(seconds: 5));

// Di onRefresh:
onRefresh: () async {
  if (!_refreshThrottle.canRefresh) return; // ← Blok jika terlalu cepat
  _refreshThrottle.markRefreshed();
  await _loadData(); // Panggil fungsi refresh yang sudah ada
},
```

---

## Urutan Implementasi

> [!NOTE]
> Urutan ini disusun dari perubahan paling aman (tidak mempengaruhi database) ke perubahan yang lebih kritis (Security Rules).

```
1. [RENDAH RISIKO]  Buat utils/debouncer.dart
2. [RENDAH RISIKO]  Perbaiki add_transaction_screen.dart (UIHelper + guard)
3. [RENDAH RISIKO]  Terapkan RefreshThrottle di home_screen.dart
4. [KRITIS]         Update firestore.rules + FirestoreService.addTransaction()
5. [KRITIS]         Deploy rules: firebase deploy --only firestore:rules
```

---

## Open Questions

> [!WARNING]
> Untuk poin no. 4 (Security Rules), kita perlu memastikan `FirestoreService.addTransaction()` selalu mengupdate `lastTransactionAt` **secara atomik** bersamaan dengan penambahan transaksi. Jika update user gagal tapi transaksi berhasil, rate limiting tidak akan bekerja.
>
> **Solusi yang direncanakan**: Gunakan Firestore `WriteBatch` untuk menjamin atomicity:
> ```dart
> final batch = FirebaseFirestore.instance.batch();
> batch.set(transactionRef, transactionData);
> batch.update(userRef, {'lastTransactionAt': FieldValue.serverTimestamp()});
> await batch.commit();
> ```

> [!IMPORTANT]
> Apakah ada screen lain selain `home_screen.dart` yang menggunakan pull-to-refresh? Jika ya, `RefreshThrottle` bisa diterapkan di semua screen tersebut dalam sekali implementasi.

---

## Verification Plan

### Automated
- `flutter analyze` — pastikan tidak ada lint errors baru.
- `firebase deploy --only firestore:rules --dry-run` — validasi sintaks Security Rules.

### Manual Testing
| Skenario | Langkah | Expected |
|----------|---------|----------|
| Double submit | Klik "Simpan" cepat 2x | Hanya 1 transaksi tersimpan |
| Pull-to-refresh spam | Pull ke bawah 3x dalam 5 detik | Hanya refresh 1x, sisanya diabaikan |
| Rate limit rules | Kirim 2 transaksi dalam < 1 detik via script | Request kedua ditolak Firestore |
| Debouncer search | Ketik cepat di search bar | API call hanya 1x setelah berhenti 500ms |
