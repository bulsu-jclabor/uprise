import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHelper {
  // Respects the recipient's `users/{uid}/settings/notifications` document
  // (the same doc org_settings.dart / student settings write to). Users who
  // never opened settings have no doc yet, so default to enabled.
  static Future<bool> _isEnabledFor(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('notifications')
          .get();
      final data = doc.data();
      if (data == null) return true;
      return (data['push_notifications'] ?? true) as bool;
    } catch (_) {
      return true;
    }
  }

  static Future<void> createNotification({
    required String userId,
    required String orgId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    if (!await _isEnabledFor(userId)) return;
    await FirebaseFirestore.instance.collection('notifications').add({
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
}