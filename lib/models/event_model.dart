import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventModel {
  final String id;
  final String title;
  final String category;
  final String location;
  final DateTime date;          // ⭐ DATE ONLY (from Firebase)
  final String startTime;       // ⭐ TIME ONLY (from Firebase)
  final String endTime;
  final String orgId;
  final String orgName;
  final String description;
  final String audience;
  final int capacity;
  final int slotsLeft;
  final String? proposalId;
  final String? createdFromProposalId;
  final String? orgLogoUrl;
  final String? bannerUrl;

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
    this.bannerUrl,
  });

  // ⭐ GET THE FULL DATE + TIME FOR COUNTDOWN ⭐
  DateTime get fullDateTime {
    try {
      // I-parse ang startTime (e.g., "07:00" or "7:00 AM")
      final timeParts = startTime.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = 0;
      
      if (timeParts.length > 1) {
        // Check if may AM/PM
        if (startTime.toLowerCase().contains('am') || 
            startTime.toLowerCase().contains('pm')) {
          // Handle 12-hour format
          final cleanTime = startTime.replaceAll(RegExp(r'[AP]M', caseSensitive: false), '').trim();
          final parts = cleanTime.split(':');
          hour = int.parse(parts[0]);
          minute = int.parse(parts[1]);
          if (startTime.toLowerCase().contains('pm') && hour < 12) {
            hour += 12;
          }
          if (startTime.toLowerCase().contains('am') && hour == 12) {
            hour = 0;
          }
        } else {
          // 24-hour format
          minute = int.parse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), ''));
        }
      }
      
      return DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
    } catch (e) {
      // Fallback: gamitin ang date lang
      return date;
    }
  }

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
      bannerUrl: d['bannerUrl'] as String?,
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
    'bannerUrl': bannerUrl,
  };

  bool get isPast => fullDateTime.isBefore(DateTime.now());
  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);
  String get formattedTime => '$startTime – $endTime';
}