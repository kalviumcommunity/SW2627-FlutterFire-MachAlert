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

Future<void> pumpFaultScreen(
  WidgetTester tester, {
  List<MachineModel> machines = const [],
  MachineModel? initialMachine,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FaultReportingScreen(
        machines: machines,
        initialMachine: initialMachine,
      ),
    ),
  );
}

void main() {
  testWidgets('FaultReportingScreen displays Day 12 form fields', (
    tester,
  ) async {
    await pumpFaultScreen(tester, machines: [createMachine()]);

    expect(find.text('Report Machine Fault'), findsOneWidget);

    expect(find.text('Machine'), findsOneWidget);

    expect(find.text('Fault Type'), findsOneWidget);

    expect(find.text('Severity'), findsOneWidget);

    expect(find.text('Low'), findsOneWidget);

    expect(find.text('Medium'), findsOneWidget);

    expect(find.text('High'), findsOneWidget);

    expect(find.text('Critical'), findsOneWidget);

    expect(find.text('Fault Description'), findsOneWidget);

    expect(find.text('Add Photos'), findsOneWidget);

    expect(find.text('Submit Fault Report'), findsOneWidget);
  });

  testWidgets('initial machine remains selected', (tester) async {
    final machine = createMachine();

    await pumpFaultScreen(tester, machines: [machine], initialMachine: machine);

    expect(find.text('M-01 - CNC Machine'), findsOneWidget);

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('Line 1'), findsOneWidget);
  });

  testWidgets('empty fault form shows required validation', (tester) async {
    await pumpFaultScreen(tester, machines: [createMachine()]);

    final submitButton = find.widgetWithText(
      FilledButton,
      'Submit Fault Report',
    );

    await tester.ensureVisible(submitButton);

    await tester.pumpAndSettle();

    await tester.tap(submitButton);

    await tester.pump();

    expect(find.text('Please select a fault type.'), findsOneWidget);

    expect(find.text('Please select a severity.'), findsOneWidget);

    expect(find.text('Please describe the fault.'), findsOneWidget);
  });

  testWidgets('user can select critical severity', (tester) async {
    await pumpFaultScreen(tester, machines: [createMachine()]);

    final criticalChip = find.text('Critical');

    await tester.ensureVisible(criticalChip);

    await tester.tap(criticalChip);

    await tester.pump();

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Critical'),
    );

    expect(chip.selected, isTrue);
  });

  testWidgets('valid Day 12 form reaches submission placeholder', (
    tester,
  ) async {
    await pumpFaultScreen(tester, machines: [createMachine()]);

    final dropdowns = find.byType(DropdownButtonFormField<String>);

    expect(dropdowns, findsNWidgets(2));

    await tester.tap(dropdowns.at(1));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Mechanical').last);

    await tester.pumpAndSettle();

    final criticalChip = find.text('Critical');

    await tester.ensureVisible(criticalChip);

    await tester.tap(criticalChip);

    await tester.pump();

    final description = find.byType(TextFormField);

    await tester.enterText(
      description,
      'Motor overheating with unusual vibration.',
    );

    final submitButton = find.widgetWithText(
      FilledButton,
      'Submit Fault Report',
    );

    await tester.ensureVisible(submitButton);

    await tester.pumpAndSettle();

    await tester.tap(submitButton);

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Fault form is ready'), findsOneWidget);
  });

  testWidgets('submit asks for machine when none exists', (tester) async {
    await pumpFaultScreen(tester);

    final submitButton = find.widgetWithText(
      FilledButton,
      'Submit Fault Report',
    );

    await tester.ensureVisible(submitButton);

    await tester.pumpAndSettle();

    await tester.tap(submitButton);

    await tester.pump();

    expect(find.text('Please select a machine first.'), findsOneWidget);
  });
}
