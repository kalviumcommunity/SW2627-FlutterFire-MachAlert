import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';

MachineModel machine({
  required String id,
  required String name,
  required String status,
  String line = 'Assembly Line',
}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: line,
    status: status,
    healthScore: 100,
  );
}

void main() {
  testWidgets('MachineListScreen displays machine list', (tester) async {
    final machines = [
      machine(id: 'M-01', name: 'CNC Machine', status: 'Operational'),
      machine(id: 'M-02', name: 'Hydraulic Press', status: 'Operational'),
      machine(
        id: 'M-03',
        name: 'Assembly Machine',
        status: 'Under Maintenance',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MachineListScreen(machines: machines)),
    );

    expect(find.text('Machines'), findsOneWidget);

    expect(find.text('M-01'), findsOneWidget);

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('M-02'), findsOneWidget);

    expect(find.text('Under Maintenance'), findsOneWidget);
  });

  testWidgets('MachineListScreen filters machines by search', (tester) async {
    final machines = [
      machine(id: 'M-01', name: 'CNC Machine', status: 'Operational'),
      machine(id: 'M-02', name: 'Hydraulic Press', status: 'Operational'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MachineListScreen(machines: machines)),
    );

    await tester.enterText(find.byType(TextField), 'CNC');

    await tester.pump();

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('Hydraulic Press'), findsNothing);
  });

  testWidgets('MachineListScreen shows empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MachineListScreen()));

    expect(find.text('No machines available'), findsOneWidget);
  });

  testWidgets('MachineListScreen shows no results after unmatched search', (
    tester,
  ) async {
    final machines = [
      machine(id: 'M-01', name: 'CNC Machine', status: 'Operational'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MachineListScreen(machines: machines)),
    );

    await tester.enterText(find.byType(TextField), 'does-not-exist');

    await tester.pump();

    expect(find.text('No machines found'), findsOneWidget);
  });
}
