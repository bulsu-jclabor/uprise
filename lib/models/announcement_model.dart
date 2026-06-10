import 'package:cloud_firestore/cloud_firestore.dart';

class AttachmentBase64 {
  final String name;
  final String base64;
  final String? size;
  const AttachmentBase64({required this.name, required this.base64, this.size});

  Map<String, dynamic> toMap() => {'name': name, 'base64': base64, if (size != null) 'size': size};
}

class AnnouncementModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String orgId;
  final Timestamp timestamp;
  final List<AttachmentBase64> attachmentsBase64;
  final String? imageBase64;
  final bool isPinned;
  final String targetAudience;
  final bool isScheduled;
  final Timestamp? scheduledPublishDate;
  final bool isPublished;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.orgId = '',
    required this.timestamp,
    this.attachmentsBase64 = const [],
    this.imageBase64,
    this.isPinned = false,
    this.targetAudience = 'Members Only',
    this.isScheduled = false,
    this.scheduledPublishDate,
    this.isPublished = true,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    List<AttachmentBase64> attachments = [];
    final attsList = d['attachmentsBase64'] as List?;
    if (attsList != null) {
      attachments = attsList
          .map((a) => AttachmentBase64(
                name: a['name'] ?? '',
                base64: a['base64'] ?? '',
                size: a['size'],
              ))
          .toList();
    }
    return AnnouncementModel(
      id: doc.id,
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? 'Unknown',
      orgId: d['orgId'] ?? '',
      timestamp: d['timestamp'] as Timestamp? ?? Timestamp.now(),
      attachmentsBase64: attachments,
      imageBase64: d['imageBase64'] as String?,
      isPinned: d['pinned'] as bool? ?? false,
      targetAudience: d['targetAudience'] as String? ?? 'Members Only',
      isScheduled: d['isScheduled'] as bool? ?? false,
      scheduledPublishDate: d['scheduledPublishDate'] as Timestamp?,
      isPublished: d['isPublished'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'orgId': orgId,
      'timestamp': timestamp,
      'attachmentsBase64': attachmentsBase64.map((a) => a.toMap()).toList(),
      if (imageBase64 != null) 'imageBase64': imageBase64,
      'pinned': isPinned,
      'targetAudience': targetAudience,
      'isScheduled': isScheduled,
      if (scheduledPublishDate != null) 'scheduledPublishDate': scheduledPublishDate,
      'isPublished': isPublished,
    };
  }
}
