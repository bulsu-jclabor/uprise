import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventModel {
  final String id;
  final String title;
  final String category;
  final String location;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String orgId;
  final String orgName;
  final String description;
  final String audience;
  final int capacity;
  final int slotsLeft;
  final String? proposalId;          // createdFromProposalId alias
  final String? createdFromProposalId;
  final String? orgLogoUrl;
  final String? bannerUrl;           // ADDED – HTTPS URL from Firebase Storage

  EventModel({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.orgId,
    required this.orgName,
    required this.description,
    required this.audience,
    required this.capacity,
    required this.slotsLeft,
    this.proposalId,
    this.createdFromProposalId,
    this.orgLogoUrl,
    this.bannerUrl,                  // ADDED
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = d['date'];
    final dateTime = timestamp is Timestamp
        ? timestamp.toDate()
        : DateTime.tryParse(d['date']?.toString() ?? '') ?? DateTime.now();

    return EventModel(
      id: doc.id,
      title: d['title'] ?? '',
      category: d['category'] ?? 'Other',
      location: d['location'] ?? '',
      date: dateTime,
      startTime: d['startTime'] ?? '',
      endTime: d['endTime'] ?? '',
      orgId: d['orgId'] ?? '',
      orgName: d['orgName'] ?? '',
      description: d['description'] ?? '',
      audience: d['audience'] ?? 'Public',
      capacity: (d['capacity'] as int?) ?? 0,
      slotsLeft: (d['slotsLeft'] as int?) ?? (d['capacity'] as int? ?? 0),
      proposalId: d['createdFromProposalId'] as String?,
      createdFromProposalId: d['createdFromProposalId'] as String?,
      orgLogoUrl: d['logoUrl'] as String?,
      bannerUrl: d['bannerUrl'] as String?,   // ADDED
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category,
    'location': location,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'orgId': orgId,
    'orgName': orgName,
    'description': description,
    'audience': audience,
    'capacity': capacity,
    'slotsLeft': slotsLeft,
    'createdFromProposalId': proposalId,
    'logoUrl': orgLogoUrl,
    'bannerUrl': bannerUrl,          // ADDED
  };

  bool get isPast => date.isBefore(DateTime.now());
  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);
  String get formattedTime => '$startTime – $endTime';
}