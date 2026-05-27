import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uprise/widgets/admin_export_button.dart';

void main() {
  testWidgets('AdminExportButton shows menu and returns selection', (WidgetTester tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: AdminExportButton(onSelected: (choice) => selected = choice),
        ),
      ),
    ));

    // Verify button is present
    expect(find.text('Export'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);

    // Tap the button to open the popup menu
    await tester.tap(find.byType(AdminExportButton));
    await tester.pumpAndSettle();

    // The popup menu should show two items: Export as CSV and Export as PDF
    expect(find.text('Export as CSV'), findsOneWidget);
    expect(find.text('Export as PDF'), findsOneWidget);

    // Select CSV
    await tester.tap(find.text('Export as CSV'));
    await tester.pumpAndSettle();
    expect(selected, 'csv');
  });
}
