import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/reports/reports_screen.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

class MockMachineService extends Fake implements MachineService {
  final List<MachineModel> machines;
  MockMachineService({this.machines = const []});

  @override
  Stream<List<MachineModel>> streamMachines({String? productionLine, String? status}) {
    return Stream.value(machines);
  }

  @override
  Future<List<MachineModel>> getMachines({String? productionLine, String? status}) async {
    return machines;
  }
}

class MockFaultService extends Fake implements FaultService {
  final List<FaultModel> faults;
  MockFaultService({this.faults = const []});

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) {
    return Stream.value(faults);
  }

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) async {
    return faults;
  }
}

Widget createReportsScreenTestWidget({
  required MachineProvider machineProvider,
  FaultService? faultService,
  List<FaultModel>? initialFaults,
  String? reportingPeriod,
  Size? physicalSize,
}) {
  final manager = UserModel(
    id: 'mgr-001',
    name: 'Plant Manager',
    email: 'manager@machalert.com',
    role: AppConstants.roleManager,
  );

  final appState = AppStateProvider()..setAuthenticated(manager);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
      if (faultService != null)
        Provider<FaultService>.value(value: faultService),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ReportsScreen(
        machineProvider: machineProvider,
        faultService: faultService,
        initialFaults: initialFaults,
        reportingPeriod: reportingPeriod,
      ),
    ),
  );
}

void main() {
  group('REPORTS SCREEN FINAL QA REMEDIATION — TABS & DATA INTEGRITY', () {
    late MachineModel machineRunning;
    late MachineModel machineBreakdown;
    late MachineModel machineInspected;
    late List<MachineModel> testMachines;

    late FaultModel faultOpenCritical;
    late FaultModel faultInProgressHigh;
    late FaultModel faultResolved;
    late List<FaultModel> testFaults;

    setUp(() {
      machineRunning = MachineModel(
        id: 'mach-01',
        name: 'CNC Milling Unit 1',
        productionLine: 'Line A',
        status: 'Running',
        healthScore: 95.0,
      );

      machineBreakdown = MachineModel(
        id: 'mach-02',
        name: 'Hydraulic Press 2',
        productionLine: 'Line B',
        status: 'Breakdown',
        healthScore: 20.0,
      );

      machineInspected = MachineModel(
        id: 'mach-03',
        name: 'Lathe Station 3',
        productionLine: 'Line A',
        status: 'Operational',
        healthScore: 88.0,
        lastInspection: DateTime(2026, 10, 20, 14, 30),
      );

      testMachines = [machineRunning, machineBreakdown, machineInspected];

      faultOpenCritical = FaultModel(
        id: 'flt-101',
        machineId: 'mach-02',
        machineName: 'Hydraulic Press 2',
        type: 'Hydraulic',
        severity: AppConstants.severityCritical,
        description: 'Main cylinder blown pressure seal causing emergency halt.',
        reportedBy: 'user-op-1',
        reportedByName: 'John Doe',
        status: AppConstants.faultStatusOpen,
        createdAt: DateTime(2026, 10, 15, 9, 0),
      );

      faultInProgressHigh = FaultModel(
        id: 'flt-102',
        machineId: 'mach-01',
        machineName: 'CNC Milling Unit 1',
        type: 'Mechanical',
        severity: AppConstants.severityHigh,
        description: 'Spindle bearing vibration threshold exceeded.',
        reportedBy: 'user-op-2',
        reportedByName: 'Jane Smith',
        status: AppConstants.faultStatusInProgress,
        createdAt: DateTime(2026, 10, 28, 11, 15),
      );

      faultResolved = FaultModel(
        id: 'flt-103',
        machineId: 'mach-03',
        machineName: 'Lathe Station 3',
        type: 'Electrical',
        severity: AppConstants.severityMedium,
        description: 'Drive motor coolant relay replaced.',
        reportedBy: 'user-tech-1',
        reportedByName: 'Alex Tech',
        status: AppConstants.faultStatusResolved,
        createdAt: DateTime(2026, 11, 2, 16, 45),
      );

      testFaults = [faultOpenCritical, faultInProgressHigh, faultResolved];
    });

    testWidgets('1. Every tab displays distinct genuine content', (tester) async {
      final machineService = MockMachineService(machines: testMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);
      final faultService = MockFaultService(faults: testFaults);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      // --- Tab 0: Overview ---
      expect(find.text('Machine Status'), findsOneWidget);
      expect(find.byType(MachineStatusDonutChart), findsOneWidget);
      expect(find.text('Events Trend'), findsOneWidget);
      expect(find.text('Insufficient Historical Trend Data'), findsOneWidget);
      expect(find.text('Inspections Status'), findsNothing);
      expect(find.text('Breakdown Statistics'), findsNothing);

      // --- Switch to Tab 1: Inspections ---
      await tester.tap(find.byKey(const ValueKey('reports-tab-inspections')));
      await tester.pumpAndSettle();

      expect(find.text('Inspections Status'), findsOneWidget);
      expect(find.text('No Inspection Records Persisted'), findsOneWidget);
      expect(find.text('Audit Note: Telemetry data is never simulated.'), findsOneWidget);
      expect(find.text('Machine Status'), findsNothing);
      expect(find.text('Breakdown Statistics'), findsNothing);

      // --- Switch to Tab 2: Breakdowns ---
      await tester.tap(find.byKey(const ValueKey('reports-tab-breakdowns')));
      await tester.pumpAndSettle();

      expect(find.text('Breakdown Statistics'), findsOneWidget);
      expect(find.text('Total Incidents'), findsOneWidget);
      expect(find.text('Active Faults'), findsOneWidget);
      expect(find.text('Critical Severity'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.text('Machines in Breakdown Status'), findsOneWidget);
      expect(find.text('Recorded Breakdown Incidents'), findsOneWidget);
      expect(find.text('Machine Status'), findsNothing);
      expect(find.text('Inspections Status'), findsNothing);
    });

    testWidgets('2. Tab switching works repeatedly without state corruption', (tester) async {
      final machineService = MockMachineService(machines: testMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);
      final faultService = MockFaultService(faults: testFaults);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      // Overview -> Inspections -> Breakdowns -> Overview -> Breakdowns -> Inspections
      await tester.tap(find.byKey(const ValueKey('reports-tab-inspections')));
      await tester.pumpAndSettle();
      expect(find.text('Inspections Status'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reports-tab-breakdowns')));
      await tester.pumpAndSettle();
      expect(find.text('Breakdown Statistics'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reports-tab-overview')));
      await tester.pumpAndSettle();
      expect(find.text('Machine Status'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reports-tab-breakdowns')));
      await tester.pumpAndSettle();
      expect(find.text('Breakdown Statistics'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reports-tab-inspections')));
      await tester.pumpAndSettle();
      expect(find.text('Inspections Status'), findsOneWidget);
    });

    testWidgets('3. Empty inspection data is handled honestly with machine timestamps', (tester) async {
      // 1 machine has lastInspection, other machines have null
      final machineService = MockMachineService(machines: testMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);
      final faultService = MockFaultService(faults: const []);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('reports-tab-inspections')));
      await tester.pumpAndSettle();

      // Honest explanation
      expect(find.text('No Inspection Records Persisted'), findsOneWidget);
      expect(
        find.textContaining('Standalone routine inspection collections are not configured in this database release'),
        findsOneWidget,
      );

      // Only the genuine inspected machine timestamp is displayed
      expect(find.text('Lathe Station 3'), findsOneWidget);
      expect(find.text('Last Inspected: Oct 20, 2026'), findsOneWidget);
      expect(find.text('CNC Milling Unit 1'), findsNothing); // Not inspected
    });

    testWidgets('3b. Completely uninspected fleet displays explicit honest empty notice', (tester) async {
      final uninspectedMachines = [
        MachineModel(id: 'm1', name: 'M1', productionLine: 'Line 1', status: 'Running', healthScore: 90.0),
        MachineModel(id: 'm2', name: 'M2', productionLine: 'Line 2', status: 'Running', healthScore: 85.0),
      ];

      final machineService = MockMachineService(machines: uninspectedMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          initialFaults: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('reports-tab-inspections')));
      await tester.pumpAndSettle();

      expect(
        find.text('None of the 2 registered machines have a recorded inspection timestamp.'),
        findsOneWidget,
      );
    });

    testWidgets('4. Breakdown statistics use real Firestore records', (tester) async {
      final machineService = MockMachineService(machines: testMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);
      final faultService = MockFaultService(faults: testFaults);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('reports-tab-breakdowns')));
      await tester.pumpAndSettle();

      // Metric cards
      // Total = 3
      expect(find.text('3'), findsOneWidget);
      // Active = 2 (1 open + 1 in progress)
      expect(find.text('2'), findsOneWidget);
      // Critical = 1, Resolved = 1 (2 metric cards showing '1')
      expect(find.text('1'), findsNWidgets(2));

      // Machine in breakdown status: mach-02 Hydraulic Press 2
      expect(find.text('Hydraulic Press 2'), findsWidgets);
      expect(find.text('ID: mach-02 • Line: Line B'), findsOneWidget);

      // Fault details
      expect(find.text('Main cylinder blown pressure seal causing emergency halt.'), findsOneWidget);
      expect(find.text('Spindle bearing vibration threshold exceeded.'), findsOneWidget);
      expect(find.text('Drive motor coolant relay replaced.'), findsOneWidget);
    });

    testWidgets('4b. Empty breakdown records display clean empty state', (tester) async {
      final normalMachines = [
        MachineModel(id: 'm1', name: 'Lathe', productionLine: 'Line 1', status: 'Running', healthScore: 92.0),
      ];
      final machineService = MockMachineService(machines: normalMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          initialFaults: const [],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('reports-tab-breakdowns')));
      await tester.pumpAndSettle();

      expect(find.text('No machines currently in Breakdown or Critical status.'), findsOneWidget);
      expect(find.text('No breakdown or fault incidents recorded in Firestore.'), findsOneWidget);
    });

    testWidgets('5. Date ranges reflect actual available record timestamps', (tester) async {
      // testFaults span Oct 15, 2026 to Nov 2, 2026
      final machineService = MockMachineService(machines: testMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);
      final faultService = MockFaultService(faults: testFaults);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      // Dynamic date range computed from actual timestamps (Oct 15, 2026 - Nov 2, 2026)
      expect(find.text('Oct 15, 2026 - Nov 2, 2026'), findsOneWidget);
      // Verified removed hardcoded string
      expect(find.text('Oct 1, 2026 - Oct 10, 2026'), findsNothing);
    });

    testWidgets('5b. Live operational data label displayed when no timestamps are present', (tester) async {
      final undatedMachines = [
        MachineModel(id: 'm1', name: 'Press', productionLine: 'L1', status: 'Running', healthScore: 88.0),
      ];
      final machineService = MockMachineService(machines: undatedMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          initialFaults: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Operational Data (All Time)'), findsOneWidget);
      expect(find.text('Oct 1, 2026 - Oct 10, 2026'), findsNothing);
    });

    testWidgets('6. Trend charts never use fabricated production curves', (tester) async {
      final machineService = MockMachineService(machines: testMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);
      final faultService = MockFaultService(faults: testFaults);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      // Verified insufficient data state rendered honestly
      expect(find.text('Insufficient Historical Trend Data'), findsOneWidget);
      expect(
        find.textContaining('MachAlert displays authentic real-time records rather than simulated telemetry curves'),
        findsOneWidget,
      );
      expect(find.text('Live Breakdowns: 3'), findsOneWidget);
      expect(find.text('Inspection Logs: Not tracked'), findsOneWidget);
    });

    testWidgets('7. Responsive layout remains valid at 320px width across all 3 tabs', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final machineService = MockMachineService(machines: testMachines);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);
      final faultService = MockFaultService(faults: testFaults);

      await tester.pumpWidget(
        createReportsScreenTestWidget(
          machineProvider: machineProvider,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      // Check Tab 0 at 320px
      expect(tester.takeException(), isNull);

      // Check Tab 1 at 320px
      await tester.tap(find.byKey(const ValueKey('reports-tab-inspections')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Check Tab 2 at 320px
      await tester.tap(find.byKey(const ValueKey('reports-tab-breakdowns')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
