import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/screens/faults/fault_reporting_screen.dart';

MachineModel createMachine({String id = 'M-01', String name = 'CNC Machine'}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: 'Line 1',
    status: 'Operational',
    healthScore: 95,
  );
}

void main() {
  testWidgets('FaultReportingScreen displays base fault UI', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FaultReportingScreen()));

    expect(find.text('Report Fault'), findsOneWidget);

    expect(find.text('Report Machine Fault'), findsOneWidget);

    expect(find.text('Machine'), findsOneWidget);

    expect(find.text('Event Type'), findsOneWidget);

    expect(find.text('Breakdown / Fault'), findsOneWidget);

    expect(find.text('Notes'), findsOneWidget);

    expect(find.text('Add Photos'), findsOneWidget);

    expect(find.text('Submit Fault Report'), findsOneWidget);
  });

  testWidgets('FaultReportingScreen shows empty machine state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FaultReportingScreen()));

    expect(find.text('No machines are available.'), findsOneWidget);
  });

  testWidgets('FaultReportingScreen shows supplied machines', (tester) async {
    final machines = [
      createMachine(),
      createMachine(id: 'M-02', name: 'Hydraulic Press'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: FaultReportingScreen(machines: machines)),
    );

    expect(find.text('M-01 - CNC Machine'), findsOneWidget);

    expect(find.text('CNC Machine'), findsOneWidget);
  });

  testWidgets('initial machine is selected', (tester) async {
    final machine = createMachine();

    await tester.pumpWidget(
      MaterialApp(
        home: FaultReportingScreen(
          machines: [machine],
          initialMachine: machine,
        ),
      ),
    );

    expect(find.text('M-01 - CNC Machine'), findsOneWidget);

    expect(find.text('Line 1'), findsOneWidget);
  });

  testWidgets('submit asks for machine when none is available', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FaultReportingScreen()));

    final submitButton = find.widgetWithText(
      FilledButton,
      'Submit Fault Report',
    );

    expect(submitButton, findsOneWidget);

    await tester.ensureVisible(submitButton);

    await tester.pumpAndSettle();

    await tester.tap(submitButton);

    await tester.pump();

    expect(find.text('Please select a machine first.'), findsOneWidget);
  });
}
