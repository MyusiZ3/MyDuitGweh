import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionModel {
  final String id;
  final String name;
  final double amount;
  final int dueDay; // 1 - 31
  final String category; // e.g. 'Tagihan', 'Hiburan'
  final String walletId; // Default wallet to charge
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;
  final List<String> paidMonths; // list of 'YYYY-MM' strings

  SubscriptionModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.category,
    required this.walletId,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
    required this.paidMonths,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return SubscriptionModel(
      id: docId ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Tanpa Nama',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      dueDay: json['dueDay'] as int? ?? 1,
      category: json['category'] as String? ?? 'Tagihan',
      walletId: json['walletId'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      paidMonths: List<String>.from(json['paidMonths'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'dueDay': dueDay,
      'category': category,
      'walletId': walletId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'paidMonths': paidMonths,
    };
  }

  bool isPaidForMonth(String monthStr) {
    return paidMonths.contains(monthStr);
  }

  SubscriptionModel copyWith({
    String? id,
    String? name,
    double? amount,
    int? dueDay,
    String? category,
    String? walletId,
    String? createdBy,
    DateTime? createdAt,
    bool? isActive,
    List<String>? paidMonths,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDay: dueDay ?? this.dueDay,
      category: category ?? this.category,
      walletId: walletId ?? this.walletId,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      paidMonths: paidMonths ?? this.paidMonths,
    );
  }
}
