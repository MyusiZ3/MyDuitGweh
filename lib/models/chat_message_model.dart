import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String message;
  final DateTime timestamp;
  final bool isEdited;
  final bool isDeleted;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.timestamp,
    this.isEdited = false,
    this.isDeleted = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? docId}) {
    return ChatMessage(
      id: docId ?? json['id'] ?? '',
      senderUid: json['senderUid'] ?? '',
      senderName: json['senderName'] ?? 'Anonim',
      message: json['message'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEdited: json['isEdited'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isEdited': isEdited,
      'isDeleted': isDeleted,
    };
  }

  /// Check if message can be unsent (within 15 minutes)
  bool get canUnsend {
    final diff = DateTime.now().difference(timestamp);
    return diff.inMinutes < 15;
  }
}
