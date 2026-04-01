import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String id;
  final String walletName;
  final double balance;
  final String type; // "personal", "colab", "debt"
  final List<String> members; // List of UIDs for colab wallets
  final String owner;
  final DateTime createdAt;
  final String? inviteCode;
  final String? debtorName;
  final String? debtorPhone;
  final String? debtType; // "payable" (Hutang), "receivable" (Piutang)

  WalletModel({
    required this.id,
    required this.walletName,
    required this.balance,
    required this.type,
    required this.members,
    required this.owner,
    required this.createdAt,
    this.inviteCode,
    this.debtorName,
    this.debtorPhone,
    this.debtType,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return WalletModel(
      id: docId ?? json['id'] as String? ?? '',
      walletName: json['walletName'] as String? ?? 'Unnamed Wallet',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'personal',
      members: List<String>.from(json['members'] ?? []),
      owner: json['owner'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inviteCode: json['inviteCode'] as String?,
      debtorName: json['debtorName'] as String?,
      debtorPhone: json['debtorPhone'] as String?,
      debtType: json['debtType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletName': walletName,
      'balance': balance,
      'type': type,
      'members': members,
      'owner': owner,
      'createdAt': Timestamp.fromDate(createdAt),
      'inviteCode': inviteCode,
      'debtorName': debtorName,
      'debtorPhone': debtorPhone,
      'debtType': debtType,
    };
  }

  WalletModel copyWith({
    String? id,
    String? walletName,
    double? balance,
    String? type,
    List<String>? members,
    String? owner,
    DateTime? createdAt,
    String? inviteCode,
    String? debtorName,
    String? debtorPhone,
    String? debtType,
  }) {
    return WalletModel(
      id: id ?? this.id,
      walletName: walletName ?? this.walletName,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      members: members ?? this.members,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
      inviteCode: inviteCode ?? this.inviteCode,
      debtorName: debtorName ?? this.debtorName,
      debtorPhone: debtorPhone ?? this.debtorPhone,
      debtType: debtType ?? this.debtType,
    );
  }

  bool get isColab => type == 'colab';
  bool get isPersonal => type == 'personal';
  bool get isDebt => type == 'debt';
}
