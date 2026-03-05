// lib/models/child.dart
class Child {
  final String id;
  final String name;
  final DateTime birthDate;
  final String gender;
  final DateTime dateAdded;

  Child({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.gender,
    required this.dateAdded,
  });

  // Calculate age in weeks from birth date to now
  int getAgeInWeeks() {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    return (difference.inDays / 7).floor();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate.toIso8601String(),
      'gender': gender,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'],
      name: json['name'],
      birthDate: DateTime.parse(json['birthDate']),
      gender: json['gender'],
      dateAdded: DateTime.parse(json['dateAdded']),
    );
  }
}