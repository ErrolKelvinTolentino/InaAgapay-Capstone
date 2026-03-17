class MidwifeContext {
  int? midwifeId;
  int? assignedBhcId;
  String? assignedBhcName;
}

class EmergencyContact {
  String? firstName;
  String? middleName;
  String? lastName;
  String? extensionName;
  String? phoneNumber;
  String? emailAddress;
  String? affiliation;
  String? houseNumber;
  String? street;
  String? barangay;
  String? city;
  String? province;

  bool get isValid =>
      (firstName ?? '').trim().isNotEmpty &&
      (lastName ?? '').trim().isNotEmpty &&
      (phoneNumber ?? '').trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'middle_name': middleName,
    'last_name': lastName,
    'extension_name': extensionName,
    'phone_number': phoneNumber,
    'email_address': emailAddress,
    'affiliation': affiliation,
    'house_number': houseNumber,
    'street': street,
    'barangay': barangay,
    'city_municipality': city,
    'province': province,
  };
}

class MedicalConditionEntry {
  MedicalConditionEntry({required this.conditionName});

  String conditionName;
  DateTime? diagnosisDate;
  String status = 'active'; // active | resolved
  String? remarks;

  bool get isActive => status == 'active';

  Map<String, dynamic> toJson() => {
    'condition_name': conditionName,
    'diagnosis_date': _fmtDate(diagnosisDate),
    'status': status,
    'remarks': remarks,
  };
}

class AllergyEntry {
  AllergyEntry({required this.allergen});

  String allergen;
  DateTime? diagnosisDate;
  String status = 'active'; // active | resolved
  String? treatment;
  String? remarks;

  bool get isActive => status == 'active';

  Map<String, dynamic> toJson() => {
    'allergen': allergen,
    'diagnosis_date': _fmtDate(diagnosisDate),
    'status': status,
    'treatment': treatment,
    'remarks': remarks,
  };
}

class PregnancyHistoryEntry {
  PregnancyHistoryEntry({required this.outcome, required this.outcomeDate});

  String outcome; // live_birth | stillbirth | miscarriage | abortion | ectopic
  DateTime outcomeDate;
  bool isOutcomeDateEstimated = false;
  double? gestationalAgeAtEnd;
  String? placeOfDelivery;
  String? deliveryMethod;

  Map<String, dynamic> toJson() => {
    'outcome': outcome,
    'outcome_date': _fmtDate(outcomeDate),
    'is_outcome_date_estimated': isOutcomeDateEstimated,
    'gestational_age_at_end': gestationalAgeAtEnd,
    'place_of_delivery': placeOfDelivery,
    'delivery_method': deliveryMethod,
  };
}

class MotherMedicationEntry {
  MotherMedicationEntry({required this.name});

  String name;
  int? quantity;
  String? frequency;
  DateTime? startDate;
  DateTime? endDate;
  String status = 'active'; // active | completed | stopped

  Map<String, dynamic> toJson() => {
    'mother_medication_name': name,
    'quantity': quantity,
    'frequency': frequency,
    'start_date': _fmtDate(startDate),
    'end_date': _fmtDate(endDate),
    'status': status,
  };
}

class GivenMedicationEntry {
  GivenMedicationEntry({required this.name});

  String name;
  int? quantity;
  DateTime? dateGiven;

  Map<String, dynamic> toJson() => {
    'given_medication_name': name,
    'quantity': quantity,
    'date_given': _fmtDate(dateGiven),
  };
}

class PrenatalCheckInput {
  DateTime checkupDateTime = DateTime.now();
  double? checkupWeight;
  int? bloodPressureSystolic;
  int? bloodPressureDiastolic;
  String? fetalPosition;
  int? fetalHeartBeat;
  String? fetalHeartTone;
  String edema = 'none';
  String? remarks;
  String? tdVaccineDose;
  bool abnormalFetalHeartBeat = false;
  bool abnormalFetalPosition = false;
  double? ageOfGestationWeeks;
  bool missedScheduledCheckups = false;
  DateTime? nextSchedule;
  int? ferrousQuantity;
  int? calciumQuantity;

  final List<MotherMedicationEntry> motherMedications = [];
  final List<GivenMedicationEntry> givenMedications = [];

  Map<String, dynamic> toJson() => {
    'checkup_datetime': _fmtDateTime(checkupDateTime),
    'checkup_weight': checkupWeight,
    'blood_pressure_systolic': bloodPressureSystolic,
    'blood_pressure_diastolic': bloodPressureDiastolic,
    'fetal_position': fetalPosition,
    'fetal_heart_beat': fetalHeartBeat,
    'fetal_heart_tone': fetalHeartTone,
    'abnormal_fetal_heart_beat': abnormalFetalHeartBeat,
    'abnormal_fetal_position': abnormalFetalPosition,
    'edema': edema,
    'remarks': remarks,
    'td_vaccine_dose': tdVaccineDose,
    'age_of_gestation': ageOfGestationWeeks,
    'missed_scheduled_checkups': missedScheduledCheckups,
    'next_schedule': _fmtDate(nextSchedule),
    'mother_medications': motherMedications.map((m) => m.toJson()).toList(),
    'given_medications': [
      if (ferrousQuantity != null && ferrousQuantity! > 0)
        {
          'given_medication_name': 'Ferrous + FA',
          'medicine_name': 'Ferrous + FA',
          'quantity': ferrousQuantity,
          'date_given': _fmtDate(DateTime.now()),
        },
      if (calciumQuantity != null && calciumQuantity! > 0)
        {
          'given_medication_name': 'Calcium',
          'medicine_name': 'Calcium',
          'quantity': calciumQuantity,
          'date_given': _fmtDate(DateTime.now()),
        },
      ...givenMedications.map((g) => g.toJson()),
    ],
  };
}

class AddMotherFormData {
  // ===== ACCOUNT =====
  String? firstName;
  String? middleName;
  String? lastName;
  String? extensionName;
  String? email;
  String? phone;

  // ===== ADDRESS =====
  bool addressSameAsBhc = true;
  String? houseNumber;
  String? street;
  String? barangay;
  String? city;
  String? province;

  // ===== PROFILE =====
  DateTime? birthdate;
  double? heightCm;
  double? weightKg;
  String? bloodType;

  // ===== CONTEXT =====
  final MidwifeContext context = MidwifeContext();

  // ===== EMERGENCY CONTACTS =====
  final List<EmergencyContact> emergencyContacts = [];

  // ===== MEDICAL CONDITIONS =====
  final List<MedicalConditionEntry> medicalConditions = [];

  // ===== ALLERGIES =====
  final List<AllergyEntry> allergies = [];

  // ===== PREGNANCY HISTORY =====
  bool hasPastPregnancy = false;
  final List<PregnancyHistoryEntry> pregnancyHistory = [];

  // ===== CURRENT PREGNANCY =====
  DateTime? lmp;
  DateTime? edd;

  // ===== FIRST PRENATAL =====
  final PrenatalCheckInput firstPrenatal = PrenatalCheckInput();

  // ===== DERIVED =====
  int? get ageYears {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate!.year;
    if (now.month < birthdate!.month ||
        (now.month == birthdate!.month && now.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  int? ageInYears({DateTime? onDate}) {
    if (birthdate == null) return null;
    final refDate = onDate ?? DateTime.now();
    int age = refDate.year - birthdate!.year;
    if (refDate.month < birthdate!.month ||
        (refDate.month == birthdate!.month && refDate.day < birthdate!.day)) {
      age--;
    }
    return age;
  }

  double? get bmi {
    if (heightCm == null || weightKg == null) return null;
    if (heightCm == 0) return null;
    final heightM = heightCm! / 100;
    return double.parse((weightKg! / (heightM * heightM)).toStringAsFixed(1));
  }

  int get activeMedicalConditionCount {
    return medicalConditions.where((c) => c.isActive).length;
  }

  bool get hasActiveAllergy {
    return allergies.any((a) => a.isActive);
  }

  List<PregnancyHistoryEntry> get pastPregnancies {
    return pregnancyHistory;
  }

  int get totalEndedPregnancies {
    return pregnancyHistory.length;
  }

  double? ageOfGestationWeeks({DateTime? onDate}) {
    if (lmp == null) return null;
    final refDate = onDate ?? DateTime.now();
    final diffDays = refDate.difference(lmp!).inDays;
    return diffDays / 7.0;
  }

  String? _addressValue(String? field, {String? fallback}) {
    if (addressSameAsBhc) return fallback;
    return field;
  }

  Map<String, dynamic> toPayload({
    required String pregnancyRiskLevel,
    bool includeFirstPrenatal = true,
    PrenatalCheckInput? prenatalOverride,
  }) {
    return {
      'account': {
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'extension_name': extensionName,
        'phone_number': phone,
        'email_address': email,
      },
      'mother_profile': {
        'birthdate': _fmtDate(birthdate),
        'height': heightCm,
        'weight': weightKg,
        'blood_type': bloodType,
        'assigned_bhc_id': context.assignedBhcId,
        'house_number': houseNumber,
        'street': street,
        'barangay': _addressValue(barangay, fallback: context.assignedBhcName),
        'city_municipality': _addressValue(city, fallback: 'Baliwag'),
        'province': _addressValue(province, fallback: 'Bulacan'),
      },
      'emergency_contacts': emergencyContacts
          .where((e) => e.isValid)
          .map((e) => e.toJson())
          .toList(),
      'medical_conditions': medicalConditions.map((m) => m.toJson()).toList(),
      'allergies': allergies.map((a) => a.toJson()).toList(),
      'pregnancy_history': pregnancyHistory.map((p) => p.toJson()).toList(),
      'current_pregnancy': {
        'last_menstrual_period': _fmtDate(lmp),
        'expected_date_of_delivery': _fmtDate(edd),
        'pregnancy_risk_level': pregnancyRiskLevel,
      },
      'include_first_prenatal': includeFirstPrenatal,
      'first_prenatal_checkup': includeFirstPrenatal
          ? (prenatalOverride ?? firstPrenatal).toJson()
          : null,
    };
  }
}

String? _fmtDate(DateTime? date) {
  if (date == null) return null;
  return date.toIso8601String().split('T').first;
}

String? _fmtDateTime(DateTime? date) {
  if (date == null) return null;
  return date.toIso8601String();
}
