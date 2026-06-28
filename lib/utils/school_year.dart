// Shared School Year / Semester helpers — used wherever an org needs to tag
// or filter something (event proposals, letter requests, financial reports)
// by academic period. Semester boundaries mirror reports_management.dart's
// _computeDateRange(): 1st Semester = Aug–Jan, 2nd Semester = Feb–Jun,
// Summer = Jun–Aug.
class SchoolYearUtil {
  static const List<String> semesters = ['1st Semester', '2nd Semester', 'Summer'];

  // The "whole year" option, used where a report/tag can cover an entire
  // school year instead of a single semester.
  static const String wholeYear = 'Whole School Year';

  static int currentStartYear([DateTime? now]) {
    final n = now ?? DateTime.now();
    return n.month >= 8 ? n.year : n.year - 1;
  }

  static String currentSchoolYear([DateTime? now]) {
    final start = currentStartYear(now);
    return '$start-${start + 1}';
  }

  // Default semester guess for "today" — a clean split for convenience
  // defaults only; the existing date-range filter logic elsewhere in the
  // app has its own (slightly overlapping) boundaries and is unaffected.
  static String currentSemester([DateTime? now]) {
    final n = now ?? DateTime.now();
    final m = n.month;
    if (m >= 8 || m == 1) return '1st Semester';
    if (m >= 2 && m <= 5) return '2nd Semester';
    return 'Summer';
  }

  // Generates a dropdown-friendly list of "YYYY-YYYY" school years, newest
  // first, centered on the current school year so it never needs manual
  // updating as years pass.
  static List<String> schoolYears({int back = 2, int forward = 1, DateTime? now}) {
    final start = currentStartYear(now);
    return [
      for (int i = forward; i >= -back; i--) '${start + i}-${start + i + 1}',
    ];
  }

  // Date range covering a given school year + semester (or the whole year
  // when semester is null / wholeYear), for filtering records by date.
  static (DateTime start, DateTime end) dateRangeFor(String schoolYear, String? semester) {
    final parts = schoolYear.split('-');
    final startYear = int.tryParse(parts[0]) ?? DateTime.now().year;
    switch (semester) {
      case '1st Semester':
        return (DateTime(startYear, 8, 1), DateTime(startYear + 1, 1, 31, 23, 59, 59));
      case '2nd Semester':
        return (DateTime(startYear + 1, 2, 1), DateTime(startYear + 1, 6, 30, 23, 59, 59));
      case 'Summer':
        return (DateTime(startYear + 1, 6, 1), DateTime(startYear + 1, 8, 31, 23, 59, 59));
      default: // wholeYear or null
        return (DateTime(startYear, 8, 1), DateTime(startYear + 1, 7, 31, 23, 59, 59));
    }
  }
}
