class AccountModel {
  final int accountId;
  final String email;
  final String accountType;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? extensionName;
  final String? phoneNumber;
  final bool isVerified;
  final String status;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  AccountModel({
    required this.accountId,
    required this.email,
    required this.accountType,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.extensionName,
    this.phoneNumber,
    required this.isVerified,
    required this.status,
    this.lastLoginAt,
    this.createdAt,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      accountId: (json['account_id'] as num).toInt(),
      email: json['email_address'] as String? ?? '',
      accountType: json['account_type'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      middleName: json['middle_name'] as String?,
      lastName: json['last_name'] as String? ?? '',
      extensionName: json['extension_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  String get fullName {
    final parts = [
      firstName,
      if (middleName != null && middleName!.isNotEmpty) middleName!,
      lastName,
      if (extensionName != null && extensionName!.isNotEmpty) extensionName!,
    ];
    return parts.join(' ').trim();
  }

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }
}
