import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // Send a single notification to a specific user
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    String orgId = '',
    Map<String, dynamic>? data,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'orgId': orgId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': data ?? {},
    });
  }

  // Send a notification to all members of an organization
  static Future<void> sendToOrgMembers({
    required String orgId,
    required String title,
    required String body,
    String type = 'announcement',
    Map<String, dynamic>? data,
  }) async {
    final membersSnap = await _db
        .collection('users')
        .where('orgId', isEqualTo: orgId)
        .get();

    final batch = _db.batch();
    for (final doc in membersSnap.docs) {
      final ref = _db.collection('notifications').doc();
      batch.set(ref, {
        'userId': doc.id,
        'orgId': orgId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': data ?? {},
      });
    }
    await batch.commit();
  }

  // Send an event notification to all registered attendees
  static Future<void> sendEventNotification({
    required String eventId,
    required String orgId,
    required String title,
    required String body,
    String type = 'event',
  }) async {
    final attendeesSnap = await _db
        .collection('events')
        .doc(eventId)
        .collection('attendees')
        .get();

    final batch = _db.batch();
    for (final doc in attendeesSnap.docs) {
      final ref = _db.collection('notifications').doc();
      batch.set(ref, {
        'userId': doc.id,
        'orgId': orgId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {'eventId': eventId},
      });
    }
    await batch.commit();
  }

  // Mark a notification as read
  static Future<void> markAsRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read for a user
  static Future<void> markAllAsRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Stream unread notification count for a user
  static Stream<int> unreadCountStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Stream all notifications for a user, newest first
  static Stream<QuerySnapshot> notificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }
}
