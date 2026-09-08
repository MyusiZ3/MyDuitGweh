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
---

## 🎨 3. Palet Warna Semantik Pastel (Semantic Pastel Palette)

Palet semantik berikut digunakan untuk status transaksi, grafik, indikator, dan tombol aksi:

| Komponen / Fungsi | Kode Warna HEX | Color Code (Dart) | Visual Preview | Keterangan |
| :--- | :--- | :--- | :---: | :--- |
| **Pastel Red (Expense / Money Out)** | `#F87171` | `Color(0xFFF87171)` | 🟥 | Coral Salmon Pastel (Pengeluaran) |
| **Pastel Green (Income / Money In)** | `#34D399` | `Color(0xFF34D399)` | 🟩 | Soft Mint Emerald Pastel (Pemasukan) |
| **Pastel Blue / Periwinkle (Transfer)** | `#8B85F6` | `Color(0xFF8B85F6)` | 🟪 | Soft Periwinkle Pastel (Pindah Dana) |
| **Pastel Yellow / Amber (Savings / Warning)** | `#FBBF24` | `Color(0xFFFBBF24)` | 🟨 | Warm Honey Gold Pastel (Tabungan & Warning) |
| **CTA Pill Button (Main Action)** | `#18181B` | `Color(0xFF18181B)` | 🖤 | Deep Slate Black (Tombol Utama Simpan/Bayar) |


---

## 🟢 3. Prinsip Warna Pastel (Soft & Muted Rules)

1. **Rendah Kejenuhan (Low Saturation)**: Menghindari warna *electric blue*, *neon purple*, atau *high-saturation orange* (`#F97316` / `#4338CA`).
2. **Penggunaan Tone Periwinkle & Cream**: Menggunakan periwinkle lembut (`#8B85F6` / `#6B64DB`) dan *warm cream/peach* (`#FFC069` / `#E09F56`).
3. **Harmoni Kontras**: Angka saldo dan teks pada kartu tetap putih bersih (`#FFFFFF`) di atas background pastel agar mudah dibaca.

---

## ⚫ 4. Aturan Warna Hitam (No Pure Black Rule)

> **WAJIB**: Jangan pernah menggunakan pure black `#000000` / `Colors.black` sebagai warna teks atau background di aplikasi ini.

Gunakan warna **off-black (near-black)** berikut sebagai pengganti:

| Penggunaan | Kode HEX | Dart Code | Keterangan |
| :--- | :--- | :--- | :--- |
| **Teks Utama (Light Mode)** | `#1C1C1E` | `Color(0xFF1C1C1E)` | Apple-style near-black, tidak keras di mata |
| **Teks Sekunder Gelap** | `#3A3A3C` | `Color(0xFF3A3A3C)` | Satu level lebih terang dari off-black |
| **Tombol CTA / Pill Black** | `#18181B` | `Color(0xFF18181B)` | Paling gelap yang diperbolehkan (Deep Slate) |
| **Background Dark Mode** | `#121214` | `Color(0xFF121214)` | Scaffold dark, bukan pure black |

### Alasan:
- Pure black `#000000` terasa terlalu keras dan tidak sesuai dengan estetika pastel yang dibangun.
- Off-black seperti `#1C1C1E` (digunakan Apple di iOS) lebih lembut dan nyaman dipandang.
- Pada dark mode, background `#121214` (bukan `#000000`) memberikan kesan premium dan tidak "terlalu pekat".
