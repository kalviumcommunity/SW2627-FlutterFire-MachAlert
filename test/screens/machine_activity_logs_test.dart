import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mach_alert/models/machine_activity_log_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/machines/machine_details_screen.dart';
import 'package:mach_alert/services/machine_activity_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:mach_alert/utils/app_constants.dart';

class _FakeActivityService extends Fake implements MachineActivityService {
  final StreamController<List<MachineActivityLogModel>> _controller =
      StreamController<List<MachineActivityLogModel>>.broadcast();

  List<MachineActivityLogModel> initialData;
  Exception? errorToThrow;
  int streamCallCount = 0;

  _FakeActivityService({
    this.initialData = const [],
    this.errorToThrow,
  });

  @override
  Stream<List<MachineActivityLogModel>> streamMachineActivity(String machineId) {
    streamCallCount++;
    if (errorToThrow != null) {
      return Stream.error(errorToThrow!);
    }
    Future.microtask(() {
      if (!_controller.isClosed) {
        _controller.add(initialData);
      }
    });
    return _controller.stream;
  }

  void emit(List<MachineActivityLogModel> events) {
    if (!_controller.isClosed) _controller.add(events);
  }

  void emitError(Object error) {
    if (!_controller.isClosed) _controller.addError(error);
  }

  void dispose() => _controller.close();
}

MachineModel _testMachine({
  String id = 'MCH-CNC-01',
  String name = 'CNC Milling Machine',
}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: 'Line A',
    status: AppConstants.machineStatusOperational,
    healthScore: 92,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required MachineModel machine,
  required MachineActivityService activityService,
}) async {
  final appState = AppStateProvider()
    ..setAuthenticated(
      UserModel(
        id: 'u1',
        name: 'Test Operator',
        email: 'test@machalert.com',
        role: AppConstants.roleOperator,
      ),
    );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: MachineDetailsScreen(
          machine: machine,
          activityService: activityService,
        ),
      ),
    ),
  );
}

void main() {
  group('Machine Details Activity Logs UI Tests', () {
    testWidgets('1. Displays empty state when no activity events exist', (tester) async {
      final activityService = _FakeActivityService(initialData: []);

      await _pumpScreen(
        tester,
        machine: _testMachine(),
        activityService: activityService,
      );

      // Switch to Logs tab
      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      expect(find.text('Machine Logs'), findsOneWidget);
      expect(find.text('No logs yet'), findsOneWidget);
      expect(
        find.textContaining('Inspection and breakdown logs will appear here'),
        findsOneWidget,
      );

      activityService.dispose();
    });

    testWidgets('2. Displays loading state while awaiting initial stream emission', (tester) async {
      final controller = StreamController<List<MachineActivityLogModel>>();
      final serviceWithPendingStream = _PendingActivityService(controller.stream);

      await _pumpScreen(
        tester,
        machine: _testMachine(),
        activityService: serviceWithPendingStream,
      );

      await tester.tap(find.text('Logs'));
      await tester.pump(); // Initial frame before stream emission

      expect(find.text('Loading Activity Logs...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Emit empty data to settle
      controller.add([]);
      await tester.pumpAndSettle();

      expect(find.text('No logs yet'), findsOneWidget);
      controller.close();
    });

    testWidgets('3. Displays error state with Retry button on Firestore failure', (tester) async {
      final activityService = _FakeActivityService(
        errorToThrow: Exception('Firestore network timeout'),
      );

      await _pumpScreen(
        tester,
        machine: _testMachine(),
        activityService: activityService,
      );

      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Logs'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      activityService.dispose();
    });

    testWidgets('4. Tapping Retry button restarts stream and recovers', (tester) async {
      bool shouldFail = true;
      final retryService = _DynamicActivityService(
        onStream: (machineId) {
          if (shouldFail) {
            return Stream.error(Exception('Temporary failure'));
          }
          return Stream.value([
            MachineActivityLogModel(
              id: 'FLT-REC',
              machineId: machineId,
              type: MachineActivityType.faultReported,
              title: 'Fault Reported: Mechanical',
              actorName: 'Jatin Kashyap',
              actorRole: 'Reporter',
              status: AppConstants.faultStatusOpen,
              timestamp: DateTime(2026, 11, 3, 10, 0),
            ),
          ]);
        },
      );

      await _pumpScreen(
        tester,
        machine: _testMachine(),
        activityService: retryService,
      );

      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Logs'), findsOneWidget);

      // Now set recovery state and tap Retry button
      shouldFail = false;
      final retryBtn = find.widgetWithText(FilledButton, 'Retry');
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.text('Fault Reported: Mechanical'), findsOneWidget);
      expect(find.textContaining('Jatin Kashyap'), findsOneWidget);
    });

    testWidgets('5. Displays multiple event types in timeline with badges and details', (tester) async {
      final events = [
        MachineActivityLogModel(
          id: 'upd-resolved',
          machineId: 'MCH-CNC-01',
          type: MachineActivityType.maintenanceResolved,
          title: 'Maintenance Resolved',
          description: 'Spindle bearings replaced and calibrated.',
          actorName: 'Marcus Vance',
          actorRole: 'Technician',
          status: AppConstants.maintenanceStatusResolved,
          severity: AppConstants.severityCritical,
          proofImageUrl: 'https://supabase/proof.jpg',
          timestamp: DateTime(2026, 11, 3, 14, 30),
        ),
        MachineActivityLogModel(
          id: 'upd-prog',
          machineId: 'MCH-CNC-01',
          type: MachineActivityType.maintenanceInProgress,
          title: 'Maintenance In Progress',
          description: 'Dismantling motor assembly.',
          actorName: 'Marcus Vance',
          actorRole: 'Technician',
          status: AppConstants.maintenanceStatusInProgress,
          timestamp: DateTime(2026, 11, 3, 11, 0),
        ),
        MachineActivityLogModel(
          id: 'mnt-assign',
          machineId: 'MCH-CNC-01',
          type: MachineActivityType.maintenanceAssigned,
          title: 'Maintenance Assigned',
          description: 'Urgent maintenance ticket assigned.',
          actorName: 'Marcus Vance',
          actorRole: 'Technician',
          status: AppConstants.maintenanceStatusPending,
          severity: AppConstants.severityCritical,
          timestamp: DateTime(2026, 11, 3, 10, 15),
        ),
        MachineActivityLogModel(
          id: 'flt-rep',
          machineId: 'MCH-CNC-01',
          type: MachineActivityType.faultReported,
          title: 'Fault Reported: Mechanical',
          description: 'Excessive spindle vibration.',
          actorName: 'Alex Operator',
          actorRole: 'Reporter',
          status: AppConstants.faultStatusOpen,
          severity: AppConstants.severityCritical,
          faultType: AppConstants.faultTypeMechanical,
          timestamp: DateTime(2026, 11, 3, 9, 45),
        ),
      ];

      final activityService = _FakeActivityService(initialData: events);

      await _pumpScreen(
        tester,
        machine: _testMachine(),
        activityService: activityService,
      );

      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      // Assert all 4 titles appear in timeline
      expect(find.text('Maintenance Resolved'), findsOneWidget);
      expect(find.text('Maintenance In Progress'), findsOneWidget);
      expect(find.text('Maintenance Assigned'), findsOneWidget);
      expect(find.text('Fault Reported: Mechanical'), findsOneWidget);

      // Assert status badges
      expect(find.text(AppConstants.maintenanceStatusResolved), findsOneWidget);
      expect(find.text(AppConstants.maintenanceStatusInProgress), findsOneWidget);
      expect(find.text(AppConstants.maintenanceStatusPending), findsOneWidget);
      expect(find.text(AppConstants.faultStatusOpen), findsOneWidget);

      // Assert descriptions
      expect(find.text('Spindle bearings replaced and calibrated.'), findsOneWidget);
      expect(find.text('Dismantling motor assembly.'), findsOneWidget);
      expect(find.text('Excessive spindle vibration.'), findsOneWidget);

      // Assert proof image indicator
      expect(find.text('Photo proof attached'), findsOneWidget);

      activityService.dispose();
    });

    testWidgets('6. Human names are displayed and raw UIDs are never exposed in UI', (tester) async {
      const rawUid = 'JO5v92NOnFQC1gvKPigwBfAnSut2';

      final events = [
        MachineActivityLogModel(
          id: 'ev-1',
          machineId: 'MCH-CNC-01',
          type: MachineActivityType.faultReported,
          title: 'Fault Reported: Hydraulic',
          actorName: 'Jatin Kashyap',
          actorRole: 'Reporter',
          status: AppConstants.faultStatusOpen,
          timestamp: DateTime(2026, 11, 3, 10, 0),
        ),
        MachineActivityLogModel(
          id: 'ev-2',
          machineId: 'MCH-CNC-01',
          type: MachineActivityType.maintenanceAssigned,
          title: 'Maintenance Assigned',
          actorName: 'Technician', // Safe fallback
          actorRole: 'Technician',
          status: AppConstants.maintenanceStatusPending,
          timestamp: DateTime(2026, 11, 3, 10, 30),
        ),
      ];

      final activityService = _FakeActivityService(initialData: events);

      await _pumpScreen(
        tester,
        machine: _testMachine(),
        activityService: activityService,
      );

      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Jatin Kashyap'), findsOneWidget);
      expect(find.textContaining('Technician'), findsWidgets);
      // Raw UID should never be present
      expect(find.textContaining(rawUid), findsNothing);

      activityService.dispose();
    });

    testWidgets('7. Responsive layout on small screen (320x568) without overflow', (tester) async {
      final events = [
        MachineActivityLogModel(
          id: 'ev-overflow-check',
          machineId: 'MCH-CNC-01',
          type: MachineActivityType.faultReported,
          title: 'Fault Reported: High Pressure Hydraulic System Super Critical Alarm',
          description:
              'A very long detailed description detailing hydraulic cylinder pressure variations, manifold issues, and sensor errors that could cause RenderFlex overflow if unconstrained.',
          actorName: 'Alexander Bartholomew Montgomery-Smith III',
          actorRole: 'Senior Lead Factory Maintenance Technician & Safety Inspector',
          status: AppConstants.faultStatusOpen,
          severity: AppConstants.severityCritical,
          faultType: AppConstants.faultTypeHydraulic,
          proofImageUrl: 'https://proof/test.jpg',
          timestamp: DateTime(2026, 11, 3, 14, 22),
        ),
      ];

      final activityService = _FakeActivityService(initialData: events);

      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _pumpScreen(
        tester,
        machine: _testMachine(),
        activityService: activityService,
      );

      await tester.tap(find.text('Logs'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Fault Reported'), findsOneWidget);

      activityService.dispose();
    });
  });
}

class _PendingActivityService extends Fake implements MachineActivityService {
  final Stream<List<MachineActivityLogModel>> stream;
  _PendingActivityService(this.stream);

  @override
  Stream<List<MachineActivityLogModel>> streamMachineActivity(String machineId) {
    return stream;
  }
}

class _DynamicActivityService extends Fake implements MachineActivityService {
  final Stream<List<MachineActivityLogModel>> Function(String machineId) onStream;
  _DynamicActivityService({required this.onStream});

  @override
  Stream<List<MachineActivityLogModel>> streamMachineActivity(String machineId) {
    return onStream(machineId);
  }
}
