// lib/screens/student/student_feedback_prompt.dart
//
// Auto-surfaces the feedback opportunity right after a student attends an
// event, instead of relying entirely on the org remembering to tap "Send
// Evaluation" in org_attendance_qr.dart. Mirrors
// guest_digital_id_notice.dart's "show once" pattern, but keyed per event
// (a student attends many events over time) rather than per account.
//
// Safe to call on every app open — it no-ops if there's nothing new to
// prompt for. Declining ("Maybe Later") only suppresses the auto-popup for
// that event; the event stays reachable via the "Evaluate attended events"
// banner on the Certificates tab and via StudentFeedbackScreen directly.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/student/app_colors.dart';
import 'student_feedback_screen.dart';

const _kPromptedPrefix = 'feedback_prompted_';

Future<void> maybeShowFeedbackPrompt(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final attSnap = await FirebaseFirestore.instance
        .collectionGroup('attendances')
        .where('studentId', isEqualTo: user.uid)
        .get();

    final feedbackSnap = await FirebaseFirestore.instance
        .collection('event_feedback')
        .where('userId', isEqualTo: user.uid)
        .get();
    final ratedEventIds = feedbackSnap.docs
        .map((d) => d.data()['eventId']?.toString())
        .whereType<String>()
        .toSet();

    final prefs = await SharedPreferences.getInstance();

    for (final doc in attSnap.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status != 'present' && status != 'late') continue;
      final eventRef = doc.reference.parent.parent;
      if (eventRef == null) continue;
      final eventId = eventRef.id;

      if (ratedEventIds.contains(eventId)) continue;
      final alreadyPrompted = prefs.getBool('$_kPromptedPrefix$eventId') ?? false;
      if (alreadyPrompted) continue;

      final eventDoc = await eventRef.get();
      if (!eventDoc.exists) continue;
      final ed = eventDoc.data() as Map<String, dynamic>;

      await prefs.setBool('$_kPromptedPrefix$eventId', true);
      if (!context.mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _FeedbackPromptDialog(
          eventTitle: (ed['title'] as String?) ?? 'this event',
        ),
      );
      return; // one prompt per app open is enough.
    }
  } catch (_) {
    // Best-effort — never block app startup over this.
  }
}

class _FeedbackPromptDialog extends StatelessWidget {
  final String eventTitle;
  const _FeedbackPromptDialog({required this.eventTitle});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rate_review_rounded, size: 32, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 18),
            const Text(
              'How was the event?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            Text(
              'You attended "$eventTitle" — share a quick evaluation so the organizer can issue your certificate.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          foregroundColor: Colors.black87,
                          title: const Text('Evaluate Events',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                        body: const StudentFeedbackScreen(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Evaluate Now',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
