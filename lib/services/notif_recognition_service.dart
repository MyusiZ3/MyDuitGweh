import 'package:flutter/foundation.dart';

class TransactionData {
  final double amount;
  final bool isIncome;
  final String description;
  final String sourceApp;

  TransactionData({
    required this.amount,
    required this.isIncome,
    required this.description,
    required this.sourceApp,
  });
}

class NotifRecognitionService {
  // Financial Apps Package Names
  static const Map<String, String> _financialApps = {
    'com.bca': 'BCA Mobile',
    'id.co.bri.brimo': 'BRImo',
    'com.bankmandiri.livin': 'Livin\' by Mandiri',
    'src.com.bni': 'BNI Mobile',
    'com.gojek.app': 'GoPay',
    'com.shopee.id': 'ShopeePay',
    'com.ovo.id': 'OVO',
    'id.dana': 'DANA',
    'com.telkom.mwallet': 'LinkAja',
  };

  // Keywords for detection
  static const List<String> _incomeKeywords = [
    'diterima',
    'dana masuk',
    'top up',
    'transfer dari',
    'cashback',
    'kredit',
    'pemasukan'
  ];

  static const List<String> _expenseKeywords = [
    'pembayaran',
    'transfer ke',
    'qris',
    'bayar',
    'debit',
    'pengeluaran',
    'berhasil kirim'
  ];

  static bool isFinancialApp(String packageName) {
    return _financialApps.containsKey(packageName);
  }

  static String getAppName(String packageName) {
    return _financialApps[packageName] ?? 'Keuangan';
  }

  static TransactionData? parseTransaction(String packageName, String text) {
    final lowerText = text.toLowerCase();

    // 1. Determine Income vs Expense
    bool? isIncome;
    for (var keyword in _incomeKeywords) {
      if (lowerText.contains(keyword)) {
        isIncome = true;
        break;
      }
    }

    if (isIncome == null) {
      for (var keyword in _expenseKeywords) {
        if (lowerText.contains(keyword)) {
          isIncome = false;
          break;
        }
      }
    }

    // Default to Expense if unclear but from a financial app
    isIncome ??= false;

    // 2. Extract Amount
    // Matches patterns like "Rp 50.000", "50,000", "Rp50.000", "100.000,00"
    final regex =
        RegExp(r'(?:rp|idr)?[\s\.]?([\d\.,]{3,})', caseSensitive: false);
    final match = regex.firstMatch(text);

    if (match == null) return null;

    String amountStr = match.group(1)!;
    // Clean string (remove dots for thousands, commas for decimals)
    // Assume Indonesian format: 1.000.000 or 1,000,000
    // Standardize: remove all non-digits except common decimal separator (if any)
    // For now, removing all '.' and ',' to get raw number, then handling decimal

    // If it has both . and , (e.g. 1.000,50), the last one is likely decimal
    double originalAmount = 0;
    try {
      // Very simple cleaner: Remove all non-numeric except the last comma/dot if it looks like decimal
      String cleaned = amountStr.replaceAll(RegExp(r'[^0-9]'), '');

      // If we see something like 1.000.000, we just want the digits
      // But if we see 50,50 we might want 50.5
      // For this simple version, let's just take the digits and parse as double
      originalAmount = double.parse(cleaned);

      // If it's a huge number but common for IDR (e.g. 5000000), it's likely rounded.
      // If it looks like it had decimals (last 2 digits), let's assume it might be cents if > 1000
      // Actually, banking apps in ID usually show full amount.
      // If it ends with ",00" or ".00", we should divide by 100 if we didn't remove it.
      // But we removed all non-digits. Let's refine.

      // Better regex for IDR: 1.000.000 -> 1000000
      if (amountStr.contains(',') && amountStr.contains('.')) {
        // Mixed. Assume 1.234,56
        String clean = amountStr.replaceAll('.', '').replaceAll(',', '.');
        originalAmount = double.parse(clean);
      } else if (amountStr.contains(',')) {
        // Comma only. In ID, 1.000 becomes 1000. 1,50 becomes 1.5
        // But many apps use 1,000 as thousands.
        // HEURISTIC: If comma count == 1 and digits after comma == 3, it's thousands.
        List<String> parts = amountStr.split(',');
        if (parts.length == 2 && parts[1].length == 3) {
          originalAmount = double.parse(amountStr.replaceAll(',', ''));
        } else {
          originalAmount = double.parse(amountStr.replaceAll(',', '.'));
        }
      } else if (amountStr.contains('.')) {
        // Dot only. In ID, 1.000 is thousands.
        List<String> parts = amountStr.split('.');
        if (parts.length == 2 && parts[1].length != 3) {
          // Likely decimal (e.g. 1.5)
          originalAmount = double.parse(amountStr);
        } else {
          // Likely thousands (e.g. 1.000 or 1.000.000)
          originalAmount = double.parse(amountStr.replaceAll('.', ''));
        }
      }
    } catch (e) {
      debugPrint('Error parsing amount: $e');
      return null;
    }

    if (originalAmount <= 0) return null;

    return TransactionData(
      amount: originalAmount,
      isIncome: isIncome,
      description: text.length > 50 ? '${text.substring(0, 47)}...' : text,
      sourceApp: getAppName(packageName),
    );
  }
}
