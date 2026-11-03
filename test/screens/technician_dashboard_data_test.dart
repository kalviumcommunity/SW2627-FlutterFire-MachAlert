import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:mach_alert/widgets/dashboard_stat_card.dart';
import 'package:provider/provider.dart';

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? user;

  FakeFirebaseAuth({this.user});

  @override
  User? get currentUser => user;

  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(user);

  @override
  Future<void> signOut() async {}
}

class FakeFirebaseUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  FakeFirebaseUser({
    required this.uid,
    this.email = 'tech@machalert.com',
    this.displayName = 'Technician User',
  });
}

class FakeUserService extends Fake implements UserService {}

class FakeFaultService extends Fake implements FaultService {
  final Stream<List<FaultModel>>? faultStream;
  int streamCalls = 0;

  FakeFaultService({this.faultStream});

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
  }) {
    streamCalls++;
    return faultStream ?? const Stream<List<FaultModel>>.empty();
  }
}

class FakeMaintenanceService extends Fake implements MaintenanceService {
  final Stream<List<MaintenanceModel>>? tasksStream;
  int streamCalls = 0;

  FakeMaintenanceService({this.tasksStream});

  @override
  Stream<List<MaintenanceModel>> streamAssignedMaintenanceTasks({
    String? status,
    String? machineId,
    String? priority,
  }) {
    streamCalls++;
    return tasksStream ?? const Stream<List<MaintenanceModel>>.empty();
  }
}

UserModel createTechnicianUser({String uid = 'tech-001'}) {
  return UserModel(
    id: uid,
    name: 'Alex Tech',
    email: 'alex.tech@machalert.com',
    role: 'technician',
  );
}

FaultModel createTestFault({
  required String id,
  required String status,
  String machineId = 'm-01',
  String machineName = 'Drill Press',
}) {
  return FaultModel(
    id: id,
    machineId: machineId,
    machineName: machineName,
    type: 'Electrical',
    severity: 'High',
    description: 'Test fault description',
    reportedBy: 'user-op',
    status: status,
    createdAt: DateTime(2026, 11, 1),
  );
}

MaintenanceModel createTestMaintenanceTask({
  required String id,
  required String technicianId,
  required String status,
  String machineId = 'm-01',
}) {
  return MaintenanceModel(
    id: id,
    machineId: machineId,
    technicianId: technicianId,
    priority: 'High',
    status: status,
    createdAt: DateTime(2026, 11, 1),
  );
}

Widget buildTestWidget({
  required UserModel user,
  required FaultService faultService,
  required MaintenanceService maintenanceService,
  MachineProvider? machineProvider,
}) {
  final appState = AppStateProvider()..setAuthenticated(user);
  final fakeAuthUser = FakeFirebaseUser(uid: user.id, email: user.email);
  final authService = AuthService(
    firebaseAuth: FakeFirebaseAuth(user: fakeAuthUser),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      Provider<AuthService>.value(value: authService),
      Provider<FaultService>.value(value: faultService),
      Provider<MaintenanceService>.value(value: maintenanceService),
      if (machineProvider != null)
        ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: HomeScreen(
        faultService: faultService,
        maintenanceService: maintenanceService,
        machineProvider: machineProvider,
      ),
    ),
  );
}

void main() {
  group('Technician Dashboard Live Statistics Regression Tests', () {
    testWidgets(
      'Assigned Tasks counts active tasks (Pending and In Progress) and excludes Resolved tasks',
      (tester) async {
        final taskController =
            StreamController<List<MaintenanceModel>>.broadcast();
        final faultController =
            StreamController<List<FaultModel>>.broadcast();
        addTearDown(() async {
          await taskController.close();
          await faultController.close();
        });

        final faultService = FakeFaultService(faultStream: faultController.stream);
        final maintenanceService =
            FakeMaintenanceService(tasksStream: taskController.stream);
        final technician = createTechnicianUser(uid: 'tech-001');

        await tester.pumpWidget(
          buildTestWidget(
            user: technician,
            faultService: faultService,
            maintenanceService: maintenanceService,
          ),
        );
        await tester.pump();

        // Emit tasks: 1 Pending, 1 In Progress, 1 Resolved
        taskController.add([
          createTestMaintenanceTask(
            id: 'task-1',
            technicianId: 'tech-001',
            status: 'Pending',
          ),
          createTestMaintenanceTask(
            id: 'task-2',
            technicianId: 'tech-001',
            status: 'In Progress',
          ),
          createTestMaintenanceTask(
            id: 'task-3',
            technicianId: 'tech-001',
            status: 'Resolved',
          ),
        ]);
        await tester.pump();
        await tester.pump();

        final assignedTasksCard =
            find.widgetWithText(DashboardStatCard, 'Assigned Tasks');
        expect(assignedTasksCard, findsOneWidget);
        // Only Pending + In Progress = 2 tasks
        expect(
          find.descendant(of: assignedTasksCard, matching: find.text('2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Assigned Tasks with real MaintenanceService strictly filters by authenticated technician UID',
      (tester) async {
        final fakeFirestore = FakeFirebaseFirestore();
        const techUid = 'tech-auth-777';
        const otherTechUid = 'tech-other-999';

        // Add 4 tasks to fake Firestore
        await fakeFirestore.collection('maintenance').doc('task-a').set({
          'id': 'task-a',
          'machineId': 'm-01',
          'technicianId': techUid,
          'status': 'Pending',
          'priority': 'High',
        });
        await fakeFirestore.collection('maintenance').doc('task-b').set({
          'id': 'task-b',
          'machineId': 'm-02',
          'technicianId': techUid,
          'status': 'In Progress',
          'priority': 'Medium',
        });
        await fakeFirestore.collection('maintenance').doc('task-c').set({
          'id': 'task-c',
          'machineId': 'm-03',
          'technicianId': techUid,
          'status': 'Resolved',
          'priority': 'Low',
        });
        await fakeFirestore.collection('maintenance').doc('task-d').set({
          'id': 'task-d',
          'machineId': 'm-04',
          'technicianId': otherTechUid,
          'status': 'Pending',
          'priority': 'Critical',
        });

        final fakeAuthUser = FakeFirebaseUser(uid: techUid);
        final realMaintenanceService = MaintenanceService(
          firestore: fakeFirestore,
          firebaseAuth: FakeFirebaseAuth(user: fakeAuthUser),
        );
        final faultService = FakeFaultService(
          faultStream: Stream.value([]),
        );
        final technician = createTechnicianUser(uid: techUid);

        await tester.pumpWidget(
          buildTestWidget(
            user: technician,
            faultService: faultService,
            maintenanceService: realMaintenanceService,
          ),
        );
        // Allow stream emission and widget rebuild
        await tester.pump();
        await tester.pump();

        final assignedTasksCard =
            find.widgetWithText(DashboardStatCard, 'Assigned Tasks');
        expect(assignedTasksCard, findsOneWidget);
        // Only tasks assigned to techUid and not Resolved: task-a (Pending) + task-b (In Progress) = 2
        expect(
          find.descendant(of: assignedTasksCard, matching: find.text('2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Active Faults counts Open and In Progress faults, excluding Resolved faults',
      (tester) async {
        final taskController =
            StreamController<List<MaintenanceModel>>.broadcast();
        final faultController =
            StreamController<List<FaultModel>>.broadcast();
        addTearDown(() async {
          await taskController.close();
          await faultController.close();
        });

        final faultService = FakeFaultService(faultStream: faultController.stream);
        final maintenanceService =
            FakeMaintenanceService(tasksStream: taskController.stream);
        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildTestWidget(
            user: technician,
            faultService: faultService,
            maintenanceService: maintenanceService,
          ),
        );
        await tester.pump();

        // Emit faults: 1 Open, 1 In Progress, 1 Resolved, 1 Closed
        faultController.add([
          createTestFault(id: 'f-1', status: 'Open'),
          createTestFault(id: 'f-2', status: 'In Progress'),
          createTestFault(id: 'f-3', status: 'Resolved'),
          createTestFault(id: 'f-4', status: 'Closed'),
        ]);
        await tester.pump();
        await tester.pump();

        final activeFaultsCard =
            find.widgetWithText(DashboardStatCard, 'Active Faults');
        expect(activeFaultsCard, findsOneWidget);
        // Only Open + In Progress = 2 active faults
        expect(
          find.descendant(of: activeFaultsCard, matching: find.text('2')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Empty streams display 0 for both Assigned Tasks and Active Faults (not "--")',
      (tester) async {
        final faultService = FakeFaultService(faultStream: Stream.value([]));
        final maintenanceService =
            FakeMaintenanceService(tasksStream: Stream.value([]));
        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildTestWidget(
            user: technician,
            faultService: faultService,
            maintenanceService: maintenanceService,
          ),
        );
        await tester.pump();

        final assignedTasksCard =
            find.widgetWithText(DashboardStatCard, 'Assigned Tasks');
        final activeFaultsCard =
            find.widgetWithText(DashboardStatCard, 'Active Faults');

        expect(
          find.descendant(of: assignedTasksCard, matching: find.text('0')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: activeFaultsCard, matching: find.text('0')),
          findsOneWidget,
        );

        // Neither card should display '--'
        expect(
          find.descendant(of: assignedTasksCard, matching: find.text('--')),
          findsNothing,
        );
        expect(
          find.descendant(of: activeFaultsCard, matching: find.text('--')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Stream failure displays an error state without crashing',
      (tester) async {
        final taskController =
            StreamController<List<MaintenanceModel>>.broadcast();
        final faultController =
            StreamController<List<FaultModel>>.broadcast();
        addTearDown(() async {
          await taskController.close();
          await faultController.close();
        });

        final faultService = FakeFaultService(faultStream: faultController.stream);
        final maintenanceService =
            FakeMaintenanceService(tasksStream: taskController.stream);
        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildTestWidget(
            user: technician,
            faultService: faultService,
            maintenanceService: maintenanceService,
          ),
        );
        await tester.pump();

        // Emit error on both streams
        taskController.addError(Exception('Network error on tasks'));
        faultController.addError(Exception('Network error on faults'));
        await tester.pump();
        await tester.pump();

        final assignedTasksCard =
            find.widgetWithText(DashboardStatCard, 'Assigned Tasks');
        final activeFaultsCard =
            find.widgetWithText(DashboardStatCard, 'Active Faults');

        // Both cards show Error state
        expect(
          find.descendant(of: assignedTasksCard, matching: find.text('Error')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: activeFaultsCard, matching: find.text('Error')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Widget rebuild does not duplicate subscriptions or stream listeners',
      (tester) async {
        final taskController =
            StreamController<List<MaintenanceModel>>.broadcast();
        final faultController =
            StreamController<List<FaultModel>>.broadcast();
        addTearDown(() async {
          await taskController.close();
          await faultController.close();
        });

        final faultService = FakeFaultService(faultStream: faultController.stream);
        final maintenanceService =
            FakeMaintenanceService(tasksStream: taskController.stream);
        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildTestWidget(
            user: technician,
            faultService: faultService,
            maintenanceService: maintenanceService,
          ),
        );
        await tester.pump();

        expect(faultService.streamCalls, 1);
        expect(maintenanceService.streamCalls, 1);

        // Trigger rebuild with same widget configuration
        await tester.pumpWidget(
          buildTestWidget(
            user: technician,
            faultService: faultService,
            maintenanceService: maintenanceService,
          ),
        );
        await tester.pump();

        // Subscriptions should not have been duplicated
        expect(faultService.streamCalls, 1);
        expect(maintenanceService.streamCalls, 1);
      },
    );
  });
}
