import 'package:flutter_test/flutter_test.dart';
import 'package:uprise/screens/web/admin/organization_management.dart';

void main() {
  test('Adviser keeps student adviser type and serializes it', () {
    final adviser = Adviser.fromMap({
      'name': 'Ana Cruz',
      'title': 'Student Adviser',
      'email': 'ana@example.com',
      'phone': '09123456789',
      'type': 'student',
    });

    expect(adviser.isStudentAdviser, isTrue);
    expect(adviser.toMap()['type'], 'student');

    final updated = adviser.copyWith(name: 'Ana Marie Cruz');
    expect(updated.name, 'Ana Marie Cruz');
    expect(updated.type, 'student');
  });
}
