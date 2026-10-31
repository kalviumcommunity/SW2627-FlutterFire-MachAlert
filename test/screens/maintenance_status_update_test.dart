import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/screens/maintenance/maintenance_details_screen.dart';

Widget buildScreen({
  String status = 'Pending',
  MaintenanceStatusUpdateCallback? onStatusUpdate,
}) {
  return MaterialApp(
    home: MaintenanceDetailsScreen(
      maintenanceId: 'MNT-001',
      title: 'Inspect spindle vibration',
      machineName: 'CNC Milling Unit 01',
      technician: 'Technician Team',
      priority: 'High',
      status: status,
      dueDate: 'Today',
      onStatusUpdate: onStatusUpdate,
    ),
  );
}

Future<void> openStatusUpdateSheet(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('update-maintenance-status-button'));

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();

  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> saveStatusUpdate(WidgetTester tester) async {
  final saveButton = find.byKey(const ValueKey('save-maintenance-status'));

  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();

  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('maintenance details shows current status', (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text('Pending'), findsWidgets);

    expect(find.text('Update Maintenance Status'), findsOneWidget);
  });

  testWidgets('update status button opens status sheet', (tester) async {
    await tester.pumpWidget(buildScreen());

    await openStatusUpdateSheet(tester);

    expect(find.text('Update Maintenance Status'), findsWidgets);

    expect(find.widgetWithText(ChoiceChip, 'Pending'), findsOneWidget);

    expect(find.widgetWithText(ChoiceChip, 'In Progress'), findsOneWidget);

    expect(find.widgetWithText(ChoiceChip, 'Completed'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('maintenance-update-notes')),
      findsOneWidget,
    );
  });

  testWidgets('user can update maintenance status to In Progress', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());

    await openStatusUpdateSheet(tester);

    final inProgressChip = find.widgetWithText(ChoiceChip, 'In Progress');

    await tester.ensureVisible(inProgressChip);

    await tester.tap(inProgressChip);

    await tester.pump();

    await saveStatusUpdate(tester);

    expect(
      find.text('Maintenance status updated to In Progress.'),
      findsOneWidget,
    );

    expect(find.text('Maintenance started'), findsOneWidget);
  });

  testWidgets('status callback receives selected status and notes', (
    tester,
  ) async {
    String? receivedStatus;
    String? receivedNotes;

    await tester.pumpWidget(
      buildScreen(
        onStatusUpdate: (status, notes) async {
          receivedStatus = status;
          receivedNotes = notes;
        },
      ),
    );

    await openStatusUpdateSheet(tester);

    final completedChip = find.widgetWithText(ChoiceChip, 'Completed');

    await tester.ensureVisible(completedChip);

    await tester.tap(completedChip);

    await tester.pump();

    final notesField = find.byKey(const ValueKey('maintenance-update-notes'));

    await tester.ensureVisible(notesField);

    await tester.enterText(notesField, 'Replaced worn bearing.');

    await tester.pump();

    await saveStatusUpdate(tester);

    expect(receivedStatus, equals('Completed'));

    expect(receivedNotes, equals('Replaced worn bearing.'));

    expect(find.text('Maintenance completed'), findsOneWidget);
  });

  testWidgets('failed status callback shows safe error', (tester) async {
    await tester.pumpWidget(
      buildScreen(
        onStatusUpdate: (status, notes) async {
          throw Exception('Backend unavailable');
        },
      ),
    );

    await openStatusUpdateSheet(tester);

    final completedChip = find.widgetWithText(ChoiceChip, 'Completed');

    await tester.ensureVisible(completedChip);

    await tester.tap(completedChip);

    await tester.pump();

    await saveStatusUpdate(tester);

    expect(
      find.text('Unable to update maintenance status. Please try again.'),
      findsOneWidget,
    );

    expect(find.textContaining('Backend unavailable'), findsNothing);
  });
}
