import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHelper {
  static Future<void> createNotification({
    required String userId,
    required String orgId,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
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