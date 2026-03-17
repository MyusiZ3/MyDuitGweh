import 'package:cloud_firestore/cloud_firestore.dart';

class WalletModel {
  final String id;
  final String walletName;
  final double balance;
  final String type; // "personal" or "colab"
  final List<String> members; // List of UIDs for colab wallets
  final String owner;
  final DateTime createdAt;

  WalletModel({
    required this.id,
    required this.walletName,
    required this.balance,
    required this.type,
    required this.members,
    required this.owner,
    required this.createdAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return WalletModel(
      id: docId ?? json['id'] as String,
      walletName: json['walletName'] as String,
      balance: (json['balance'] as num).toDouble(),
      type: json['type'] as String,
      members: List<String>.from(json['members'] ?? []),
      owner: json['owner'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
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
  }) {
    return WalletModel(
      id: id ?? this.id,
      walletName: walletName ?? this.walletName,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      members: members ?? this.members,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isColab => type == 'colab';
  bool get isPersonal => type == 'personal';
}
