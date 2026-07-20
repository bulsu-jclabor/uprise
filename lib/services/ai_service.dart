import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AiService {
  static final FirebaseFunctions _functions = () {
    final functions = FirebaseFunctions.instance;
    if (kDebugMode) {
      functions.useFunctionsEmulator('localhost', 5001);
    }
    return functions;
  }();

  static String buildAdminDashboardInsightPrompt({
    required int activeOrganizations,
    required int activeEvents,
    required int pendingProposals,
    required int overdueReports,
    required String topOrganization,
  }) {
    return '''
You are an admin dashboard assistant for a student organization management app.
Review the current dashboard metrics and give a concise, practical recommendation.

Context:
- Active organizations: $activeOrganizations
- Active events: $activeEvents
- Pending proposals: $pendingProposals
- Overdue reports: $overdueReports
- Top organization: $topOrganization

Please return:
1. One sentence saying whether the system looks healthy or needs attention.
2. One clear action the admin should take next.
''';
  }

  static String buildAnalyticsInsightPrompt({
    required int totalFeedbacks,
    required double avgRating,
    required int totalEvents,
    required int publishedForms,
    required String highestEvent,
    required double highestScore,
    required String lowestEvent,
    required double lowestScore,
    required Map<int, int> starCounts,
  }) {
    final ratingBreakdown = [
      '5-star: ${starCounts[5] ?? 0}',
      '4-star: ${starCounts[4] ?? 0}',
      '3-star: ${starCounts[3] ?? 0}',
      '2-star: ${starCounts[2] ?? 0}',
      '1-star: ${starCounts[1] ?? 0}',
    ].join('; ');

    return '''
You are an event analytics assistant for a student organization app.
You are helping an org officer understand event feedback and prioritize improvements.

Context:
- Total evaluations: $totalFeedbacks
- Average rating: ${avgRating.toStringAsFixed(1)} / 5
- Total events: $totalEvents
- Published evaluation forms: $publishedForms
- Highest rated event: $highestEvent (${highestScore.toStringAsFixed(1)} / 5)
- Needs improvement: $lowestEvent (${lowestScore.toStringAsFixed(1)} / 5)
- Rating breakdown: $ratingBreakdown

Please return:
1. A polished 2-sentence summary of current event performance.
2. 3 practical recommendations for improving future events.
3. One suggestion for how the org should prioritize follow-up.
''';
  }

  static String buildStudentImportValidationPrompt({
    required List<Map<String, String>> sampleRows,
    required List<String> expectedFields,
  }) {
    final rowsText = sampleRows
        .asMap()
        .entries
        .map((entry) {
          final rowNumber = entry.key + 1;
          final cells = expectedFields
              .map((field) {
                final value = entry.value[field] ?? '';
                return '$field: ${value.isEmpty ? '<empty>' : value}';
              })
              .join(', ');
          return 'Row $rowNumber: $cells';
        })
        .join('\n');

    return '''
You are a data validation assistant for a student batch import process.

Expected fields:
- ${expectedFields.join('\n- ')}

Review the sample rows below and identify whether the values appear to be in the correct columns, whether any fields are missing or likely misplaced, and whether the email, student ID, course, semester, and school year values look valid.

For each sample row, return one of these two formats:
- Row N: OK
- Row N: Warning - <explanation>

Then return a short import recommendation summarizing whether the batch looks ready for import.

Sample rows:
$rowsText
''';
  }

  static String buildReportManagementInsightPrompt({
    required int activeOrganizations,
    required int activeEvents,
    required int overdueReports,
    required int lateSubmissions,
    required int pendingReports,
    required String topOrganization,
  }) {
    return '''
You are an administrative report dashboard assistant for a student organization management app.
Review the current report submission health and provide concise guidance.

Context:
- Active organizations: $activeOrganizations
- Active events: $activeEvents
- Overdue reports: $overdueReports
- Late submissions: $lateSubmissions
- Pending reports: $pendingReports
- Top organization with the most overdue items: $topOrganization

Please return:
1. A one-sentence summary of the current report submission health.
2. One specific action the admin should take next.
''';
  }

  static String buildAdminDashboardSummary({
    required int activeOrganizations,
    required int activeEvents,
    required int pendingProposals,
    required int overdueReports,
    required String topOrganization,
  }) {
    final attention = pendingProposals > 0 || overdueReports > 0;
    if (attention) {
      return 'Admin health: needs attention. Review pending proposals and overdue reports first, then follow up with the most active organization.';
    }
    return 'Admin health: steady. The dashboard looks active and organized, and current operations appear on track.';
  }

  static Future<String> ask(
    String prompt, {
    String model = 'gemini-2.0-flash',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Please sign in first.');
    }

    final result = await _functions
        .httpsCallable('askAi')
        .call<Map<String, dynamic>>({
          'prompt': prompt,
          'model': model,
          'temperature': 0.2,
          'maxOutputTokens': 600,
        });

    return (result.data['text'] as String?) ?? '';
  }
}
