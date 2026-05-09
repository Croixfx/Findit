class UserModel {
  final String id;
  final String firebaseUid;
  final String email;
  final String fullName;
  final String role;
  final String? institutionId;
  final String? fcmToken;

  const UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.fullName,
    required this.role,
    this.institutionId,
    this.fcmToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // /auth/me returns institution as a populated object; handle object, plain ID, or null
    String? institutionId;
    final inst = json['institution'];
    if (inst is Map) {
      institutionId = inst['_id'] as String? ?? inst['id'] as String?;
    } else if (inst is String && inst.isNotEmpty) {
      institutionId = inst;
    }
    institutionId ??= json['institutionId'] as String?;
    institutionId ??= json['institution_id'] as String?;

    return UserModel(
      id: json['_id'] as String? ?? json['id'] as String,
      firebaseUid: json['firebaseUid'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      role: json['role'] as String,
      institutionId: institutionId,
      fcmToken: json['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebaseUid': firebaseUid,
      'email': email,
      'fullName': fullName,
      'role': role,
      if (institutionId != null) 'institutionId': institutionId,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }
}
