import 'package:flutter_test/flutter_test.dart';
import 'package:uprise/services/ai_service.dart';

void main() {
  test('builds a useful analytics prompt', () {
    final prompt = AiService.buildAnalyticsInsightPrompt(
      totalFeedbacks: 12,
      avgRating: 4.3,
      totalEvents: 5,
      publishedForms: 2,
      highestEvent: 'Youth Summit',
      highestScore: 4.8,
      lowestEvent: 'Fundraising Drive',
      lowestScore: 3.2,
      starCounts: {5: 5, 4: 4, 3: 2, 2: 1, 1: 0},
    );

    expect(prompt, contains('Total evaluations: 12'));
    expect(prompt, contains('Average rating: 4.3 / 5'));
    expect(prompt, contains('Total events: 5'));
    expect(prompt, contains('Published evaluation forms: 2'));
    expect(prompt, contains('Highest rated event: Youth Summit'));
    expect(prompt, contains('5-star: 5'));
  });

  test('builds a useful admin dashboard prompt', () {
    final prompt = AiService.buildAdminDashboardInsightPrompt(
      activeOrganizations: 7,
      activeEvents: 12,
      pendingProposals: 4,
      overdueReports: 2,
      topOrganization: 'CICT Council',
    );

    expect(prompt, contains('Active organizations: 7'));
    expect(prompt, contains('Pending proposals: 4'));
    expect(prompt, contains('Top organization: CICT Council'));
  });
}
