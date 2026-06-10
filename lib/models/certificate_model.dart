import 'package:cloud_firestore/cloud_firestore.dart';

class CertificateModel {
  final String id;
  final String certificateId;
  final String eventName;
  final String organization;
  final String orgId;
  final String type;
  final DateTime date;
  final int recipients;
  final String status;
  final String templateType;
  final String? templateFileUrl;
  final String? recipientId;
  final DateTime? createdAt;

  const CertificateModel({
    required this.id,
    required this.certificateId,
    required this.eventName,
    required this.organization,
    this.orgId = '',
    this.type = 'Participation',
    required this.date,
    this.recipients = 1,
    this.status = 'draft',
    this.templateType = 'Formal Academic',
    this.templateFileUrl,
    this.recipientId,
    this.createdAt,
  });

  factory CertificateModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return CertificateModel(
      id: doc.id,
      certificateId: 'CERT-${doc.id.substring(0, 4).toUpperCase()}',
      eventName: d['eventName'] as String? ?? d['certificateName'] as String? ?? 'Untitled',
      organization: d['organization'] as String? ?? 'N/A',
      orgId: d['orgId'] as String? ?? '',
      type: d['type'] as String? ?? 'Participation',
      date: (d['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipients: (d['recipients'] as num?)?.toInt() ?? 1,
      status: d['status'] as String? ?? 'draft',
      templateType: d['templateType'] as String? ?? 'Formal Academic',
      templateFileUrl: d['templateFileUrl'] as String?,
      recipientId: d['recipientId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventName': eventName,
      'organization': organization,
      'orgId': orgId,
      'type': type,
      'issuedAt': Timestamp.fromDate(date),
      'recipients': recipients,
      'status': status,
      'templateType': templateType,
      if (templateFileUrl != null) 'templateFileUrl': templateFileUrl,
      if (recipientId != null) 'recipientId': recipientId,
    };
  }
}
