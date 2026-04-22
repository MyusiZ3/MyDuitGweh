import 'package:flutter/material.dart';

class CategoryMatcher {
  static final Map<String, List<String>> _keywords = {
    'Makan \u0026 Minum': [
      'makan', 'minum', 'kopi', 'restoran', 'warung', 'gojek', 'grabfood', 'shopeefood', 
      'cemilan', 'snack', 'dinner', 'lunch', 'breakfast', 'sarapan', 'bakso', 'mie', 'nasi'
    ],
    'Transportasi': [
      'bensin', 'parkir', 'gojek', 'gocar', 'grab', 'ojek', 'tol', 'kereta', 'bus', 'tiket', 
      'pajak motor', 'service', 'oli', 'ban'
    ],
    'Belanja': [
      'tokopedia', 'shopee', 'lazada', 'alfamart', 'indomaret', 'supermarket', 'mall', 
      'pakaian', 'baju', 'celana', 'sepatu', 'elektronik'
    ],
    'Tagihan': [
      'listrik', 'pln', 'air', 'pdam', 'wifi', 'internet', 'pulsa', 'kuota', 'netflix', 
      'spotify', 'asuransi', 'kos', 'kontrakan', 'cicilan'
    ],
    'Kesehatan': [
      'obat', 'apotek', 'rumah sakit', 'dokter', 'vitamin', 'masker', 'skincare'
    ],
    'Hiburan': [
      'nonton', 'bioskop', 'game', 'topup', 'liburan', 'hotel', 'staycation', 'wisata'
    ],
    'Pendidikan': [
      'buku', 'kursus', 'udemy', 'sekolah', 'kuliah', 'alat tulis'
    ],
    'Sosial': [
      'sedekah', 'zakat', 'donasi', 'kado', 'hadiah', 'pinjaman'
    ],
  };

  static String? matchCategory(String note) {
    if (note.isEmpty) return null;
    final lowerNote = note.toLowerCase();
    
    for (var entry in _keywords.entries) {
      for (var keyword in entry.value) {
        if (lowerNote.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }
}
