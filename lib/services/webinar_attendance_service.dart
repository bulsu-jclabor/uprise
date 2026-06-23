// Rotating-code attendance for online events (webinars), as a counterpart to
// the QR-scan flow used for face-to-face events.
//
// Reuses the same `events/{eventDocId}/attendances` collection and field
// names (`studentId`, `studentName`, `status`, `timestamp`, ...) that
// org_attendance_qr.dart's QR/manual flow already writes to, so a webinar
// check-in shows up in the exact same attendance table/exports — just with
// `method: 'webinar_code'` instead of `'qr'`/`'manual'`. Two new
// subcollections support the rotating-code mechanism itself:
//
//   events/{eventDocId}/webinarSession/current   — session state (single doc)
//   events/{eventDocId}/attendanceCodes          — one doc per rotation
//   events/{eventDocId}/codeSubmissions          — audit log of every
//                                                   submission attempt,
//                                                   successful or not
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebinarAttendanceService {
  static final Random _rng = Random.secure();

  static String generateCode({int length = 6}) {
    // Excludes visually ambiguous characters (0/O, 1/I) since this gets read
    // off a screen and typed back in.
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    return List.generate(length, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  static DocumentReference<Map<String, dynamic>> _sessionRef(String eventDocId) =>
      FirebaseFirestore.instance.collection('events').doc(eventDocId).collection('webinarSession').doc('current');

  static CollectionReference<Map<String, dynamic>> _codesRef(String eventDocId) =>
      FirebaseFirestore.instance.collection('events').doc(eventDocId).collection('attendanceCodes');

  static CollectionReference<Map<String, dynamic>> _submissionsRef(String eventDocId) =>
      FirebaseFirestore.instance.collection('events').doc(eventDocId).collection('codeSubmissions');

  static Stream<DocumentSnapshot<Map<String, dynamic>>> sessionStream(String eventDocId) =>
      _sessionRef(eventDocId).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> codeStream(String eventDocId, String type) => _codesRef(eventDocId)
      .where('type', isEqualTo: type)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> submissionsStream(String eventDocId) =>
      _submissionsRef(eventDocId).orderBy('timestamp', descending: true).limit(50).snapshots();

  // ── Organizer: session lifecycle ──────────────────────────────────────────

  static Future<void> startSession({
    required String eventDocId,
    required String startedBy,
    required int intervalMinutes,
    required bool requireCheckOut,
  }) async {
    await _sessionRef(eventDocId).set({
      'isActive': true,
      'phase': 'checkin',
      'intervalMinutes': intervalMinutes,
      'requireCheckOut': requireCheckOut,
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'startedBy': startedBy,
    });
    await rotateCode(eventDocId, 'checkin', intervalMinutes);
  }

  static Future<void> rotateCode(String eventDocId, String type, int intervalMinutes) async {
    final now = DateTime.now();
    await _codesRef(eventDocId).add({
      'code': generateCode(),
      'type': type,
      'startsAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(Duration(minutes: intervalMinutes))),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> startCheckOutPhase(String eventDocId, int intervalMinutes) async {
    await _sessionRef(eventDocId).update({'phase': 'checkout'});
    await rotateCode(eventDocId, 'checkout', intervalMinutes);
  }

  static Future<void> endSession(String eventDocId) async {
    await _sessionRef(eventDocId).update({'isActive': false, 'endedAt': FieldValue.serverTimestamp()});
  }

  // ── Student: submit a code ────────────────────────────────────────────────
  //
  // Returns one of: 'success', 'session_inactive', 'no_active_code',
  // 'expired', 'invalid_code', 'duplicate', 'not_checked_in',
  // 'not_registered', 'error'. Every attempt is recorded to codeSubmissions
  // regardless of outcome, so organizers can audit failed attempts too.
  static Future<String> submitCode({
    required String eventDocId,
    required String studentUid,
    required String submittedCode,
    required String type, // 'checkin' | 'checkout'
  }) async {
    final cleaned = submittedCode.trim().toUpperCase();
    String result;
    try {
      final sessionSnap = await _sessionRef(eventDocId).get();
      final session = sessionSnap.data();
      if (session == null || session['isActive'] != true || session['phase'] != type) {
        result = 'session_inactive';
      } else {
        final codesSnap =
            await _codesRef(eventDocId).where('type', isEqualTo: type).orderBy('createdAt', descending: true).limit(1).get();
        if (codesSnap.docs.isEmpty) {
          result = 'no_active_code';
        } else {
          final codeData = codesSnap.docs.first.data();
          final now = DateTime.now();
          final startsAt = (codeData['startsAt'] as Timestamp).toDate();
          final expiresAt = (codeData['expiresAt'] as Timestamp).toDate();
          if (now.isBefore(startsAt) || now.isAfter(expiresAt)) {
            result = 'expired';
          } else if ((codeData['code'] as String).toUpperCase() != cleaned) {
            result = 'invalid_code';
          } else {
            result = await _recordAttendance(eventDocId, studentUid, type);
          }
        }
      }
    } catch (_) {
      result = 'error';
    }

    String studentName = 'Unknown';
    String studentEmail = '';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(studentUid).get();
      final d = userDoc.data();
      if (d != null) {
        studentName = (d['name'] ?? d['email'] ?? 'Unknown').toString();
        studentEmail = (d['email'] ?? '').toString();
      }
    } catch (_) {}

    await _submissionsRef(eventDocId).add({
      'studentId': studentUid,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'submittedCode': cleaned,
      'type': type,
      'result': result,
      'timestamp': FieldValue.serverTimestamp(),
    });

    return result;
  }

  static Future<String> _recordAttendance(String eventDocId, String studentUid, String type) async {
    final attendances = FirebaseFirestore.instance.collection('events').doc(eventDocId).collection('attendances');

    if (type == 'checkin') {
      final existing = await attendances.where('studentId', isEqualTo: studentUid).limit(1).get();
      if (existing.docs.isNotEmpty) return 'duplicate';

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(studentUid).get();
      if (!userDoc.exists) return 'not_registered';
      final data = userDoc.data() as Map<String, dynamic>;

      await attendances.add({
        'studentId': studentUid,
        'studentName': data['name'] ?? data['email'] ?? 'Unknown',
        'studentEmail': data['email'] ?? '',
        'program': data['program'] ?? 'N/A',
        'yearLevel': data['yearLevel'] ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'present',
        'method': 'webinar_code',
      });
      return 'success';
    } else {
      final existing = await attendances.where('studentId', isEqualTo: studentUid).limit(1).get();
      if (existing.docs.isEmpty) return 'not_checked_in';
      final doc = existing.docs.first;
      if (doc.data()['checkOutAt'] != null) return 'duplicate';
      await doc.reference.update({'checkOutAt': FieldValue.serverTimestamp()});
      return 'success';
    }
  }
}
