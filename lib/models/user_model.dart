import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String studentId;
  final String role;
  final String? profilePicture;
  final String? photoUrl;
  final bool isFirstLogin;
  final bool mustChangePassword;
  final String? organizationId;
  final String? orgId;
  final String? mobile;
  final String? address;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.studentId = '',
    required this.role,
    this.profilePicture,
    this.photoUrl,
    this.isFirstLogin = false,
    this.mustChangePassword = false,
    this.organizationId,
    this.orgId,
    this.mobile,
    this.address,
    required this.createdAt,
  });

  bool get needsPasswordChange =>
      isFirstLogin || mustChangePassword;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'studentId': studentId,
      'role': role,
      if (profilePicture != null) 'profilePicture': profilePicture,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'isFirstLogin': isFirstLogin,
      'mustChangePassword': mustChangePassword,
      if (organizationId != null) 'organizationId': organizationId,
      if (orgId != null) 'orgId': orgId,
      if (mobile != null) 'mobile': mobile,
      if (address != null) 'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      studentId: map['studentId'] ?? '',
      role: map['role'] ?? 'guest',
      profilePicture: map['profilePicture'] as String?,
      photoUrl: map['photoUrl'] as String?,
      isFirstLogin: map['isFirstLogin'] as bool? ?? false,
      mustChangePassword: (map['mustChangePassword'] as bool? ?? false) ||
          (map['needsPasswordChange'] as bool? ?? false) ||
          (map['firstLogin'] as bool? ?? false),
      organizationId: map['organizationId'] as String?,
      orgId: map['orgId'] as String?,
      mobile: map['mobile'] as String?,
      address: map['address'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}