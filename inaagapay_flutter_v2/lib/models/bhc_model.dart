class BhcModel {
  final int bhcId;
  final String bhcName;

  BhcModel({required this.bhcId, required this.bhcName});

  factory BhcModel.fromJson(Map<String, dynamic> json) {
    return BhcModel(
      bhcId: (json['bhc_id'] as num).toInt(),
      bhcName: json['bhc_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'bhc_id': bhcId, 'bhc_name': bhcName};
}
