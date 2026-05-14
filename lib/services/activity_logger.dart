import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Logs an activity entry to Firestore.
  ///
  /// The `orgId` field is optional, but should be set for organization actions
  /// so the admin audit log can filter and tally org-specific events.
  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    String? orgId,
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final detailsMap = details ?? {};
    final entry = <String, dynamic>{
      'user': user?.email ?? 'Unknown',
      'action': action,
      'module': module,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
      'orgId': orgId ?? (detailsMap['orgId'] is String ? detailsMap['orgId'] as String : '') ?? '',
      'ipAddress': '',
      'details': detailsMap,
    };

    try {
      await _firestore.collection('activity_logs').add(entry);
    } catch (_) {
      // If logging fails, do not stop the main user flow.
    }
  }
}
