class VaccineModel {
  final int vaccineId;
  final String vaccineName;
  final int doseNumber;
  final double recommendedAgeMonths;
  final String targetRecipients;
  final String? notes;

  VaccineModel({
    required this.vaccineId,
    required this.vaccineName,
    required this.doseNumber,
    required this.recommendedAgeMonths,
    required this.targetRecipients,
    this.notes,
  });

  factory VaccineModel.fromJson(Map<String, dynamic> json) {
    return VaccineModel(
      vaccineId: int.parse(json['vaccine_id'].toString()),
      vaccineName: json['vaccine_name'],
      doseNumber: int.parse(json['dose_number'].toString()),
      recommendedAgeMonths:
          double.parse(json['recommended_age_months'].toString()),
      targetRecipients: json['target_recipients'],
      notes: json['notes'],
    );
  }
}
