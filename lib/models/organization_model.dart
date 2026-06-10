import 'package:cloud_firestore/cloud_firestore.dart';

class OrganizationModel {
  final String id;
  final String name;
  final String shortName;
  final String email;
  final String description;
  final String logoUrl;
  final String facebook;
  final String instagram;
  final String twitter;
  final String gmail;
  final String adviserName;
  final String adviserEmail;
  final String adviserPhone;
  final String adviserPhotoUrl;
  final String adviserTitle;
  final List<Map<String, dynamic>> officers;
  final DateTime? createdAt;

  const OrganizationModel({
    required this.id,
    required this.name,
    this.shortName = '',
    required this.email,
    this.description = '',
    this.logoUrl = '',
    this.facebook = '',
    this.instagram = '',
    this.twitter = '',
    this.gmail = '',
    this.adviserName = '',
    this.adviserEmail = '',
    this.adviserPhone = '',
    this.adviserPhotoUrl = '',
    this.adviserTitle = '',
    this.officers = const [],
    this.createdAt,
  });

  factory OrganizationModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return OrganizationModel(
      id: doc.id,
      name: d['name'] ?? '',
      shortName: d['shortName'] ?? '',
      email: d['email'] ?? '',
      description: d['description'] ?? '',
      logoUrl: d['logoUrl'] ?? '',
      facebook: d['facebook'] ?? '',
      instagram: d['instagram'] ?? '',
      twitter: d['twitter'] ?? '',
      gmail: d['gmail'] ?? '',
      adviserName: d['adviserName'] ?? '',
      adviserEmail: d['adviserEmail'] ?? '',
      adviserPhone: d['adviserPhone'] ?? '',
      adviserPhotoUrl: d['adviserPhotoUrl'] ?? '',
      adviserTitle: d['adviserTitle'] ?? '',
      officers: List<Map<String, dynamic>>.from(d['officers'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'shortName': shortName,
      'email': email,
      'description': description,
      'logoUrl': logoUrl,
      'facebook': facebook,
      'instagram': instagram,
      'twitter': twitter,
      'gmail': gmail,
      'adviserName': adviserName,
      'adviserEmail': adviserEmail,
      'adviserPhone': adviserPhone,
      'adviserPhotoUrl': adviserPhotoUrl,
      'adviserTitle': adviserTitle,
      'officers': officers,
    };
  }
}
