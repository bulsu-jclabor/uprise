import 'package:cloud_firestore/cloud_firestore.dart';

class OfficerModel {
  final String id;
  final String name;
  final String position;
  final String email;
  final String phone;
  final int positionRank;
  final bool isCaptain;
  final String photoUrl;

  const OfficerModel({
    required this.id,
    required this.name,
    required this.position,
    this.email = '',
    this.phone = '',
    this.positionRank = 0,
    this.isCaptain = false,
    this.photoUrl = '',
  });

  factory OfficerModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return OfficerModel(
      id: doc.id,
      name: d['name'] ?? '',
      position: d['position'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      positionRank: (d['positionRank'] as num?)?.toInt() ?? 0,
      isCaptain: d['isCaptain'] as bool? ?? false,
      photoUrl: d['photoUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'position': position,
      'email': email,
      'phone': phone,
      'positionRank': positionRank,
      'isCaptain': isCaptain,
      'photoUrl': photoUrl,
    };
  }
}
