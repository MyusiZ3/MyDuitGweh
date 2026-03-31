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

  factory TransactionModel.fromJson(Map<String, dynamic> json, {String? docId}) {
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
    'Freelance',
    'Investasi',
    'Hadiah',
    'Transfer Masuk',
    'Lainnya',
  ];

  static const List<String> expenseCategories = [
    'Makanan',
    'Transportasi',
    'Belanja',
    'Hiburan',
    'Tagihan',
    'Kesehatan',
    'Pendidikan',
    'Transfer Keluar',
    'Lainnya',
  ];

  static List<String> getCategoriesForType(String type) {
    return type == 'income' ? incomeCategories : expenseCategories;
  }

  static IconData getIconForCategory(String category) {
    switch (category) {
      case 'Gaji':
        return Icons.account_balance_wallet;
      case 'Freelance':
        return Icons.work_outline;
      case 'Investasi':
        return Icons.trending_up;
      case 'Hadiah':
        return Icons.card_giftcard;
      case 'Transfer Masuk':
      case 'Transfer Keluar':
        return Icons.swap_horiz;
      case 'Makanan':
        return Icons.restaurant;
      case 'Transportasi':
        return Icons.directions_car_outlined;
      case 'Belanja':
        return Icons.shopping_bag_outlined;
      case 'Hiburan':
        return Icons.movie_outlined;
      case 'Tagihan':
        return Icons.receipt_long_outlined;
      case 'Kesehatan':
        return Icons.local_hospital_outlined;
      case 'Pendidikan':
        return Icons.school_outlined;
      default:
        return Icons.more_horiz;
    }
  }
}
