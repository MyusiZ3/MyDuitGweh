# 🎨 Color Palette & Design System — MyDuitGweh

Panduan Palet Warna Pastel & Sistem Desain UI untuk Aplikasi Financial Tracker **MyDuitGweh**.

---

## 🌟 Core Pastel Color Palette

Palet warna utama aplikasi ini menggunakan perpaduan **Soft Pastels Modern** yang cerah, ramah mata, dan memberikan kontras tinggi pada tampilan **Light Mode** maupun **Dark Mode (OLED Black)**.

| Kategori | Hex Code | Pratinjau | Fungsi Utama & Penggunaan |
| :--- | :--- | :--- | :--- |
| **Pastel Red** | `#FF746C` | 🔴 `RGB(255, 116, 108)` | **Pengeluaran (Expense)**, Transaksi Keluar, Alert Kritis, Indicator Ring Overbudget |
| **Pastel Green** | `#80EF80` | 🟢 `RGB(128, 239, 128)` | **Pemasukan (Income)**, Transaksi Masuk, Status Positif, Rata-rata Hemat |
| **Pastel Blue** | `#60A5FA` | 🔵 `RGB(96, 165, 250)` | **Primary Accent**, Filter Periode, Kalender Active Range, Tombol Aksi Utama |
| **Pastel Yellow** | `#FFEE8C` | 🟡 `RGB(255, 238, 140)` | **Peringatan / Highlight**, Saldo Perhatian, Badge Kategori Netral, Catatan |
| **Pastel Orange** | `#FFC067` | 🟠 `RGB(255, 192, 103)` | **Anggaran Bulanan (Budget)**, Status Transaksi Pending, Chart Donut Slice |

---

## 🌓 Neutral & Surface Colors

### Light Mode Surface (`Bright & Clean`)
- **Background**: `#F2F2F7` (Apple iOS System Gray 6)
- **Card Surface**: `#FFFFFF` (Solid White)
- **Secondary Surface**: `#F4F4F5` (Subtle Soft Gray)
- **Text Primary**: `#18181B` (Deep Carbon)
- **Text Secondary**: `#71717A` (Muted Slate)

### Dark Mode Surface (`OLED Glassmorphism`)
- **Background**: `#000000` / `#121214` (Deep OLED Black)
- **Card Surface**: `#1C1C1E` / `#242429` (Apple System Gray 6 Dark)
- **Active Card Highlight**: `#232A3B` (Subtle Blue Tinted Dark)
- **Text Primary**: `#FFFFFF` (Pure White)
- **Text Secondary**: `#A1A1AA` (Soft White 70%)

---

## 📐 Usage Guidelines & UI Rules

### 1. Transparency & Glassmorphism
- **Selection Pills & Badges**: Gunakan warna pastel dengan transparansi `0.15` hingga `0.25` (contoh: `Color(0xFF60A5FA).withOpacity(0.18)`).
- **Active Borders**: Gunakan warna pastel solid dengan ketebalan `1.5px` untuk menandai elemen yang dipilih.

### 2. Chart & Financial Metrics Mapping
- **Pengeluaran**: `#FF746C`
- **Pemasukan**: `#80EF80`
- **Total Saldo**: `#60A5FA`
- **Budget / Sisa Anggaran**: `#FFC067`
- **Peringatan Batas Hemat**: `#FFEE8C`

---

## 💻 Implementation Snippet (Flutter Dart)

```dart
import 'package:flutter/material.dart';

class AppPastelColors {
  // Core Pastel Palette
  static const Color pastelRed    = Color(0xFFFF746C);
  static const Color pastelGreen  = Color(0xFF80EF80);
  static const Color pastelBlue   = Color(0xFF60A5FA);
  static const Color pastelYellow = Color(0xFFFFEE8C);
  static const Color pastelOrange = Color(0xFFFFC067);

  // Semantic Mappings
  static const Color expense = pastelRed;
  static const Color income  = pastelGreen;
  static const Color primary = pastelBlue;
  static const Color warning = pastelYellow;
  static const Color budget  = pastelOrange;

  // Background Opacity Wrappers
  static Color redBg(bool isDark)    => pastelRed.withOpacity(isDark ? 0.25 : 0.15);
  static Color greenBg(bool isDark)  => pastelGreen.withOpacity(isDark ? 0.25 : 0.15);
  static Color blueBg(bool isDark)   => pastelBlue.withOpacity(isDark ? 0.25 : 0.18);
  static Color yellowBg(bool isDark) => pastelYellow.withOpacity(isDark ? 0.25 : 0.18);
  static Color orangeBg(bool isDark) => pastelOrange.withOpacity(isDark ? 0.25 : 0.18);
}
```
