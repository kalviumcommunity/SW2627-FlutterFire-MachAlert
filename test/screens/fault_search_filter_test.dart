import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/screens/faults/realtime_faults_screen.dart';
import 'package:mach_alert/services/fault_service.dart';

FaultModel createFault({
  required String id,
  required String machineId,
  required String machineName,
  required String severity,
  required String status,
  String type = 'Mechanical',
  String description = 'Machine fault description',
}) {
  return FaultModel(
    id: id,
    machineId: machineId,
    machineName: machineName,
    type: type,
    severity: severity,
    description: description,
    reportedBy: 'user-1',
    reportedByName: 'Operator',
    status: status,
    createdAt: DateTime(2026, 10, 27, 10),
  );
}

class RecordingFaultService extends Fake implements FaultService {
  final List<({String? machineId, String? status, String? severity})>
  streamCalls = [];
  final List<StreamController<List<FaultModel>>> controllers = [];
  final List<FaultModel> faults;

  RecordingFaultService({this.faults = const []});

  StreamController<List<FaultModel>> get lastController => controllers.last;

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
  }) {
    streamCalls.add((machineId: machineId, status: status, severity: severity));
    late final StreamController<List<FaultModel>> controller;
    controller = StreamController<List<FaultModel>>.broadcast(
      onListen: () {
        if (faults.isNotEmpty) {
          scheduleMicrotask(() {
            if (!controller.isClosed) {
              var filtered = List<FaultModel>.from(faults);
              if (status != null) {
                filtered = filtered
                    .where(
                      (f) => f.status.toLowerCase() == status.toLowerCase(),
                    )
                    .toList();
              }
              if (severity != null) {
                filtered = filtered
                    .where(
                      (f) => f.severity.toLowerCase() == severity.toLowerCase(),
                    )
                    .toList();
              }
              controller.add(filtered);
            }
          });
        }
      },
    );
    controllers.add(controller);
    return controller.stream;
  }
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

  group('FaultService integration and server-side filtering', () {
    testWidgets(
      'initial load requests unfiltered stream, status and severity filter requests update stream correctly',
      (tester) async {
        final faultService = RecordingFaultService(
          faults: [
            createFault(
              id: 'F-01',
              machineId: 'CNC-01',
              machineName: 'CNC Machine',
              status: 'In Progress',
              severity: 'Critical',
            ),
            createFault(
              id: 'F-02',
              machineId: 'M-02',
              machineName: 'Lathe Machine',
              status: 'Open',
              severity: 'High',
            ),
          ],
        );
        addTearDown(() {
          for (final c in faultService.controllers) {
            c.close();
          }
        });

        await tester.pumpWidget(
          MaterialApp(home: RealtimeFaultsScreen(faultService: faultService)),
        );
        await tester.pump();

        // 1. Initial loading requests an unfiltered stream
        expect(faultService.streamCalls.length, 1);
        expect(faultService.streamCalls.first.status, isNull);
        expect(faultService.streamCalls.first.severity, isNull);

        // 2. Selecting a status requests a stream with the correct status
        final inProgressChip = find.widgetWithText(ChoiceChip, 'In Progress');
        await tester.ensureVisible(inProgressChip);
        await tester.tap(inProgressChip);
        await tester.pump();

        expect(faultService.streamCalls.length, 2);
        expect(faultService.streamCalls.last.status, 'In Progress');
        expect(faultService.streamCalls.last.severity, isNull);

        // 3. Selecting a severity requests a stream with the correct severity
        final criticalChip = find.widgetWithText(ChoiceChip, 'Critical');
        await tester.ensureVisible(criticalChip);
        await tester.tap(criticalChip);
        await tester.pump();

        // 4. Selecting both sends both filter parameters together
        expect(faultService.streamCalls.length, 3);
        expect(faultService.streamCalls.last.status, 'In Progress');
        expect(faultService.streamCalls.last.severity, 'Critical');

        // 5. Clearing filters restores the unfiltered stream
        final clearButton = find.text('Clear All');
        await tester.ensureVisible(clearButton);
        await tester.tap(clearButton);
        await tester.pump();

        expect(faultService.streamCalls.length, 4);
        expect(faultService.streamCalls.last.status, isNull);
        expect(faultService.streamCalls.last.severity, isNull);
      },
    );

    testWidgets(
      'free-text search works with server-side filters and does not re-request stream',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final faultService = RecordingFaultService(
          faults: [
            createFault(
              id: 'F-01',
              machineId: 'CNC-01',
              machineName: 'CNC Milling Machine',
              severity: 'High',
              status: 'Open',
              description: 'Spindle overheating warning',
            ),
            createFault(
              id: 'F-02',
              machineId: 'PRESS-02',
              machineName: 'Hydraulic Press',
              severity: 'High',
              status: 'Open',
              description: 'Vibration detected',
            ),
            createFault(
              id: 'F-03',
              machineId: 'LAT-03',
              machineName: 'Lathe Machine',
              severity: 'Low',
              status: 'Open',
              description: 'Belt noise',
            ),
          ],
        );
        addTearDown(() {
          for (final c in faultService.controllers) {
            c.close();
          }
        });

        await tester.pumpWidget(
          MaterialApp(home: RealtimeFaultsScreen(faultService: faultService)),
        );
        await tester.pump();

        final highChip = find.widgetWithText(ChoiceChip, 'High');
        await tester.ensureVisible(highChip);
        await tester.tap(highChip);
        await tester.pump();

        expect(faultService.streamCalls.length, 2);
        expect(faultService.streamCalls.last.severity, 'High');
        expect(find.text('CNC Milling Machine'), findsOneWidget);
        expect(find.text('Hydraulic Press'), findsOneWidget);
        expect(find.text('2 matching faults'), findsOneWidget);

        // Free-text search
        await tester.enterText(find.byType(TextField), 'spindle');
        await tester.pump();

        // Ensure stream was NOT re-requested (search is local)
        expect(faultService.streamCalls.length, 2);
        expect(find.text('CNC Milling Machine'), findsOneWidget);
        expect(find.text('Hydraulic Press'), findsNothing);
        expect(find.text('1 of 2 matching faults shown'), findsOneWidget);
      },
    );

    testWidgets(
      'empty filtered query displays No matching faults with clear button and not No active faults',
      (tester) async {
        final faultService = RecordingFaultService(
          faults: [
            createFault(
              id: 'F-01',
              machineId: 'CNC-01',
              machineName: 'CNC Milling Machine',
              severity: 'Low',
              status: 'Open',
            ),
          ],
        );
        addTearDown(() {
          for (final c in faultService.controllers) {
            c.close();
          }
        });

        await tester.pumpWidget(
          MaterialApp(home: RealtimeFaultsScreen(faultService: faultService)),
        );
        await tester.pump();

        final criticalChip = find.widgetWithText(ChoiceChip, 'Critical');
        await tester.ensureVisible(criticalChip);
        await tester.tap(criticalChip);
        await tester.pump();

        // Server returns empty list for this filter
        expect(find.text('No matching faults'), findsOneWidget);
        expect(find.text('No active faults'), findsNothing);
        expect(find.text('Clear Filters'), findsOneWidget);
        expect(find.text('0 matching faults'), findsOneWidget);

        // Tapping Clear Filters restores unfiltered stream
        await tester.tap(find.text('Clear Filters'));
        await tester.pump();
        await tester.pump();

        expect(faultService.streamCalls.last.severity, isNull);
        expect(faultService.streamCalls.last.status, isNull);
        expect(find.text('CNC Milling Machine'), findsOneWidget);
      },
    );

    testWidgets('filtered stream receives dynamic live updates', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final faultService = RecordingFaultService(
        faults: [
          createFault(
            id: 'F-01',
            machineId: 'M-01',
            machineName: 'Lathe 01',
            severity: 'Low',
            status: 'Open',
          ),
        ],
      );
      addTearDown(() {
        for (final c in faultService.controllers) {
          c.close();
        }
      });

      await tester.pumpWidget(
        MaterialApp(home: RealtimeFaultsScreen(faultService: faultService)),
      );
      await tester.pump();

      final openChip = find.widgetWithText(ChoiceChip, 'Open');
      await tester.ensureVisible(openChip);
      await tester.tap(openChip);
      await tester.pump();

      expect(find.text('1 matching fault'), findsOneWidget);
      expect(find.text('Lathe 01'), findsOneWidget);

      // Dynamic update on the active filtered stream
      faultService.lastController.add([
        createFault(
          id: 'F-01',
          machineId: 'M-01',
          machineName: 'Lathe 01',
          severity: 'Low',
          status: 'Open',
        ),
        createFault(
          id: 'F-02',
          machineId: 'M-02',
          machineName: 'Conveyor 02',
          severity: 'Medium',
          status: 'Open',
        ),
      ]);
      await tester.pump();

      expect(find.text('2 matching faults'), findsOneWidget);
      expect(find.text('Conveyor 02'), findsOneWidget);
    });
  });
}
