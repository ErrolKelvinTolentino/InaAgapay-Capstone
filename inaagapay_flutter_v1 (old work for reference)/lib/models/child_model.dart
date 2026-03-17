class ChildModel {
  final int id;
  final String fullName;
  final DateTime? birthdate;

  ChildModel({
    required this.id,
    required this.fullName,
    this.birthdate,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    final middle = json['middle_name'] ?? '';
    final ext = json['extension_name'] ?? '';

    final name = [
      json['first_name'],
      middle.isNotEmpty ? '$middle.' : null,
      json['last_name'],
      ext,
    ].where((e) => e != null && e.toString().isNotEmpty).join(' ');

    return ChildModel(
      id: json['child_id'],
      fullName: name,
      birthdate: json['birthdate'] != null
          ? DateTime.parse(json['birthdate'])
          : null,
    );
  }

  String get ageText {
    if (birthdate == null) return 'Age unknown';

    final now = DateTime.now();
    int years = now.year - birthdate!.year;
    int months = now.month - birthdate!.month;

    if (months < 0) {
      years--;
      months += 12;
    }

    return '$years years $months months old';
  }
}
