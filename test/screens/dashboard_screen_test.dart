import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/faults/fault_history_screen.dart';
import 'package:mach_alert/screens/faults/realtime_faults_screen.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/widgets/dashboard_action_card.dart';
import 'package:mach_alert/widgets/dashboard_stat_card.dart';
import 'package:provider/provider.dart';

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() {
    return const Stream<User?>.empty();
  }

  @override
  Future<void> signOut() async {}
}

class FakeUserService extends Fake implements UserService {}

class FakeFaultService extends Fake implements FaultService {
  final Stream<List<FaultModel>>? faultStream;
  int streamCalls = 0;

  FakeFaultService({this.faultStream});

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
  }) async {
    return [];
  }

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
  }) {
    streamCalls++;
    return faultStream ?? const Stream.empty();
  }
}

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
    return machineStream ?? const Stream.empty();
  }
}

MachineModel createTestMachine({
  required String id,
  required String name,
  String productionLine = 'Line A',
  String status = 'Operational',
  double healthScore = 95.0,
}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: productionLine,
    status: status,
    healthScore: healthScore,
  );
}

UserModel createUser({required String role}) {
  return UserModel(
    id: 'user-1',
    name: 'Test User',
    email: 'test@machalert.com',
    role: role,
  );
}

FaultModel createTestFault({
  required String id,
  required String machineId,
  required String machineName,
  String severity = 'High',
  String status = 'Open',
  String description = 'Test motor vibration detected.',
}) {
  return FaultModel(
    id: id,
    machineId: machineId,
    machineName: machineName,
    type: 'Mechanical',
    severity: severity,
    description: description,
    reportedBy: 'user-1',
    reportedByName: 'Test Operator',
    status: status,
    createdAt: DateTime(2026, 10, 26, 12, 0),
  );
}

Future<void> pumpDashboard(
  WidgetTester tester, {
  required String role,
  FaultService? faultService,
  bool injectFaultServiceDirectly = true,
  MachineProvider? machineProvider,
}) async {
  final appState = AppStateProvider()..setAuthenticated(createUser(role: role));

  final authService = AuthService(firebaseAuth: FakeFirebaseAuth());
  final effectiveFaultService = faultService ?? FakeFaultService();

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());

    appState.dispose();
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        Provider<AuthService>.value(value: authService),
        Provider<FaultService>.value(value: effectiveFaultService),
        if (machineProvider != null)
          ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
      ],
      child: MaterialApp(
        home: HomeScreen(
          faultService: injectFaultServiceDirectly
              ? effectiveFaultService
              : null,
          machineProvider: machineProvider,
        ),
      ),
    ),
  );

  await tester.pump();
}

void main() {
  group('Role based dashboard UI', () {
    testWidgets('Operator sees operator dashboard actions', (tester) async {
      await pumpDashboard(tester, role: 'operator');

      expect(find.text('Operator Dashboard'), findsOneWidget);

      expect(find.text('Machines'), findsOneWidget);

      expect(find.text('Report Fault'), findsOneWidget);

      expect(find.text('Fault History'), findsOneWidget);

      expect(find.text('My Reports'), findsOneWidget);
    });

    testWidgets('Technician sees technician dashboard actions', (tester) async {
      await pumpDashboard(tester, role: 'technician');

      expect(find.text('Technician Dashboard'), findsOneWidget);

      expect(find.text('Assigned Maintenance'), findsOneWidget);

      expect(find.text('Active Faults'), findsWidgets);

      expect(find.text('Fault History'), findsOneWidget);

      expect(find.text('Machines'), findsOneWidget);
    });

    testWidgets('Manager sees manager dashboard actions', (tester) async {
      await pumpDashboard(tester, role: 'manager');

      expect(find.text('Manager Dashboard'), findsOneWidget);

      expect(find.text('Factory Overview'), findsOneWidget);

      expect(find.text('Machines'), findsWidgets);

      expect(find.text('Fault History'), findsOneWidget);

      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('Unknown role shows neutral dashboard', (tester) async {
      await pumpDashboard(tester, role: '');

      expect(find.text('Dashboard'), findsOneWidget);

      expect(find.text('Your role is being prepared.'), findsOneWidget);

      expect(find.text('Machines'), findsOneWidget);

      expect(find.text('Report Fault'), findsNothing);
    });

    testWidgets('Operator Machines action opens MachineListScreen', (
      tester,
    ) async {
      await pumpDashboard(tester, role: 'operator');

      final machinesButton = find.text('Machines');

      expect(machinesButton, findsOneWidget);

      await tester.ensureVisible(machinesButton);

      await tester.tap(machinesButton);

      await tester.pumpAndSettle();

      expect(find.byType(MachineListScreen), findsOneWidget);

      expect(find.text('No machines available'), findsOneWidget);
    });

    testWidgets('Machine screen back navigation returns to dashboard', (
      tester,
    ) async {
      await pumpDashboard(tester, role: 'operator');

      final machinesButton = find.text('Machines');

      await tester.ensureVisible(machinesButton);

      await tester.tap(machinesButton);

      await tester.pumpAndSettle();

      expect(find.byType(MachineListScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      expect(find.text('Operator Dashboard'), findsOneWidget);

      expect(find.byType(MachineListScreen), findsNothing);
    });

    testWidgets(
      'Operator Fault History action opens FaultHistoryScreen and shows title',
      (tester) async {
        await pumpDashboard(tester, role: 'operator');

        final faultHistoryButton = find.text('Fault History');
        expect(faultHistoryButton, findsOneWidget);

        await tester.ensureVisible(faultHistoryButton);
        await tester.tap(faultHistoryButton);
        await tester.pumpAndSettle();

        expect(find.byType(FaultHistoryScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Fault History'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Technician Fault History action opens FaultHistoryScreen and shows title',
      (tester) async {
        await pumpDashboard(tester, role: 'technician');

        final faultHistoryButton = find.text('Fault History');
        expect(faultHistoryButton, findsOneWidget);

        await tester.ensureVisible(faultHistoryButton);
        await tester.tap(faultHistoryButton);
        await tester.pumpAndSettle();

        expect(find.byType(FaultHistoryScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Fault History'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Manager Fault History action opens FaultHistoryScreen and shows title',
      (tester) async {
        await pumpDashboard(tester, role: 'manager');

        final faultHistoryButton = find.text('Fault History');
        expect(faultHistoryButton, findsOneWidget);

        await tester.ensureVisible(faultHistoryButton);
        await tester.tap(faultHistoryButton);
        await tester.pumpAndSettle();

        expect(find.byType(FaultHistoryScreen), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Fault History'),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('Real-time fault integration', () {
    testWidgets(
      'Manager Faults action opens RealtimeFaultsScreen with live stream updates',
      (tester) async {
        final controller = StreamController<List<FaultModel>>.broadcast();
        addTearDown(controller.close);

        final faultService = FakeFaultService(faultStream: controller.stream);
        await pumpDashboard(
          tester,
          role: 'manager',
          faultService: faultService,
        );

        final faultsCard = find.widgetWithText(DashboardActionCard, 'Faults');
        expect(faultsCard, findsOneWidget);

        await tester.ensureVisible(faultsCard);
        await tester.tap(faultsCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(RealtimeFaultsScreen), findsOneWidget);
        expect(find.text('Live Faults'), findsOneWidget);

        // Emit initial fault list
        controller.add([
          createTestFault(
            id: 'fault-01',
            machineId: 'cnc-01',
            machineName: 'CNC Milling Unit 01',
            severity: 'High',
          ),
        ]);
        await tester.pump();

        expect(find.text('1 live fault'), findsOneWidget);
        expect(find.text('CNC Milling Unit 01'), findsOneWidget);
        expect(find.text('cnc-01'), findsOneWidget);

        // Emit updated list without navigating away or manually refreshing
        controller.add([
          createTestFault(
            id: 'fault-01',
            machineId: 'cnc-01',
            machineName: 'CNC Milling Unit 01',
            severity: 'High',
          ),
          createTestFault(
            id: 'fault-02',
            machineId: 'press-02',
            machineName: 'Hydraulic Press 02',
            severity: 'Critical',
          ),
        ]);
        await tester.pump();

        expect(find.text('2 live faults'), findsOneWidget);
        expect(find.text('Hydraulic Press 02'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Card),
            matching: find.text('Critical'),
          ),
          findsOneWidget,
        );

        // Cleanly pop screen
        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Technician Active Faults action opens RealtimeFaultsScreen with live stream updates',
      (tester) async {
        final controller = StreamController<List<FaultModel>>.broadcast();
        addTearDown(controller.close);

        final faultService = FakeFaultService(faultStream: controller.stream);
        await pumpDashboard(
          tester,
          role: 'technician',
          faultService: faultService,
        );

        final activeFaultsCard = find.widgetWithText(
          DashboardActionCard,
          'Active Faults',
        );
        expect(activeFaultsCard, findsOneWidget);

        await tester.ensureVisible(activeFaultsCard);
        await tester.tap(activeFaultsCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(RealtimeFaultsScreen), findsOneWidget);

        // Emit initial fault list
        controller.add([
          createTestFault(
            id: 'fault-tech-01',
            machineId: 'lathe-03',
            machineName: 'Lathe Machine 03',
            severity: 'Medium',
          ),
        ]);
        await tester.pump();

        expect(find.text('1 live fault'), findsOneWidget);
        expect(find.text('Lathe Machine 03'), findsOneWidget);
        expect(find.text('lathe-03'), findsOneWidget);

        // Emit subsequent updated list dynamically
        controller.add([
          createTestFault(
            id: 'fault-tech-01',
            machineId: 'lathe-03',
            machineName: 'Lathe Machine 03',
            severity: 'Medium',
          ),
          createTestFault(
            id: 'fault-tech-02',
            machineId: 'drill-06',
            machineName: 'Radial Drill 06',
            severity: 'High',
          ),
        ]);
        await tester.pump();

        expect(find.text('2 live faults'), findsOneWidget);
        expect(find.text('Radial Drill 06'), findsOneWidget);

        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard navigation passes FaultService instance to RealtimeFaultsScreen',
      (tester) async {
        final controller = StreamController<List<FaultModel>>.broadcast();
        addTearDown(controller.close);

        final faultService = FakeFaultService(faultStream: controller.stream);
        await pumpDashboard(
          tester,
          role: 'manager',
          faultService: faultService,
        );

        final faultsCard = find.widgetWithText(DashboardActionCard, 'Faults');
        await tester.ensureVisible(faultsCard);
        await tester.tap(faultsCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final screen = tester.widget<RealtimeFaultsScreen>(
          find.byType(RealtimeFaultsScreen),
        );
        expect(screen.faultService, equals(faultService));
      },
    );

    testWidgets(
      'HomeScreen resolves FaultService from Provider when not directly injected',
      (tester) async {
        final controller = StreamController<List<FaultModel>>.broadcast();
        addTearDown(controller.close);

        final faultService = FakeFaultService(faultStream: controller.stream);
        await pumpDashboard(
          tester,
          role: 'manager',
          faultService: faultService,
          injectFaultServiceDirectly: false,
        );

        final faultsCard = find.widgetWithText(DashboardActionCard, 'Faults');
        await tester.ensureVisible(faultsCard);
        await tester.tap(faultsCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(RealtimeFaultsScreen), findsOneWidget);

        // Emit initial fault list
        controller.add([
          createTestFault(
            id: 'fault-provider-01',
            machineId: 'conveyor-04',
            machineName: 'Assembly Conveyor 04',
            severity: 'Low',
          ),
        ]);
        await tester.pump();

        expect(find.text('1 live fault'), findsOneWidget);
        expect(find.text('Assembly Conveyor 04'), findsOneWidget);

        // Emit subsequent updated list dynamically
        controller.add([
          createTestFault(
            id: 'fault-provider-01',
            machineId: 'conveyor-04',
            machineName: 'Assembly Conveyor 04',
            severity: 'Low',
          ),
          createTestFault(
            id: 'fault-provider-02',
            machineId: 'welder-05',
            machineName: 'Robotic Welder 05',
            severity: 'Critical',
          ),
        ]);
        await tester.pump();

        expect(find.text('2 live faults'), findsOneWidget);
        expect(find.text('Robotic Welder 05'), findsOneWidget);

        await tester.pageBack();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'MachAlertApp registers FaultService in application MultiProvider',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeAuthService = AuthService(firebaseAuth: FakeFirebaseAuth());

        await tester.pumpWidget(
          MachAlertApp(
            faultService: fakeFaultService,
            authService: fakeAuthService,
            userService: FakeUserService(),
          ),
        );

        final materialAppContext = tester.element(find.byType(MaterialApp));
        expect(
          materialAppContext.read<FaultService>(),
          equals(fakeFaultService),
        );
      },
    );
  });

  group('Manager Dashboard Machine Statistics', () {
    testWidgets('1. Manager dashboard triggers machine subscription', (
      tester,
    ) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: fakeService);
      addTearDown(provider.dispose);

      expect(provider.hasActiveSubscription, isFalse);
      expect(fakeService.streamCalls, equals(0));

      await pumpDashboard(tester, role: 'manager', machineProvider: provider);

      expect(provider.hasActiveSubscription, isTrue);
      expect(fakeService.streamCalls, equals(1));
    });

    testWidgets('2. Initial loading displays --', (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: fakeService);
      addTearDown(provider.dispose);

      await pumpDashboard(tester, role: 'manager', machineProvider: provider);

      final statCard = find.widgetWithText(DashboardStatCard, 'Machines');
      expect(
        find.descendant(of: statCard, matching: find.text('--')),
        findsOneWidget,
      );
    });

    testWidgets('3. Five machines produce count 5', (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: fakeService);
      addTearDown(provider.dispose);

      await pumpDashboard(tester, role: 'manager', machineProvider: provider);

      controller.add(
        List.generate(
          5,
          (i) => createTestMachine(id: 'm-$i', name: 'Machine $i'),
        ),
      );
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Machines');
      expect(
        find.descendant(of: statCard, matching: find.text('5')),
        findsOneWidget,
      );
    });

    testWidgets('4. Empty result displays 0', (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: fakeService);
      addTearDown(provider.dispose);

      await pumpDashboard(tester, role: 'manager', machineProvider: provider);

      controller.add([]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Machines');
      expect(
        find.descendant(of: statCard, matching: find.text('0')),
        findsOneWidget,
      );
    });

    testWidgets('5. New machine stream event updates the count', (
      tester,
    ) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: fakeService);
      addTearDown(provider.dispose);

      await pumpDashboard(tester, role: 'manager', machineProvider: provider);

      controller.add(
        List.generate(
          3,
          (i) => createTestMachine(id: 'm-$i', name: 'Machine $i'),
        ),
      );
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Machines');
      expect(
        find.descendant(of: statCard, matching: find.text('3')),
        findsOneWidget,
      );

      controller.add(
        List.generate(
          4,
          (i) => createTestMachine(id: 'm-$i', name: 'Machine $i'),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: statCard, matching: find.text('4')),
        findsOneWidget,
      );
    });

    testWidgets('6. Stream errors do not show false zero', (tester) async {
      final controller = StreamController<List<MachineModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeMachineService(machineStream: controller.stream);
      final provider = MachineProvider(machineService: fakeService);
      addTearDown(provider.dispose);

      await pumpDashboard(tester, role: 'manager', machineProvider: provider);

      controller.addError(
        MachineServiceException(
          code: 'unavailable',
          message: 'Firestore unavailable',
        ),
      );
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Machines');
      expect(
        find.descendant(of: statCard, matching: find.text('--')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: statCard, matching: find.text('0')),
        findsNothing,
      );
    });

    testWidgets(
      '7. Navigating to Machines does not create duplicate subscriptions',
      (tester) async {
        final controller = StreamController<List<MachineModel>>.broadcast();
        addTearDown(controller.close);

        final fakeService = FakeMachineService(
          machineStream: controller.stream,
        );
        final provider = MachineProvider(machineService: fakeService);
        addTearDown(provider.dispose);

        await pumpDashboard(tester, role: 'manager', machineProvider: provider);

        controller.add([createTestMachine(id: 'm-1', name: 'Machine 1')]);
        await tester.pump();
        await tester.pump();

        expect(fakeService.streamCalls, equals(1));

        final machinesCard = find.widgetWithText(
          DashboardActionCard,
          'Machines',
        );
        await tester.ensureVisible(machinesCard);
        await tester.tap(machinesCard);
        await tester.pumpAndSettle();

        expect(find.byType(MachineListScreen), findsOneWidget);
        expect(fakeService.streamCalls, equals(1));

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(fakeService.streamCalls, equals(1));
      },
    );
  });

  group('Manager Dashboard Active Fault Statistics', () {
    testWidgets('8. Initial loading displays --', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('--')),
        findsOneWidget,
      );
    });

    testWidgets('9. One Open fault produces count 1', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.add([
        createTestFault(
          id: 'fault-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'Open',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('10. One In Progress fault is included', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.add([
        createTestFault(
          id: 'fault-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'In Progress',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('11. Resolved faults are excluded', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.add([
        createTestFault(
          id: 'fault-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'Resolved',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('0')),
        findsOneWidget,
      );
    });

    testWidgets('12. Mixed statuses produce the correct active count', (
      tester,
    ) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.add([
        createTestFault(
          id: 'f-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'Open',
        ),
        createTestFault(
          id: 'f-2',
          machineId: 'm-2',
          machineName: 'M2',
          status: 'In Progress',
        ),
        createTestFault(
          id: 'f-3',
          machineId: 'm-3',
          machineName: 'M3',
          status: 'Resolved',
        ),
        createTestFault(
          id: 'f-4',
          machineId: 'm-4',
          machineName: 'M4',
          status: 'Resolved',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('13. New fault stream events update the count', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.add([
        createTestFault(
          id: 'f-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'Open',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('1')),
        findsOneWidget,
      );

      controller.add([
        createTestFault(
          id: 'f-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'Open',
        ),
        createTestFault(
          id: 'f-2',
          machineId: 'm-2',
          machineName: 'M2',
          status: 'Open',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: statCard, matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('14. Resolving a fault updates the count', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.add([
        createTestFault(
          id: 'f-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'Open',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('1')),
        findsOneWidget,
      );

      controller.add([
        createTestFault(
          id: 'f-1',
          machineId: 'm-1',
          machineName: 'M1',
          status: 'Resolved',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(of: statCard, matching: find.text('0')),
        findsOneWidget,
      );
    });

    testWidgets('15. Empty successful response displays 0', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.add([]);
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('0')),
        findsOneWidget,
      );
    });

    testWidgets('16. Stream error is handled safely', (tester) async {
      final controller = StreamController<List<FaultModel>>.broadcast();
      addTearDown(controller.close);

      final fakeService = FakeFaultService(faultStream: controller.stream);
      await pumpDashboard(tester, role: 'manager', faultService: fakeService);

      controller.addError(
        FaultServiceException(
          code: 'unavailable',
          message: 'Firestore unavailable',
        ),
      );
      await tester.pump();
      await tester.pump();

      final statCard = find.widgetWithText(DashboardStatCard, 'Active Faults');
      expect(
        find.descendant(of: statCard, matching: find.text('--')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: statCard, matching: find.text('0')),
        findsNothing,
      );
    });
  });

  group('Role regression', () {
    testWidgets(
      '17. Operator dashboard does not unnecessarily initialize manager-only statistics',
      (tester) async {
        final machineController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(machineController.close);
        final fakeMachineService = FakeMachineService(
          machineStream: machineController.stream,
        );
        final machineProvider = MachineProvider(
          machineService: fakeMachineService,
        );
        addTearDown(machineProvider.dispose);

        final faultController = StreamController<List<FaultModel>>.broadcast();
        addTearDown(faultController.close);
        final fakeFaultService = FakeFaultService(
          faultStream: faultController.stream,
        );

        await pumpDashboard(
          tester,
          role: 'operator',
          machineProvider: machineProvider,
          faultService: fakeFaultService,
        );

        expect(machineProvider.hasActiveSubscription, isFalse);
        expect(fakeMachineService.streamCalls, equals(0));
        expect(fakeFaultService.streamCalls, equals(0));
      },
    );

    testWidgets(
      '18. Manager-only statistics do not appear on Operator dashboard',
      (tester) async {
        await pumpDashboard(tester, role: 'operator');

        expect(find.text('Factory Overview'), findsNothing);
        expect(
          find.widgetWithText(DashboardStatCard, 'Machines'),
          findsNothing,
        );
        expect(
          find.widgetWithText(DashboardStatCard, 'Active Faults'),
          findsNothing,
        );
      },
    );

    testWidgets('19. Technician dashboard remains unaffected', (tester) async {
      await pumpDashboard(tester, role: 'technician');

      expect(find.text('Maintenance Overview'), findsOneWidget);
      expect(
        find.widgetWithText(DashboardStatCard, 'Assigned Tasks'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DashboardStatCard, 'Active Faults'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DashboardActionCard, 'Assigned Maintenance'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DashboardActionCard, 'Active Faults'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DashboardActionCard, 'Fault History'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(DashboardActionCard, 'Machines'),
        findsOneWidget,
      );
    });
  });
}
