# 🔐 System Plan: Auth & Design System
**Status: COMPLETED (Production Ready)**

Dokumentasi ini merangkum gerbang keamanan (Authentication) dan bahasa visual (Design Tokens) yang memberikan identitas unik pada aplikasi MyDuitGweh.

---

## 🏗️ Authentication Infrastructure

### 1. Unified Auth Service
Sistem tunggal untuk mengelola kredensial dan sesi user:
- **Firebase Auth Implementation**: Mendukung Login Email/Password dan **Google Sign-In** (opsional).
- **Session Persistence**: Menggunakan SharedPreferences untuk menyimpan metadata user agar tidak perlu login ulang setiap membuka aplikasi.
- **Role-Based Access Control (RBAC)**: Membedakan akun **SuperAdmin** (akses Eagle Eye) dan User Biasa melalui role di dokumen `users/{uid}`.

### 2. User Lifecycle Management
- **Onboarding Logic**: Pendeteksian user baru untuk menampilkan intro singkat.
- **Profile Customization**: Edit Nama, Foto, dan PIN Keamanan dari layar profil.

---

## 🎨 Design System & Visual Tokens

### 1. Glassmorphism Aesthetics
Bahasa visual utama yang menonjolkan kedalaman dan transparansi:
- **Backdrop Blur (Frosted Glass)**: Digunakan pada AppBar, BottomSheet, dan Modal Popup.
- **Glassy Cards**: Card dengan opacity transparan dan border halus (hairline border).
- **Elevated Surfaces**: Penggunaan Drop Shadow yang lembut untuk efek melayang.

### 2. Premium Color Tokens
Pemilihan warna yang harmonis untuk kesan premium:
- **Primary Gradient**: Perpaduan biru tua/ungu untuk kesan finansial yang stabil.
- **Success/Danger Hues**: Hijau & Merah yang lembut (bukan warna dasar/mencolok).
- **Dark Mode Optimization**: Desain yang didesain dari awal untuk kenyamanan di malam hari.

### 3. Motion & Micro-Animations
- **Lottie Animations**: Digunakan untuk state Loading, Success (centang), dan Empty State (brankas kosong).
- **Hero Transitions**: Animasi perpindahan halus saat membuka detail dompet.

---

## 🛠️ Komponen Teknis
| Komponen | Deskripsi |
| :--- | :--- |
| `AuthService.dart` | Singleton untuk operasi Auth (Login, Register, Sign Out). |
| `UIHelper.dart` | Kumpulan utility untuk Backdrop Blur & Glassy Style. |
| `AppColors.dart` | Definisi palet warna global. |
| `ProfileScreen.dart` | Pusat pengaturan user dan tampilan akun. |

---

## 🎯 Target Pengalaman User
- **Seamless**: Login instan dan aman melalui ekosistem Google/Firebase.
- **Premium WoW**: User merasa bangga menggunakan aplikasi yang terlihat indah ("Eyecandy").
- **Consistent**: Semua layar memiliki bahasa visual yang seragam dan tidak membingungkan.
