import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransactionModel {
  final String id;
  final String walletId;
  final double amount;
  final String type; // "income" or "expense"
  final String category;
  final String note;
  final String createdBy;
  final String createdByName;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.type,
    required this.category,
    required this.note,
    required this.createdBy,
    required this.createdByName,
    required this.date,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json,
      {String? docId}) {
    return TransactionModel(
      id: docId ?? json['id'] as String,
      walletId: json['walletId'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      category: json['category'] as String,
      note: json['note'] as String? ?? '',
      createdBy: json['createdBy'] as String,
      createdByName: json['createdByName'] as String? ?? 'Teman Kamu',
      date: (json['date'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'amount': amount,
      'type': type,
      'category': category,
      'note': note,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'date': Timestamp.fromDate(date),
    };
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  TransactionModel copyWith({
    String? id,
    String? walletId,
    double? amount,
    String? type,
    String? category,
    String? note,
    String? createdBy,
    String? createdByName,
    DateTime? date,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      date: date ?? this.date,
    );
  }
}

class TransactionCategory {
  static const List<String> incomeCategories = [
    'Gaji',
    'Bonus',
    'Investasi',
    'Freelance',
    'Hadiah',
    'Penjualan',
    'Transfer Masuk',
    'Lainnya',
  ];

  static const List<String> expenseCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Cicilan',
    'Hutang',
    'Tagihan',
    'Kesehatan',
    'Pendidikan',
    'Hobi',
    'Pajak',
    'Asuransi',
    'Zakat/Donasi',
    'Langganan',
    'Hiburan',
    'Transfer Keluar',
    'Lainnya',
  ];

  static List<String> getCategoriesForType(String type) {
    return type == 'income' ? incomeCategories : expenseCategories;
  }

  static IconData getIconForCategory(String category) {
    switch (category) {
      case 'Gaji':
        return Icons.payments_outlined;
      case 'Bonus':
        return Icons.auto_awesome_outlined;
      case 'Investasi':
        return Icons.trending_up_rounded;
      case 'Freelance':
        return Icons.work_outline_rounded;
      case 'Hadiah':
        return Icons.card_giftcard_rounded;
      case 'Penjualan':
        return Icons.storefront_rounded;
      case 'Transfer Masuk':
      case 'Transfer Keluar':
        return Icons.swap_horiz_rounded;
      case 'Makanan':
        return Icons.restaurant_rounded;
      case 'Transportasi':
        return Icons.directions_car_rounded;
      case 'Belanja':
        return Icons.shopping_bag_outlined;
      case 'Cicilan':
        return Icons.credit_card_rounded;
      case 'Hutang':
        return Icons.money_off_rounded;
      case 'Tagihan':
        return Icons.receipt_long_rounded;
      case 'Kesehatan':
        return Icons.local_hospital_rounded;
      case 'Pendidikan':
        return Icons.school_rounded;
      case 'Hobi':
        return Icons.sports_esports_rounded;
      case 'Pajak':
        return Icons.account_balance_outlined;
      case 'Asuransi':
        return Icons.verified_user_outlined;
      case 'Zakat/Donasi':
        return Icons.volunteer_activism_rounded;
      case 'Langganan':
        return Icons.subscriptions_outlined;
      case 'Hiburan':
        return Icons.movie_outlined;
      default:
        return Icons.more_horiz_rounded;
    }
  }
}
