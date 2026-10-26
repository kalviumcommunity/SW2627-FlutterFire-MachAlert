import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/faults/fault_history_screen.dart';
import 'package:mach_alert/screens/faults/realtime_faults_screen.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/widgets/dashboard_action_card.dart';
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

  FakeFaultService({this.faultStream});

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
  }) async {
    return [];
  }

  @override
  Stream<List<FaultModel>> streamFaults({String? machineId, String? status}) {
    return faultStream ?? const Stream.empty();
  }
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
      ],
      child: MaterialApp(
        home: HomeScreen(
          faultService: injectFaultServiceDirectly
              ? effectiveFaultService
              : null,
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
        expect(find.text('Critical'), findsOneWidget);

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
}
