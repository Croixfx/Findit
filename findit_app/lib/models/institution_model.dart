class InstitutionModel {
  final String id;
  final String name;
  final String status;
  final String? contactEmail;

  const InstitutionModel({
    required this.id,
    required this.name,
    required this.status,
    this.contactEmail,
  });

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    return InstitutionModel(
      id: json['_id'] as String? ?? json['id'] as String,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      contactEmail:
          json['contactEmail'] as String? ?? json['email'] as String?,
    );
  }
}
