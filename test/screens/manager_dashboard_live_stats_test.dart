// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/widgets/dashboard_stat_card.dart';
import 'package:provider/provider.dart';

class FakeMachineService extends Fake implements MachineService {
  final Stream<List<MachineModel>>? machineStream;
  int streamCalls = 0;

  FakeMachineService({this.machineStream});

  @override
  Stream<List<MachineModel>> streamMachines({
    String? productionLine,
    String? status,
  }) {
    streamCalls++;
    return machineStream ?? const Stream<List<MachineModel>>.empty();
  }
}

class FakeFaultService extends Fake implements FaultService {
  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) {
    return const Stream<List<FaultModel>>.empty();
  }

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) async {
    return [];
  }
}

void main() {
  MachineModel makeMachine(String id, String name, String status) {
    return MachineModel(
      id: id,
      name: name,
      productionLine: 'Line A',
      status: status,
      healthScore: 90.0,
    );
  }

  Widget buildManagerDashboard(MachineProvider provider) {
    final managerUser = UserModel(
      id: 'mgr_uid_1',
      name: 'Operations Manager',
      email: 'manager@machalert.com',
      role: AppConstants.roleManager,
    );

    final appState = AppStateProvider()..setAuthenticated(managerUser);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        ChangeNotifierProvider<MachineProvider>.value(value: provider),
        Provider<FaultService>.value(value: FakeFaultService()),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  testWidgets(
    'Derives statistics accurately from normalized status equivalents (Operational/Running, Under Maintenance/In Maintenance, Critical/Breakdown, Warning/Other)',
    (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final service = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(buildManagerDashboard(provider));
      await tester.pumpAndSettle();

      // Emit machines with standard and equivalent casing/statuses:
      // Operational + Running = 2 running
      // Under Maintenance + In Maintenance = 2 in maintenance
      // Critical + Breakdown = 2 breakdown
      // Warning = 1 other / warning
      // Total = 7 (2 running + 2 maintenance + 2 breakdown + 1 other == 7)
      controller.add([
        makeMachine('M-1', 'CNC-1', 'Operational'),
        makeMachine('M-2', 'CNC-2', 'Running'),
        makeMachine('M-3', 'Press-1', 'Under Maintenance'),
        makeMachine('M-4', 'Press-2', 'In Maintenance'),
        makeMachine('M-5', 'Lathe-1', 'Warning'),
        makeMachine('M-6', 'Furnace-1', 'Critical'),
        makeMachine('M-7', 'Furnace-2', 'Breakdown'),
      ]);

      await tester.pump();
      await tester.pump();

      // Verify Total Machines
      final machinesCard = find.widgetWithText(DashboardStatCard, 'Machines');
      expect(find.descendant(of: machinesCard, matching: find.text('7')), findsOneWidget);

      // Verify Running
      final runningCard = find.widgetWithText(DashboardStatCard, 'Running');
      expect(find.descendant(of: runningCard, matching: find.text('2')), findsOneWidget);

      // Verify In Maintenance (Warning is NOT counted as active maintenance)
      final maintenanceCard = find.widgetWithText(DashboardStatCard, 'In Maintenance');
      expect(find.descendant(of: maintenanceCard, matching: find.text('2')), findsOneWidget);

      // Verify Breakdown
      final breakdownCard = find.widgetWithText(DashboardStatCard, 'Breakdown');
      expect(find.descendant(of: breakdownCard, matching: find.text('2')), findsOneWidget);

      // Verify Other / Unknown (Warning correctly mapped to Other)
      final otherCard = find.widgetWithText(DashboardStatCard, 'Other / Unknown');
      expect(find.descendant(of: otherCard, matching: find.text('1')), findsOneWidget);
    },
  );

  testWidgets(
    'Empty inventory produces genuine zero ("0") instead of "--"',
    (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final service = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(buildManagerDashboard(provider));
      await tester.pumpAndSettle();

      // Emit empty machine list
      controller.add([]);

      await tester.pump();
      await tester.pump();

      final machinesCard = find.widgetWithText(DashboardStatCard, 'Machines');
      final runningCard = find.widgetWithText(DashboardStatCard, 'Running');
      final maintenanceCard = find.widgetWithText(DashboardStatCard, 'In Maintenance');
      final breakdownCard = find.widgetWithText(DashboardStatCard, 'Breakdown');

      expect(find.descendant(of: machinesCard, matching: find.text('0')), findsOneWidget);
      expect(find.descendant(of: runningCard, matching: find.text('0')), findsOneWidget);
      expect(find.descendant(of: maintenanceCard, matching: find.text('0')), findsOneWidget);
      expect(find.descendant(of: breakdownCard, matching: find.text('0')), findsOneWidget);
    },
  );

  testWidgets(
    'Query failure displays error banner with Retry button; tapping Retry refreshes subscription',
    (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final service = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(buildManagerDashboard(provider));
      await tester.pumpAndSettle();

      expect(service.streamCalls, equals(1));

      // Simulate a network/permission error from Firestore
      controller.addError(
        MachineServiceException(
          code: 'unavailable',
          message: 'Failed to connect to machine database.',
        ),
      );

      await tester.pump();
      await tester.pump();

      // Error message is displayed
      expect(find.text('Failed to connect to machine database.'), findsOneWidget);

      // Cards display '--' instead of false zeros
      final machinesCard = find.widgetWithText(DashboardStatCard, 'Machines');
      expect(find.descendant(of: machinesCard, matching: find.text('--')), findsOneWidget);

      // Retry button is present
      final retryButton = find.byKey(const ValueKey('manager-stats-retry-button'));
      expect(retryButton, findsOneWidget);

      // Tap Retry
      await tester.tap(retryButton);
      await tester.pump();

      // Subscription is re-initiated
      expect(service.streamCalls, equals(2));
    },
  );

  testWidgets(
    'Live Firestore changes automatically update statistics in real-time',
    (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final service = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: service);
      addTearDown(provider.dispose);

      await tester.pumpWidget(buildManagerDashboard(provider));
      await tester.pumpAndSettle();

      // Initial state: 1 machine running
      controller.add([
        makeMachine('M-1', 'CNC-1', 'Operational'),
      ]);

      await tester.pump();
      await tester.pump();

      final runningCard = find.widgetWithText(DashboardStatCard, 'Running');
      final breakdownCard = find.widgetWithText(DashboardStatCard, 'Breakdown');

      expect(find.descendant(of: runningCard, matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: breakdownCard, matching: find.text('0')), findsOneWidget);

      // Live update: Machine broke down
      controller.add([
        makeMachine('M-1', 'CNC-1', 'Critical'),
      ]);

      await tester.pump();
      await tester.pump();

      // Stats update automatically in real-time
      expect(find.descendant(of: runningCard, matching: find.text('0')), findsOneWidget);
      expect(find.descendant(of: breakdownCard, matching: find.text('1')), findsOneWidget);
    },
  );
}
