import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/screens/faults/realtime_faults_screen.dart';

FaultModel createFault({
  required String id,
  required String machineId,
  required String machineName,
  String severity = 'High',
}) {
  return FaultModel(
    id: id,
    machineId: machineId,
    machineName: machineName,
    type: 'Mechanical',
    severity: severity,
    description: 'Motor vibration detected.',
    reportedBy: 'user-1',
    reportedByName: 'Test User',
    status: 'Open',
    createdAt: DateTime(2026, 10, 26, 12, 0),
  );
}

void main() {
  testWidgets('shows integration state when stream is missing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RealtimeFaultsScreen()));

    expect(find.text('Live Faults'), findsOneWidget);

    expect(find.text('LIVE'), findsOneWidget);

    expect(find.text('Live fault monitoring'), findsOneWidget);
  });

  testWidgets('shows fault received from live stream', (tester) async {
    final controller = StreamController<List<FaultModel>>();

    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: RealtimeFaultsScreen(faultStream: controller.stream)),
    );

    controller.add([
      createFault(id: 'F-01', machineId: 'M-01', machineName: 'CNC Machine'),
    ]);

    await tester.pump();

    expect(find.text('1 live fault'), findsOneWidget);

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('M-01'), findsOneWidget);

    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('updates list when stream emits new data', (tester) async {
    final controller = StreamController<List<FaultModel>>();

    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: RealtimeFaultsScreen(faultStream: controller.stream)),
    );

    controller.add([
      createFault(id: 'F-01', machineId: 'M-01', machineName: 'CNC Machine'),
    ]);

    await tester.pump();

    expect(find.text('1 live fault'), findsOneWidget);

    controller.add([
      createFault(id: 'F-01', machineId: 'M-01', machineName: 'CNC Machine'),
      createFault(
        id: 'F-02',
        machineId: 'M-02',
        machineName: 'Hydraulic Press',
        severity: 'Critical',
      ),
    ]);

    await tester.pump();

    expect(find.text('2 live faults'), findsOneWidget);

    expect(find.text('Hydraulic Press'), findsOneWidget);

    expect(find.text('Critical'), findsOneWidget);
  });

  testWidgets('shows empty state when live stream has no faults', (
    tester,
  ) async {
    final controller = StreamController<List<FaultModel>>();

    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: RealtimeFaultsScreen(faultStream: controller.stream)),
    );

    controller.add([]);

    await tester.pump();

    expect(find.text('No active faults'), findsOneWidget);
  });

  testWidgets('shows error state when live stream fails', (tester) async {
    final controller = StreamController<List<FaultModel>>();

    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(home: RealtimeFaultsScreen(faultStream: controller.stream)),
    );

    controller.addError(Exception('stream failed'));

    await tester.pump();

    expect(find.text('Unable to load live faults'), findsOneWidget);
  });
}
