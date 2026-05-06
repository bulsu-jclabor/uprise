// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';  // ← IDAGDAG ITO

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String studentId;
  final String role;
  final String? profilePicture;
  final bool isFirstLogin;
  final String? organizationId;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.studentId,
    required this.role,
    this.profilePicture,
    required this.isFirstLogin,
    this.organizationId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'studentId': studentId,
      'role': role,
      'profilePicture': profilePicture,
      'isFirstLogin': isFirstLogin,
      'organizationId': organizationId,
      'createdAt': createdAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      studentId: map['studentId'] ?? '',
      role: map['role'] ?? 'guest',
      profilePicture: map['profilePicture'],
      isFirstLogin: map['isFirstLogin'] ?? false,
      organizationId: map['organizationId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}