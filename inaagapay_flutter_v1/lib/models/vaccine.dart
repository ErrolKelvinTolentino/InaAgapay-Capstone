class Vaccine {
  final int vaccineId;
  final String name;
  final int dose;
  final double recommendedAge;

  Vaccine({
    required this.vaccineId,
    required this.name,
    required this.dose,
    required this.recommendedAge,
  });

  factory Vaccine.fromJson(Map<String, dynamic> json) {
    return Vaccine(
      vaccineId: int.parse(json['vaccine_id']),
      name: json['vaccine_name'],
      dose: int.parse(json['dose_number']),
      recommendedAge: double.parse(json['recommended_age_months']),
    );
  }

  String get displayName => '$name (Dose $dose)';
}
