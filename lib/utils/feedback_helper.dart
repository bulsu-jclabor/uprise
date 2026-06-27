// lib/utils/feedback_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackHelper {
  
  // Ito yung taga-check kung nagbigay na ng feedback ang student
  static Future<bool> hasStudentGivenFeedback({
    required String studentId,
    required String eventId,
  }) async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('event_feedback')
          .where('userId', isEqualTo: studentId)
          .where('eventId', isEqualTo: eventId)
          .get();
      
      return result.docs.isNotEmpty;
      
    } catch (e) {
      print('Error checking feedback: $e');
      return false;
    }
  }
}