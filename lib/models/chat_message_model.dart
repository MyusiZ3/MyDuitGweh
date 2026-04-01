import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? docId}) {
    return ChatMessage(
      id: docId ?? json['id'] ?? '',
      senderUid: json['senderUid'] ?? '',
      senderName: json['senderName'] ?? 'Anonim',
      message: json['message'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'senderName': senderName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
