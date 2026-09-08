# 🎨 Dokumentasi Palet Warna & Panduan UI (MyDuitGweh)

Dokumen ini berfungsi sebagai acuan resmi (*design token reference*) untuk skema warna, komponen UI, dan panduan gaya visual aplikasi **MyDuitGweh**. Seluruh pengembangan UI di masa mendatang **wajib mematuhi palet warna pastel ini** untuk menjaga konsistensi visual di *Light Mode* dan *Dark Mode*.

---

## ☀️ 1. Light Mode Palette (Soft Pastel Banking Aesthetic)

Palet *Light Mode* dirancang dengan gaya *soft pastel mobile banking* (berbasis warna pastel periwinkle-ivory yang lembut dan tidak tajam).

| Komponen / Fungsi | Kode Warna HEX | Color Code (Dart) | Visual Preview | Keterangan |
| :--- | :--- | :--- | :---: | :--- |
| **Scaffold / Canvas Background** | `#F3F1F7` | `Color(0xFFF3F1F7)` | 🟣 | Latar belakang utama seluruh layar (*Soft Ivory Lavender*) |
| **Card / Surface Container** | `#FFFFFF` | `Colors.white` | ⚪ | Latar container bento card, modal, & nav bar |
| **Front Credit Card** | `#8B85F6` | `Color(0xFF8B85F6)` | 🟪 | Warna kartu saldo utama (*Soft Pastel Lavender*) |
| **Stacked Card Backing** | `#FFC069` | `Color(0xFFFFC069)` | 🟠 | Warna intip kartu belakang (*Warm Soft Sand/Peach*) |
| **Center Action Button** | `#7C75D9` | `Color(0xFF7C75D9)` | 🔵 | Tombol lingkaran scanner / aksi tengah (*Soft Periwinkle*) |
| **CTA Pill Button / Black Accent** | `#18181B` | `Color(0xFF18181B)` | 🖤 | Tombol CTA kapsul utama (*Deep Slate Black*) |
| **Teks Utama (Title & Heading)** | `#18181B` | `Color(0xFF18181B)` | 🖤 | Warna teks judul & angka utama |
| **Teks Sekunder (Subtitle & Hint)** | `#71717A` | `Color(0xFF71717A)` | 🩶 | Warna teks keterangan & sub-informasi |

---

## 🌙 2. Dark Mode Palette (True Soft Pastel Dark Theme)

Palet *Dark Mode* **tidak menggunakan warna elektrik/neon tajam**, melainkan warna *pastel desaturated* yang lembut dan adem di mata.

| Komponen / Fungsi | Kode Warna HEX | Color Code (Dart) | Visual Preview | Keterangan |
| :--- | :--- | :--- | :---: | :--- |
| **Scaffold / Canvas Background** | `#121214` | `Color(0xFF121214)` | 🖤 | Latar belakang utama layar (*Deep Charcoal*) |
| **Card / Surface Container** | `#1C1C22` | `Color(0xFF1C1C22)` | ⬛ | Latar container bento card & quick action box |
| **Front Credit Card** | `#6B64DB` | `Color(0xFF6B64DB)` | 🟪 | Kartu saldo utama (*Desaturated Soft Periwinkle*) |
| **Stacked Card Backing** | `#E09F56` | `Color(0xFFE09F56)` | 🟧 | Intip kartu belakang (*Soft Pastel Warm Sand*) |
| **Center Action Button** | `#7C75D9` | `Color(0xFF7C75D9)` | 🔵 | Tombol lingkaran scanner (*Soft Periwinkle Pastel*) |
| **Quick Action Icon: Catat** | `#ECFDF5` / `#34D399` | `Color(0xFF34D399)` | 🟩 | Soft mint pastel |
| **Quick Action Icon: Colab** | `#F3E8FF` / `#A78BFA` | `Color(0xFFA78BFA)` | 🟪 | Soft lavender purple pastel |
| **Quick Action Icon: Dompet** | `#EFF6FF` / `#60A5FA` | `Color(0xFF60A5FA)` | 🟦 | Soft periwinkle blue pastel |
| **Quick Action Icon: Laporan** | `#FEF3C7` / `#FBBF24` | `Color(0xFFFBBF24)` | 🟧 | Soft amber gold pastel |

---

## 🟢 3. Prinsip Warna Pastel (Soft & Muted Rules)

1. **Rendah Kejenuhan (Low Saturation)**: Menghindari warna *electric blue*, *neon purple*, atau *high-saturation orange* (`#F97316` / `#4338CA`).
2. **Penggunaan Tone Periwinkle & Cream**: Menggunakan periwinkle lembut (`#8B85F6` / `#6B64DB`) dan *warm cream/peach* (`#FFC069` / `#E09F56`).
3. **Harmoni Kontras**: Angka saldo dan teks pada kartu tetap putih bersih (`#FFFFFF`) di atas background pastel agar mudah dibaca.
