// lib/models/growth_record.dart
class GrowthRecord {
  final String id;
  final String childId;
  final DateTime dateRecorded;
  final int ageInWeeks;
  final double weight;
  final double height;
  final double bmi;
  final double weightZScore;
  final double heightZScore;
  final double bmiZScore;
  final String weightClassification;
  final String heightClassification;
  final String bmiClassification;

  GrowthRecord({
    required this.id,
    required this.childId,
    required this.dateRecorded,
    required this.ageInWeeks,
    required this.weight,
    required this.height,
    required this.bmi,
    required this.weightZScore,
    required this.heightZScore,
    required this.bmiZScore,
    required this.weightClassification,
    required this.heightClassification,
    required this.bmiClassification,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childId': childId,
      'dateRecorded': dateRecorded.toIso8601String(),
      'ageInWeeks': ageInWeeks,
      'weight': weight,
      'height': height,
      'bmi': bmi,
      'weightZScore': weightZScore,
      'heightZScore': heightZScore,
      'bmiZScore': bmiZScore,
      'weightClassification': weightClassification,
      'heightClassification': heightClassification,
      'bmiClassification': bmiClassification,
    };
  }

  factory GrowthRecord.fromJson(Map<String, dynamic> json) {
    return GrowthRecord(
      id: json['id'],
      childId: json['childId'],
      dateRecorded: DateTime.parse(json['dateRecorded']),
      ageInWeeks: json['ageInWeeks'],
      weight: json['weight'],
      height: json['height'],
      bmi: json['bmi'],
      weightZScore: json['weightZScore'],
      heightZScore: json['heightZScore'],
      bmiZScore: json['bmiZScore'],
      weightClassification: json['weightClassification'],
      heightClassification: json['heightClassification'],
      bmiClassification: json['bmiClassification'],
    );
  }
}