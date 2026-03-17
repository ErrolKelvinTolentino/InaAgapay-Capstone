class GreetingModel {
  final String role;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? extensionName;
  final String? bhcName;

  GreetingModel({
    required this.role,
    this.firstName,
    this.middleName,
    this.lastName,
    this.extensionName,
    this.bhcName,
  });

  factory GreetingModel.fromJson(Map<String, dynamic> json) {
    return GreetingModel(
      role: (json['role'] ?? '').toString(),
      firstName: json['first_name']?.toString(),
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString(),
      extensionName: json['extension_name']?.toString(),
      bhcName: json['bhc_name']?.toString(),
    );
  }

  /// Builds full name safely
  String get displayName {
    final parts = [firstName, middleName, lastName, extensionName];

    return parts
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim())
        .join(' ');
  }

  /// Human-readable role
  String get roleLabel {
    switch (role) {
      case 'midwife':
        return 'Midwife';
      case 'mother':
        return 'Mother';
      case 'admin':
        return 'Admin';
      default:
        return 'User';
    }
  }
}
