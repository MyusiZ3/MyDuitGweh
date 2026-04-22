class FinancialLogic {
  /// Nisab emas dalam gram (ketentuan umum 85 gram)
  static const double nisabGoldGram = 85.0;

  /// Harga emas default (akan diupdate berkala atau via settings)
  /// Harga di April 2024 sekitar Rp 1.100.000 - Rp 1.300.000
  static const double defaultGoldPrice = 1350000.0;

  /// Tarif zakat mal (2.5%)
  static const double zakatRate = 0.025;

  /// Tarif estimasi pajak bulanan (Simplify: 5% dari pendapatan)
  static const double defaultTaxRate = 0.05;

  /// Menghitung apakah kekayaan sudah mencapai Nisab
  static bool reachesNisab(double netWorth, {double? goldPrice}) {
    final currentNisab = (goldPrice ?? defaultGoldPrice) * nisabGoldGram;
    return netWorth >= currentNisab;
  }

  /// Menghitung estimasi zakat mal
  static double calculateZakat(double netWorth, {double? goldPrice}) {
    if (reachesNisab(netWorth, goldPrice: goldPrice)) {
      return netWorth * zakatRate;
    }
    return 0.0;
  }

  /// Menghitung estimasi pajak berdasarkan pendapatan bulanan
  static double calculateTax(double monthlyIncome, {double? taxRate}) {
    return monthlyIncome * (taxRate ?? defaultTaxRate);
  }

  /// Mendapatkan deskripsi progress Nisab
  static double getNisabProgress(double netWorth, {double? goldPrice}) {
    final currentNisab = (goldPrice ?? defaultGoldPrice) * nisabGoldGram;
    if (currentNisab == 0) return 1.0;
    return (netWorth / currentNisab).clamp(0.0, 1.0);
  }
}
