import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/faults/fault_reporting_screen.dart';
import 'package:mach_alert/screens/reports/reports_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/utils/mock_machine_data.dart';
import 'package:mach_alert/widgets/dashboard_stat_card.dart';
import 'package:provider/provider.dart';

class _FakeAuthService extends Fake implements AuthService {
  @override
  Future<void> signOut() async {}
}

class _FakeFaultService extends Fake implements FaultService {
  int addFaultCallCount = 0;
  FaultModel? lastSubmittedFault;

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

  @override
  Future<String> addFault(FaultModel fault) async {
    addFaultCallCount++;
    lastSubmittedFault = fault;
    return 'fault-doc-123';
  }
}

class _FakeStorageService extends Fake implements StorageService {}

class _FakeMachineService extends Fake implements MachineService {
  final Stream<List<MachineModel>>? machineStream;
  int streamCalls = 0;

  _FakeMachineService({this.machineStream});

  @override
  Stream<List<MachineModel>> streamMachines({
    String? productionLine,
    String? status,
  }) {
    streamCalls++;
    return machineStream ?? const Stream<List<MachineModel>>.empty();
  }
}

Widget _wrapWithProviders({
  required Widget child,
  required UserModel user,
  required MachineProvider machineProvider,
  FaultService? faultService,
}) {
  final appState = AppStateProvider()..setAuthenticated(user);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
      Provider<AuthService>.value(value: _FakeAuthService()),
      Provider<FaultService>.value(value: faultService ?? _FakeFaultService()),
      Provider<UserService>.value(value: FakeUserService()),
    ],
    child: MaterialApp(home: child),
  );
}

class FakeUserService extends Fake implements UserService {}

void main() {
  group('Machine Counts Reconciliation & Overflow Tests', () {
    final managerUser = UserModel(
      id: 'manager-1',
      name: 'Operations Manager',
      email: 'manager@machalert.com',
      role: AppConstants.roleManager,
    );

    final technicianUser = UserModel(
      id: 'tech-1',
      name: 'Shift Technician',
      email: 'tech@machalert.com',
      role: AppConstants.roleTechnician,
    );

    final operatorUser = UserModel(
      id: 'op-1',
      name: 'Floor Operator',
      email: 'operator@machalert.com',
      role: AppConstants.roleOperator,
    );

    testWidgets(
      '1, 2, 3, 4, 5: Dashboard and Reports show matching reconciled factory-wide machine counts',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService = _FakeMachineService(
          machineStream: streamController.stream,
        );
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        final sampleMachines = MockMachineData.sampleMachines;
        streamController.add(sampleMachines);

        // 1. Pump Manager Dashboard
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const HomeScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify Dashboard Counts (5 Total: 2 Running, 1 Maintenance, 1 Breakdown, 1 Other/Warning)
        final totalStat = find.widgetWithText(DashboardStatCard, 'Machines');
        final runningStat = find.widgetWithText(DashboardStatCard, 'Running');
        final maintenanceStat = find.widgetWithText(
          DashboardStatCard,
          'In Maintenance',
        );
        final breakdownStat = find.widgetWithText(
          DashboardStatCard,
          'Breakdown',
        );
        final otherStat = find.widgetWithText(
          DashboardStatCard,
          'Other / Unknown',
        );

        expect(
          find.descendant(of: totalStat, matching: find.text('5')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: runningStat, matching: find.text('2')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: maintenanceStat, matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: breakdownStat, matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: otherStat, matching: find.text('1')),
          findsOneWidget,
        );

        // 2. Pump Reports Screen
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const ReportsScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Verify Reports Screen Counts: Total Machines = 5 (replaces hardcoded 12)
        expect(find.text('5'), findsOneWidget);
        expect(find.text('12'), findsNothing);

        // Verify Reports Screen Legend Breakdown matches Dashboard exactly:
        // Running: 2 (40%)
        // Maintenance: 1 (20%)
        // Breakdown: 1 (20%)
        // Other / Unknown: 1 (20%)
        expect(find.text('2 (40%)'), findsOneWidget); // Running
        expect(find.text('1 (20%)'), findsNWidgets(3)); // Maintenance, Breakdown, Other / Unknown
        expect(
          find.text('8 (67%)'),
          findsNothing,
        ); // Hardcoded mock value removed!
        expect(
          find.text('2 (17%)'),
          findsNothing,
        ); // Hardcoded mock value removed!

        // Verify Donut chart contains segments for Running, Maintenance, Breakdown, and Other / Warning
        final donutFinder = find.byType(MachineStatusDonutChart);
        expect(donutFinder, findsOneWidget);
        final customPaint = tester.widget<CustomPaint>(
          find.descendant(of: donutFinder, matching: find.byType(CustomPaint)),
        );
        final painter = customPaint.painter as MachineStatusDonutPainter;
        expect(painter.segments.length, equals(4));
        expect(
          painter.segments.any((s) => s.color == const Color(0xFF788896) && s.count == 1),
          isTrue,
        );

        // 5. Invariant: 2 running + 1 maintenance + 1 breakdown + 1 other == 5 total
        final stats = machineProvider.statistics;
        expect(stats.total, equals(5));
        expect(stats.running, equals(2));
        expect(stats.maintenance, equals(1));
        expect(stats.breakdown, equals(1));
        expect(stats.other, equals(1));
        expect(
          stats.running + stats.maintenance + stats.breakdown + stats.other,
          equals(stats.total),
        );
      },
    );

    testWidgets(
      '5b. Unrecognized machine statuses are explicitly shown as Other/Unknown and do not inflate Maintenance',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService = _FakeMachineService(
          machineStream: streamController.stream,
        );
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        // 5 canonical machines + 1 with unrecognized status 'Decommissioned'
        final mixedMachines = [
          ...MockMachineData.sampleMachines,
          MachineModel(
            id: 'mock-decommissioned-06',
            name: 'Decommissioned Press 06',
            productionLine: 'Line D',
            status: 'Decommissioned',
            healthScore: 0.0,
          ),
        ];

        streamController.add(mixedMachines);

        // Pump Dashboard
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const HomeScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Total Machines: 6
        final totalStat = find.widgetWithText(DashboardStatCard, 'Machines');
        expect(
          find.descendant(of: totalStat, matching: find.text('6')),
          findsOneWidget,
        );

        // Running: 2, Maintenance: 1 (NOT inflated!), Breakdown: 1, Other/Unknown: 2 (Warning + Decommissioned)
        final runningStat = find.widgetWithText(DashboardStatCard, 'Running');
        final maintenanceStat = find.widgetWithText(
          DashboardStatCard,
          'In Maintenance',
        );
        final breakdownStat = find.widgetWithText(
          DashboardStatCard,
          'Breakdown',
        );
        final otherStat = find.widgetWithText(
          DashboardStatCard,
          'Other / Unknown',
        );

        expect(
          find.descendant(of: runningStat, matching: find.text('2')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: maintenanceStat, matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: breakdownStat, matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: otherStat, matching: find.text('2')),
          findsOneWidget,
        );

        // Pump Reports Screen
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const ReportsScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Total 6 machines in Donut center
        expect(find.text('6'), findsOneWidget);

        // Reports shows Other / Unknown legend with count and percentage: 2 of 6 = 33%
        expect(find.text('Other / Unknown'), findsOneWidget);
        // Both Running (2 of 6 = 33%) and Other / Unknown (2 of 6 = 33%) display '2 (33%)'
        expect(find.text('2 (33%)'), findsNWidgets(2));
        // Both Breakdown (1 of 6 = 17%) and Maintenance (1 of 6 = 17%) display '1 (17%)'
        expect(find.text('1 (17%)'), findsNWidgets(2));

        // Verify Donut chart itself includes the Other category in its painted segments
        final donutFinder = find.byType(MachineStatusDonutChart);
        expect(donutFinder, findsOneWidget);
        final customPaint = tester.widget<CustomPaint>(
          find.descendant(of: donutFinder, matching: find.byType(CustomPaint)),
        );
        final painter = customPaint.painter as MachineStatusDonutPainter;
        expect(
          painter.segments.any(
            (s) => s.color == const Color(0xFF788896) && s.count == 2,
          ),
          isTrue,
        );

        // Reconciles: 2 Running + 1 Maintenance + 1 Breakdown + 2 Other == 6 Total
        final stats = machineProvider.statistics;
        expect(stats.total, equals(6));
        expect(stats.running, equals(2));
        expect(stats.maintenance, equals(1));
        expect(stats.breakdown, equals(1));
        expect(stats.other, equals(2));
        expect(
          stats.running + stats.maintenance + stats.breakdown + stats.other,
          equals(stats.total),
        );
      },
    );

    testWidgets(
      '6. New Firestore machine documents update both screens in real time',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService = _FakeMachineService(
          machineStream: streamController.stream,
        );
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        // Start with 5 machines
        streamController.add(MockMachineData.sampleMachines);

        // Pump Dashboard
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const HomeScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump();

        final totalStat = find.widgetWithText(DashboardStatCard, 'Machines');
        expect(
          find.descendant(of: totalStat, matching: find.text('5')),
          findsOneWidget,
        );

        // Now emit 6 machines (new Operational machine added)
        final updatedList = [
          ...MockMachineData.sampleMachines,
          MachineModel(
            id: 'mock-lathe-06',
            name: 'CNC Lathe 06',
            productionLine: 'Line C',
            status: AppConstants.machineStatusOperational,
            healthScore: 98.0,
          ),
        ];
        streamController.add(updatedList);
        await tester.pump();
        await tester.pump();

        // Dashboard immediately updates to 6 machines, 3 running
        expect(
          find.descendant(of: totalStat, matching: find.text('6')),
          findsOneWidget,
        );
        final runningStat = find.widgetWithText(DashboardStatCard, 'Running');
        expect(
          find.descendant(of: runningStat, matching: find.text('3')),
          findsOneWidget,
        );

        // Pump Reports Screen and confirm synchronized 6 machines, 3 running
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const ReportsScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('6'), findsOneWidget);
        expect(find.text('3 (50%)'), findsOneWidget); // 3 of 6 running = 50%
      },
    );

    testWidgets(
      '7. Removed or changed machine documents update aggregates correctly',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService = _FakeMachineService(
          machineStream: streamController.stream,
        );
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        // Start with 5 machines
        streamController.add(MockMachineData.sampleMachines);

        // Transition mock-press-02 to Critical (now 2 Critical breakdowns, 1 Maintenance)
        final modifiedMachines = MockMachineData.sampleMachines.map((m) {
          if (m.id == 'mock-press-02') {
            return m.copyWith(status: AppConstants.machineStatusCritical);
          }
          return m;
        }).toList();

        streamController.add(modifiedMachines);

        // Pump Reports
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const ReportsScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump();

        // Total 5 machines: 2 Running (40%), 1 Maintenance (20%), 2 Breakdown (40%)
        expect(find.text('5'), findsOneWidget);
        expect(find.text('2 (40%)'), findsNWidgets(2)); // Running & Breakdown
        expect(find.text('1 (20%)'), findsOneWidget); // Maintenance

        // Now remove a machine (5 -> 4 machines)
        streamController.add(modifiedMachines.sublist(0, 4));
        await tester.pump();
        await tester.pump();

        expect(find.text('4'), findsOneWidget);
      },
    );

    testWidgets(
      '8. Loading and error states do not display fabricated counts on Dashboard or Reports',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService = _FakeMachineService(
          machineStream: streamController.stream,
        );
        // Provider in loading state (subscribed but nothing emitted yet)
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        // Pump Dashboard while loading
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const HomeScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        final totalStat = find.widgetWithText(DashboardStatCard, 'Machines');
        expect(
          find.descendant(of: totalStat, matching: find.text('--')),
          findsOneWidget,
        );
        expect(find.text('12'), findsNothing);
        expect(find.text('5'), findsNothing);

        // Pump Reports Screen while loading
        await tester.pumpWidget(
          _wrapWithProviders(
            child: const ReportsScreen(),
            user: managerUser,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        // Reports displays loading indicator instead of fabricated 12
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('12'), findsNothing);
        expect(find.text('8 (67%)'), findsNothing);

        // Emit error on stream
        streamController.addError(Exception('Firestore offline'));
        await tester.pump();
        await tester.pump();

        // Error state displays error with Retry button instead of fabricated counts
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('12'), findsNothing);
      },
    );

    testWidgets(
      '9, 10: Long machine names do not cause horizontal overflow and dropdown arrow remains visible',
      (tester) async {
        final longNamedMachine = MachineModel(
          id: 'M-SUPER-EXTENDED-LINE-099-ALPHA-OMEGA-SERIES-HEAVY-DUTY',
          name: 'Industrial Ultra-High Precision 5-Axis Multi-Spindle Computerized Numerical Control Machine 99 - Line Omega',
          productionLine: 'High-Velocity Stamping Division Line Beta Extended',
          status: 'Operational',
          healthScore: 99.0,
        );

        // Pump on narrow screen width (320px) to stress layout bounds
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FaultReportingScreen(
                machines: [longNamedMachine],
                initialMachine: longNamedMachine,
                faultService: _FakeFaultService(),
                storageService: _FakeStorageService(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 9. Verify NO exception/overflow was thrown
        expect(tester.takeException(), isNull);

        // 10. Dropdown arrow remains visible
        expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);

        // The card preserves the complete name and ID
        expect(find.text(longNamedMachine.name), findsOneWidget);
        expect(find.text(longNamedMachine.id), findsOneWidget);
      },
    );

    testWidgets(
      '11. Machine selection and fault reporting still work with long machine names',
      (tester) async {
        final longNamedMachine = MachineModel(
          id: 'M-SPECIAL-LONG-ID-99',
          name: 'Extra Long Hydraulic Press Machine 99 Specialized',
          productionLine: 'Line Stamping',
          status: 'Operational',
          healthScore: 85.0,
        );

        final faultService = _FakeFaultService();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FaultReportingScreen(
                machines: [longNamedMachine],
                faultService: faultService,
                storageService: _FakeStorageService(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Select machine from dropdown
        final dropdownFinder = find
            .byType(DropdownButtonFormField<String>)
            .first;
        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        final menuItemFinder = find
            .text('${longNamedMachine.id} - ${longNamedMachine.name}')
            .last;
        await tester.tap(menuItemFinder);
        await tester.pumpAndSettle();

        // Selected machine card appears
        expect(find.text(longNamedMachine.name), findsOneWidget);
        expect(find.text(longNamedMachine.id), findsOneWidget);

        // Fill out required fault fields
        final descField = find.byType(TextFormField);
        await tester.ensureVisible(descField);
        await tester.pumpAndSettle();
        await tester.enterText(
          descField,
          'Excessive oil spraying around piston.',
        );
        await tester.pumpAndSettle();

        // Select fault type
        final faultTypeDropdown = find
            .byType(DropdownButtonFormField<String>)
            .at(1);
        await tester.ensureVisible(faultTypeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(faultTypeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mechanical').last);
        await tester.pumpAndSettle();

        // Select severity
        final chip = find.widgetWithText(ChoiceChip, 'High');
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();

        // Submit form
        final submitButton = find.widgetWithText(
          FilledButton,
          'Submit Fault Report',
        );
        await tester.ensureVisible(submitButton);
        await tester.pumpAndSettle();
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Verify fault service was called with selected machine ID
        expect(faultService.addFaultCallCount, equals(1));
        expect(
          faultService.lastSubmittedFault?.machineId,
          equals(longNamedMachine.id),
        );
        expect(
          faultService.lastSubmittedFault?.description,
          equals('Excessive oil spraying around piston.'),
        );
      },
    );

    testWidgets('12. Existing role permissions remain intact on Dashboard', (
      tester,
    ) async {
      final streamController = StreamController<List<MachineModel>>.broadcast();
      addTearDown(streamController.close);

      final machineService = _FakeMachineService(
        machineStream: streamController.stream,
      );
      final machineProvider = MachineProvider(
        machineService: machineService,
        autoSubscribe: true,
      );
      addTearDown(machineProvider.dispose);

      streamController.add(MockMachineData.sampleMachines);

      // Manager sees Factory Overview
      await tester.pumpWidget(
        _wrapWithProviders(
          child: const HomeScreen(),
          user: managerUser,
          machineProvider: machineProvider,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Factory Overview'), findsOneWidget);
      expect(
        find.widgetWithText(DashboardStatCard, 'Machines'),
        findsOneWidget,
      );

      // Technician sees Maintenance Overview, NOT Factory Overview
      await tester.pumpWidget(
        _wrapWithProviders(
          child: const HomeScreen(),
          user: technicianUser,
          machineProvider: machineProvider,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Maintenance Overview'), findsOneWidget);
      expect(find.text('Factory Overview'), findsNothing);

      // Operator does NOT see Factory Overview
      await tester.pumpWidget(
        _wrapWithProviders(
          child: const HomeScreen(),
          user: operatorUser,
          machineProvider: machineProvider,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Operator Dashboard'), findsOneWidget);
      expect(find.text('Factory Overview'), findsNothing);
    });
  });
}
