import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/screens/machines/machine_details_screen.dart';

MachineModel createMachine({String status = 'Operational'}) {
  return MachineModel(
    id: 'M-01',
    name: 'CNC Machine',
    productionLine: 'Assembly Line A',
    modelNumber: 'CNC-X100',
    status: status,
    healthScore: 92,
    temperature: 64.5,
    vibration: 12.3,
    lastInspection: DateTime(2026, 10, 10, 10, 30),
  );
}

void main() {
  testWidgets('MachineDetailsScreen displays machine information', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    expect(find.text('M-01'), findsWidgets);

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('Assembly Line A'), findsOneWidget);

    expect(find.text('Running'), findsOneWidget);

    expect(find.text('92%'), findsOneWidget);

    expect(find.text('64.5°C'), findsOneWidget);

    expect(find.text('12.3'), findsOneWidget);
  });

  testWidgets('MachineDetailsScreen displays overview tab initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    expect(find.text('Total Inspections'), findsOneWidget);

    expect(find.text('Total Breakdowns'), findsOneWidget);

    expect(find.text('Last Inspection'), findsOneWidget);

    expect(find.text('Recent Logs'), findsOneWidget);
  });

  testWidgets('MachineDetailsScreen switches to Logs tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    await tester.tap(find.text('Logs'));

    await tester.pump();

    expect(find.text('Machine Logs'), findsOneWidget);

    expect(
      find.textContaining('Inspection and breakdown logs'),
      findsOneWidget,
    );
  });

  testWidgets('MachineDetailsScreen switches to Trend tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    await tester.tap(find.text('Trend'));

    await tester.pump();

    expect(find.text('Machine Trend'), findsOneWidget);
  });

  testWidgets('Breakdown status displays correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MachineDetailsScreen(machine: createMachine(status: 'Breakdown')),
      ),
    );

    expect(find.text('Breakdown'), findsOneWidget);
  });
}
