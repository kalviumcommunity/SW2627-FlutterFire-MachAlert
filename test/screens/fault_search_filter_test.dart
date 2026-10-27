import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/screens/faults/realtime_faults_screen.dart';

FaultModel createFault({
  required String id,
  required String machineId,
  required String machineName,
  required String severity,
  required String status,
  String type = 'Mechanical',
}) {
  return FaultModel(
    id: id,
    machineId: machineId,
    machineName: machineName,
    type: type,
    severity: severity,
    description: 'Machine fault description',
    reportedBy: 'user-1',
    reportedByName: 'Operator',
    status: status,
    createdAt: DateTime(2026, 10, 27, 10),
  );
}

Future<StreamController<List<FaultModel>>> pumpScreen(
  WidgetTester tester,
) async {
  final controller = StreamController<List<FaultModel>>();

  await tester.pumpWidget(
    MaterialApp(home: RealtimeFaultsScreen(faultStream: controller.stream)),
  );

  controller.add([
    createFault(
      id: 'F-01',
      machineId: 'M-01',
      machineName: 'CNC Machine',
      severity: 'High',
      status: 'Open',
    ),
    createFault(
      id: 'F-02',
      machineId: 'M-02',
      machineName: 'Hydraulic Press',
      severity: 'Critical',
      status: 'In Progress',
      type: 'Hydraulic',
    ),
  ]);

  await tester.pump();

  return controller;
}

void main() {
  testWidgets('shows search and filter controls', (tester) async {
    final controller = await pumpScreen(tester);

    addTearDown(controller.close);

    expect(find.text('Search faults...'), findsOneWidget);

    expect(find.text('Filters'), findsOneWidget);

    expect(find.text('Severity'), findsOneWidget);

    expect(find.text('Status'), findsOneWidget);
  });

  testWidgets('search filters faults by machine name', (tester) async {
    final controller = await pumpScreen(tester);

    addTearDown(controller.close);

    await tester.enterText(find.byType(TextField), 'CNC');

    await tester.pump();

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('Hydraulic Press'), findsNothing);

    expect(find.text('1 of 2 faults shown'), findsOneWidget);
  });

  testWidgets('severity filter shows matching fault', (tester) async {
    final controller = await pumpScreen(tester);

    addTearDown(controller.close);

    final criticalChip = find.widgetWithText(ChoiceChip, 'Critical');

    await tester.ensureVisible(criticalChip);

    await tester.tap(criticalChip);

    await tester.pump();

    expect(find.text('Hydraulic Press'), findsOneWidget);

    expect(find.text('CNC Machine'), findsNothing);
  });

  testWidgets('status filter shows matching fault', (tester) async {
    final controller = await pumpScreen(tester);

    addTearDown(controller.close);

    final inProgressChip = find.widgetWithText(ChoiceChip, 'In Progress');

    await tester.ensureVisible(inProgressChip);

    await tester.tap(inProgressChip);

    await tester.pump();

    expect(find.text('Hydraulic Press'), findsOneWidget);

    expect(find.text('CNC Machine'), findsNothing);
  });

  testWidgets('no matching search displays empty result state', (tester) async {
    final controller = await pumpScreen(tester);

    addTearDown(controller.close);

    await tester.enterText(find.byType(TextField), 'does-not-exist');

    await tester.pump();

    expect(find.text('No matching faults'), findsOneWidget);

    expect(find.text('Clear Filters'), findsOneWidget);
  });
}
