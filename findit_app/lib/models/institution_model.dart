class InstitutionModel {
  final String id;
  final String name;
  final String status;
  final String type;
  final String? contactEmail;
  final String? address;
  final String? phone;

  const InstitutionModel({
    required this.id,
    required this.name,
    required this.status,
    this.type = '',
    this.contactEmail,
    this.address,
    this.phone,
  });

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    return InstitutionModel(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      type: json['type'] as String? ?? '',
      contactEmail: json['contactEmail'] as String? ?? json['email'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
    );
  }
}
