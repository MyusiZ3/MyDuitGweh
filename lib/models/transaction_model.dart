import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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
        return CupertinoIcons.money_dollar;
      case 'Bonus':
        return CupertinoIcons.gift;
      case 'Investasi':
        return CupertinoIcons.graph_circle;
      case 'Freelance':
        return CupertinoIcons.briefcase;
      case 'Hadiah':
        return CupertinoIcons.gift_fill;
      case 'Penjualan':
        return CupertinoIcons.cart;
      case 'Transfer Masuk':
      case 'Transfer Keluar':
        return CupertinoIcons.arrow_right_arrow_left;
      case 'Makanan':
        return CupertinoIcons.cart_fill; // Using cart for food/groceries
      case 'Transportasi':
        return CupertinoIcons.car_detailed;
      case 'Belanja':
        return CupertinoIcons.bag;
      case 'Cicilan':
        return CupertinoIcons.creditcard;
      case 'Hutang':
        return CupertinoIcons.money_dollar_circle;
      case 'Tagihan':
        return CupertinoIcons.doc_text;
      case 'Kesehatan':
        return CupertinoIcons.heart_fill;
      case 'Pendidikan':
        return CupertinoIcons.book;
      case 'Hobi':
        return CupertinoIcons.gamecontroller;
      case 'Pajak':
        return CupertinoIcons.building_2_fill;
      case 'Asuransi':
        return CupertinoIcons.shield_fill;
      case 'Zakat/Donasi':
        return CupertinoIcons.heart_circle;
      case 'Langganan':
        return CupertinoIcons.play_rectangle;
      case 'Hiburan':
        return CupertinoIcons.tv;
      default:
        return CupertinoIcons.ellipsis_circle;
    }
  }
}
