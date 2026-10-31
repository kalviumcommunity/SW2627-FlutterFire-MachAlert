import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/screens/maintenance/maintenance_details_screen.dart';
import 'package:mach_alert/screens/maintenance/maintenance_list_screen.dart';

void main() {
  testWidgets('maintenance list displays task summary and cards', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MaintenanceListScreen()));

    expect(find.text('Maintenance'), findsOneWidget);

    expect(find.text('Track machine maintenance activity'), findsOneWidget);

    expect(find.text('Pending'), findsWidgets);

    expect(find.text('Active'), findsOneWidget);

    expect(find.text('Done'), findsOneWidget);

    expect(find.text('Inspect spindle vibration'), findsOneWidget);

    expect(find.text('Check hydraulic pressure'), findsOneWidget);
  });

  testWidgets('assigned maintenance screen shows assigned title', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MaintenanceListScreen(assignedOnly: true)),
    );

    expect(find.text('Assigned Maintenance'), findsOneWidget);

    expect(find.text('Your assigned maintenance work'), findsOneWidget);
  });

  testWidgets('maintenance status filter works', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MaintenanceListScreen()));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));

    await tester.pump();

    expect(find.text('Lubricate conveyor bearings'), findsOneWidget);

    expect(find.text('Inspect spindle vibration'), findsNothing);
  });

  testWidgets('tapping maintenance card opens details', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MaintenanceListScreen()));

    await tester.tap(find.text('Inspect spindle vibration'));

    await tester.pumpAndSettle();

    expect(find.byType(MaintenanceDetailsScreen), findsOneWidget);

    expect(find.text('Maintenance Details'), findsOneWidget);

    expect(find.text('MNT-001'), findsOneWidget);

    expect(find.text('CNC Milling Unit 01'), findsOneWidget);

    expect(find.text('Update Maintenance Status'), findsOneWidget);
  });
}
