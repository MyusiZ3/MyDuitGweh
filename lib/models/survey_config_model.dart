class SurveyConfigModel {
  final bool isAvailable;
  final int minTransactions;
  final int minAccountAgeDays;

  SurveyConfigModel({
    required this.isAvailable,
    required this.minTransactions,
    required this.minAccountAgeDays,
  });

  factory SurveyConfigModel.fromJson(Map<String, dynamic> json) {
    return SurveyConfigModel(
      isAvailable: json['isAvailable'] ?? true,
      minTransactions: json['minTransactions'] ?? 5,
      minAccountAgeDays: json['minAccountAgeDays'] ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAvailable': isAvailable,
      'minTransactions': minTransactions,
      'minAccountAgeDays': minAccountAgeDays,
    };
  }

  SurveyConfigModel copyWith({
    bool? isAvailable,
    int? minTransactions,
    int? minAccountAgeDays,
  }) {
    return SurveyConfigModel(
      isAvailable: isAvailable ?? this.isAvailable,
      minTransactions: minTransactions ?? this.minTransactions,
      minAccountAgeDays: minAccountAgeDays ?? this.minAccountAgeDays,
    );
  }
}
