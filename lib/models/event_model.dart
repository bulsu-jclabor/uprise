import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String orgId;
  final String orgName;
  final String title;
  final String description;
  final String location;
  final int capacity;
  final int slotsLeft;
  final String startTime;
  final String endTime;
  final String category;
  final String guestSpeaker;
  final List<String> resources;
  final List<String> labPreparation;
  final List<String> tags;
  final DateTime date;
  final String status;
  final bool isPublic;
  final String? bannerUrl;
  final String? logoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EventModel({
    required this.id,
    required this.orgId,
    this.orgName = '',
    required this.title,
    this.description = '',
    this.location = '',
    this.capacity = 0,
    this.slotsLeft = 0,
    this.startTime = '',
    this.endTime = '',
    this.category = 'Other',
    this.guestSpeaker = '',
    this.resources = const [],
    this.labPreparation = const [],
    this.tags = const [],
    required this.date,
    this.status = 'pending',
    this.isPublic = true,
    this.bannerUrl,
    this.logoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    List<String> toList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }
    DateTime toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }
    return EventModel(
      id: doc.id,
      orgId: (d['orgId'] ?? '').toString(),
      orgName: (d['orgName'] ?? '').toString(),
      title: d['title'] ?? '',
      description: d['description'] ?? '',
      location: d['location'] ?? '',
      capacity: (d['capacity'] as num?)?.toInt() ?? 0,
      slotsLeft: (d['slotsLeft'] as num?)?.toInt() ?? (d['capacity'] as num?)?.toInt() ?? 0,
      startTime: d['startTime'] ?? '',
      endTime: d['endTime'] ?? '',
      category: d['category'] ?? 'Other',
      guestSpeaker: d['guestSpeaker'] ?? '',
      resources: toList(d['resources']),
      labPreparation: toList(d['labPreparation']),
      tags: toList(d['tags']),
      date: toDate(d['date']),
      status: (d['status'] ?? 'pending').toString().toLowerCase(),
      isPublic: d['isPublic'] ?? true,
      bannerUrl: d['bannerUrl'] as String?,
      logoUrl: d['logoUrl'] as String?,
      createdAt: d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null,
      updatedAt: d['updatedAt'] is Timestamp ? (d['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'orgName': orgName,
      'title': title,
      'description': description,
      'location': location,
      'capacity': capacity,
      'slotsLeft': slotsLeft,
      'startTime': startTime,
      'endTime': endTime,
      'category': category,
      'guestSpeaker': guestSpeaker,
      'resources': resources,
      'labPreparation': labPreparation,
      'tags': tags,
      'date': Timestamp.fromDate(date),
      'status': status,
      'isPublic': isPublic,
      if (bannerUrl != null) 'bannerUrl': bannerUrl,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };
  }
}
