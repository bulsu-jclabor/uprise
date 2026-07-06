import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uprise/screens/student/student_announcements_screen.dart';

void main() {
  group('shouldShowAnnouncementToStudent', () {
    test('hides unpublished announcements', () {
      final data = <String, dynamic>{'isPublished': false};

      expect(shouldShowAnnouncementToStudent(data), isFalse);
    });

    test('hides scheduled announcements before their publish time', () {
      final future = DateTime.now().add(const Duration(hours: 1));
      final data = <String, dynamic>{
        'isPublished': true,
        'isScheduled': true,
        'scheduledPublishDate': Timestamp.fromDate(future),
      };

      expect(shouldShowAnnouncementToStudent(data), isFalse);
    });

    test('shows scheduled announcements after their publish time', () {
      final past = DateTime.now().subtract(const Duration(minutes: 1));
      final data = <String, dynamic>{
        'isPublished': true,
        'isScheduled': true,
        'scheduledPublishDate': Timestamp.fromDate(past),
      };

      expect(shouldShowAnnouncementToStudent(data), isTrue);
    });
  });
}
