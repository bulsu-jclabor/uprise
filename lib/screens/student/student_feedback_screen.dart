import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ─── App Colors ────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF5F5F5);
}

class StudentFeedbackScreen extends StatefulWidget {
  const StudentFeedbackScreen({super.key});

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  Future<List<Map<String, dynamic>>>? _attendedEventsFuture;

  @override
  void initState() {
    super.initState();
    _attendedEventsFuture = _loadAttendedEvents();
  }

  void _refresh() => setState(() {
    _attendedEventsFuture = _loadAttendedEvents();
  });

  Future<List<Map<String, dynamic>>> _loadAttendedEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

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

    final results = <Map<String, dynamic>>[];
    for (final doc in attSnap.docs) {
      final status = (doc.data()['status'] ?? '').toString();
      if (status != 'present' && status != 'late') continue;
      final eventRef = doc.reference.parent.parent;
      if (eventRef == null) continue;
      final eventDoc = await eventRef.get();
      if (!eventDoc.exists) continue;
      final ed = eventDoc.data() as Map<String, dynamic>;
      results.add({
        'eventId': eventRef.id,
        'eventName': ed['title'] ?? 'Event',
        'organization': ed['orgName'] ?? '',
        'orgId': ed['orgId'] ?? '',
        'rated': ratedEventIds.contains(eventRef.id),
      });
    }
    results.sort((a, b) => (a['rated'] as bool ? 1 : 0).compareTo(b['rated'] as bool ? 1 : 0));
    return results;
  }

  Future<void> _showEventFeedbackDialog(Map<String, dynamic> ev) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    int selectedRating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submit() async {
            if (selectedRating == 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Please select a star rating.'),
                backgroundColor: AppColors.primaryDark,
              ));
              return;
            }
            setSheet(() => submitting = true);
            try {
              await FirebaseFirestore.instance.collection('event_feedback').add({
                'eventId': ev['eventId'],
                'eventName': ev['eventName'],
                'organization': ev['organization'],
                'orgId': ev['orgId'],
                'rating': selectedRating,
                'comment': commentCtrl.text.trim(),
                'userId': user.uid,
                'submittedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                _refresh();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Evaluation submitted. Thank you!'),
                  backgroundColor: Colors.green,
                ));
              }
            } catch (e) {
              setSheet(() => submitting = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Failed to submit: $e'),
                  backgroundColor: Colors.red,
                ));
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Evaluate Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(ev['eventName'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        onPressed: () => setSheet(() => selectedRating = star),
                        icon: Icon(
                          star <= selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: star <= selectedRating ? AppColors.primaryDark : Colors.grey.shade400,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts about this event (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: submitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: submitting
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Evaluation', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primaryDark,
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _attendedEventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryDark));
          }
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.feedback_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Center(
                  child: Text('No events to evaluate yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey)),
                ),
                SizedBox(height: 8),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Once you attend an event, it will show up here for you to evaluate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, i) {
              final ev = events[i];
              final rated = ev['rated'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ev['eventName'] ?? 'Event',
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.black87)),
                      if ((ev['organization'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(ev['organization'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ]),
                  ),
                  const SizedBox(width: 12),
                  rated
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Submitted',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                        )
                      : ElevatedButton(
                          onPressed: () => _showEventFeedbackDialog(ev),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Evaluate', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}