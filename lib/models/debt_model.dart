import 'package:cloud_firestore/cloud_firestore.dart';

class DebtModel {
  final String id;
  final String type; // 'utang' (payable/debt) or 'piutang' (receivable)
  final String title; // Name of person or purpose
  final double totalAmount;
  final double paidAmount;
  final String status; // 'active', 'completed'
  final DateTime createdAt;
  final DateTime? dueDate;
  final String createdBy;
  final String? walletId; // The wallet associated with the initial transaction

  DebtModel({
    required this.id,
    required this.type,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
    this.dueDate,
    required this.createdBy,
    this.walletId,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return DebtModel(
      id: docId ?? json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'utang',
      title: json['title'] as String? ?? 'Tanpa Judul',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'active',
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      dueDate: json['dueDate'] != null
          ? (json['dueDate'] as Timestamp).toDate()
          : null,
      createdBy: json['createdBy'] as String? ?? '',
      walletId: json['walletId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      'createdBy': createdBy,
      if (walletId != null) 'walletId': walletId,
    };
  }

  double get remainingAmount => totalAmount - paidAmount;
  bool get isUtang => type == 'utang';
  bool get isPiutang => type == 'piutang';

  DebtModel copyWith({
    String? id,
    String? type,
    String? title,
    double? totalAmount,
    double? paidAmount,
    String? status,
    DateTime? createdAt,
    DateTime? dueDate,
    String? createdBy,
    String? walletId,
  }) {
    return DebtModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      walletId: walletId ?? this.walletId,
    );
  }
}
