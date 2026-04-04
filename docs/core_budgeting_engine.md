# 💳 System Plan: Core Budgeting Engine
**Status: COMPLETED (Production Ready)**

Ini adalah jantung dari aplikasi MyDuitGweh yang mengatur data keuangan user secara akurat, aman, dan real-time.

---

## 🏛️ Core Logic & Data Modeling

### 1. Multi-Dimensional Database (Firestore)
Struktur data dirancang untuk performa tinggi dengan minimal read/write:
- **`wallets/{walletId}`**: Mendukung multi-dompet (Dompet Pribadi, Dana Darurat, Tabungan Bisnis).
- **`transactions/{txId}`**: Setiap transaksi terikat pada `walletId` dan `userId`.
- **`categories`**: Koleksi global untuk pengelompokan pengeluaran.

### 2. Transaction Lifecycle
Hanya dalam satu flow `addTx()`, sistem melakukan 4 aksi sekaligus:
1. **Validation**: Cek saldo dompet (untuk pengeluaran).
2. **Persistence**: Tulis data baru ke Firestore `/transactions`.
3. **Wallet Update**: Menambah/Mengurangi saldo di dokumen `/wallets` secara atomik.
4. **Analytics Update**: Memperbarui agregasi total harian/bulanan di layar dashboard.

---

## 🚀 Fitur Utama

### 1. Unified Dashboard (Real-time)
- **Balance Aggregation**: User melihat total harta dari semua dompet di Home.
- **Recent Activity**: Stream 5 transaksi terakhir secara langsung (StreamBuilder).

### 2. Smart Reporting (Charts & Analytics)
- **Expense Categorization**: Pie Chart yang menunjukkan ke mana uang paling banyak dihabiskan.
- **Trend Analysis**: Bar Chart mingguan/bulanan untuk melihat fluktuasi pengeluaran.

---

## 🛠️ Komponen Teknis
| Komponen | Deskripsi |
| :--- | :--- |
| `FirestoreService.dart` | Singleton yang menangani seluruh logika CRUD Firestore. |
| `WalletModel.dart` | Representasi data dompet (Type: Personal, Business, etc). |
| `TransactionModel.dart` | Model data transaksi (Amount, Category, Date, Note). |
| `ReportsScreen.dart` | UI interaktif dengan integrasi chart (fl_chart). |

---

## 🎯 Target Pengalaman User
- **Integrity**: Saldo selalu sinkron antara dompet dan total semua transaksi (No data drift).
- **Speed**: Transaksi baru muncul secara instan di semua layar dashboard.
- **Clarity**: Visualisasi data yang memudahkan user mengambil keputusan finansial.
