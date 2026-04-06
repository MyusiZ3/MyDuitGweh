import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String? id;
  final String userId;
  final double rating;
  final String category;
  final String comment;
  final String appVersion;
  final String deviceInfo;
  final DateTime createdAt;

  FeedbackModel({
    this.id,
    required this.userId,
    required this.rating,
    required this.category,
    required this.comment,
    required this.appVersion,
    required this.deviceInfo,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    return FeedbackModel(
      id: docId ?? json['id'],
      userId: json['userId'] ?? '',
      rating: (json['rating'] ?? 0.0).toDouble(),
      category: json['category'] ?? 'General',
      comment: json['comment'] ?? '',
      appVersion: json['appVersion'] ?? 'unknown',
      deviceInfo: json['deviceInfo'] ?? 'unknown',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'rating': rating,
      'category': category,
      'comment': comment,
      'appVersion': appVersion,
      'deviceInfo': deviceInfo,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
