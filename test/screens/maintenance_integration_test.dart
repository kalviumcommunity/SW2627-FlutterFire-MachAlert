// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/maintenance/maintenance_details_screen.dart';
import 'package:mach_alert/screens/maintenance/maintenance_list_screen.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  FakeUser({required this.uid, this.email, this.displayName});
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  FakeFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  void setCurrentUser(User? user) {
    _currentUser = user;
  }
}

class FailingMaintenanceService extends Fake implements MaintenanceService {
  bool shouldFail = true;
  final MaintenanceService realService;

  FailingMaintenanceService(this.realService);

  @override
  Stream<List<MaintenanceModel>> streamMaintenanceTasks({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) {
    if (shouldFail) {
      return Stream.error(
        MaintenanceServiceException(
          code: 'unavailable',
          message: 'Firestore is currently unavailable. Please check your network connection.',
        ),
      );
    }
    return realService.streamMaintenanceTasks(
      technicianId: technicianId,
      machineId: machineId,
      status: status,
      priority: priority,
    );
  }

  @override
  Stream<List<MaintenanceModel>> streamAssignedMaintenanceTasks({
    String? status,
    String? machineId,
    String? priority,
  }) {
    if (shouldFail) {
      return Stream.error(
        MaintenanceServiceException(
          code: 'unavailable',
          message: 'Firestore is currently unavailable. Please check your network connection.',
        ),
      );
    }
    return realService.streamAssignedMaintenanceTasks(
      status: status,
      machineId: machineId,
      priority: priority,
    );
  }

  @override
  Future<String> createMaintenanceTask(MaintenanceModel task) =>
      realService.createMaintenanceTask(task);
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakeFirebaseAuth fakeAuth;
  late MaintenanceService maintenanceService;
  late UserService userService;
  late MachineService machineService;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth(
      initialUser: FakeUser(
        uid: 'user_mgr_1',
        email: 'manager@machalert.com',
        displayName: 'Plant Manager',
      ),
    );

    maintenanceService = MaintenanceService(
      firestore: fakeFirestore,
      firebaseAuth: fakeAuth,
    );
    userService = UserService(firestore: fakeFirestore);
    machineService = MachineService(firestore: fakeFirestore);
  });

  Widget buildMaintenanceApp({
    required UserModel currentUser,
    MaintenanceService? customService,
    bool assignedOnly = false,
  }) {
    final appState = AppStateProvider();
    appState.setAuthenticated(currentUser);

    // Seed current user in Firestore so AppStateProvider resolves role
    fakeFirestore
        .collection('users')
        .doc(currentUser.id)
        .set(currentUser.toFirestoreMap());

    fakeAuth.setCurrentUser(
      FakeUser(
        uid: currentUser.id,
        email: currentUser.email,
        displayName: currentUser.name,
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        Provider<MaintenanceService>.value(
          value: customService ?? maintenanceService,
        ),
        Provider<UserService>.value(value: userService),
        Provider<MachineService>.value(value: machineService),
      ],
      child: MaterialApp(
        home: MaintenanceListScreen(
          assignedOnly: assignedOnly,
          maintenanceService: customService ?? maintenanceService,
        ),
      ),
    );
  }

  void setLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    '1. MachAlertApp registers an injected MaintenanceService in root MultiProvider',
    (tester) async {
      final injectedService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      MaintenanceService? resolvedService;

      await tester.pumpWidget(
        MachAlertApp(
          maintenanceService: injectedService,
          userService: userService,
          machineService: machineService,
          appStateProvider: AppStateProvider(),
        ),
      );

      await tester.pump();

      // Access context inside MachAlertApp's child
      final builderFinder = find.byType(MaterialApp);
      final BuildContext context = tester.element(builderFinder);
      resolvedService = context.read<MaintenanceService>();

      expect(resolvedService, same(injectedService));
    },
  );

  testWidgets(
    '2 & 10. Manager maintenance screen requests the all-plant stream and shows task creation action',
    (tester) async {
      final manager = UserModel(
        id: 'mgr_01',
        name: 'Manager Bob',
        email: 'bob@machalert.com',
        role: AppConstants.roleManager,
      );

      // Seed plant tasks assigned to various technicians
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('TASK-1')
          .set({
            'id': 'TASK-1',
            'machineId': 'M-01',
            'machineName': 'Milling Center 1',
            'technicianId': 'tech_alpha',
            'technicianName': 'Alpha Tech',
            'priority': 'Critical',
            'status': 'Pending',
            'notes': 'Inspect main motor vibration',
            'createdAt': Timestamp.now(),
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('TASK-2')
          .set({
            'id': 'TASK-2',
            'machineId': 'M-02',
            'machineName': 'Press Unit 2',
            'technicianId': 'tech_beta',
            'technicianName': 'Beta Tech',
            'priority': 'High',
            'status': 'In Progress',
            'notes': 'Check hydraulic seal leak',
            'createdAt': Timestamp.now(),
          });

      await tester.pumpWidget(buildMaintenanceApp(currentUser: manager));
      await tester.pumpAndSettle();

      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Track machine maintenance activity'), findsOneWidget);

      // Manager sees all plant tasks
      expect(find.text('Inspect main motor vibration'), findsOneWidget);
      expect(find.text('Check hydraulic seal leak'), findsOneWidget);

      // 10. Manager sees Create Task FAB
      expect(
        find.byKey(const ValueKey('create-maintenance-task-fab')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '3 & 11. Technician screen requests assigned-task stream and does not see manager creation action',
    (tester) async {
      final technician = UserModel(
        id: 'tech_alpha',
        name: 'Alpha Tech',
        email: 'alpha@machalert.com',
        role: AppConstants.roleTechnician,
      );

      // Task for tech_alpha
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('TASK-ALPHA')
          .set({
            'id': 'TASK-ALPHA',
            'machineId': 'M-01',
            'machineName': 'Milling Center 1',
            'technicianId': 'tech_alpha',
            'technicianName': 'Alpha Tech',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Spindle alignment check',
            'createdAt': Timestamp.now(),
          });

      // Task for tech_beta (should NOT be visible to tech_alpha)
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('TASK-BETA')
          .set({
            'id': 'TASK-BETA',
            'machineId': 'M-02',
            'machineName': 'Press Unit 2',
            'technicianId': 'tech_beta',
            'technicianName': 'Beta Tech',
            'priority': 'Critical',
            'status': 'In Progress',
            'notes': 'Hydraulic valve repair',
            'createdAt': Timestamp.now(),
          });

      await tester.pumpWidget(
        buildMaintenanceApp(currentUser: technician, assignedOnly: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assigned Maintenance'), findsOneWidget);
      expect(find.text('Your assigned maintenance work'), findsOneWidget);

      // Sees only assigned task
      expect(find.text('Spindle alignment check'), findsOneWidget);
      expect(find.text('Hydraulic valve repair'), findsNothing);

      // 11. Technician does NOT see the Create Task FAB
      expect(
        find.byKey(const ValueKey('create-maintenance-task-fab')),
        findsNothing,
      );
    },
  );

  testWidgets(
    '4 & 5. Status chips query Pending/In Progress/Completed, and Completed maps to Resolved',
    (tester) async {
      setLargeViewport(tester);
      final manager = UserModel(
        id: 'mgr_01',
        name: 'Manager Bob',
        email: 'bob@machalert.com',
        role: AppConstants.roleManager,
      );

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('T-PENDING')
          .set({
            'id': 'T-PENDING',
            'machineId': 'M-1',
            'technicianId': 't1',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Pending maintenance task',
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('T-ACTIVE')
          .set({
            'id': 'T-ACTIVE',
            'machineId': 'M-2',
            'technicianId': 't1',
            'priority': 'Medium',
            'status': 'In Progress',
            'notes': 'Active in progress task',
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('T-RESOLVED')
          .set({
            'id': 'T-RESOLVED',
            'machineId': 'M-3',
            'technicianId': 't1',
            'priority': 'Low',
            'status': 'Resolved', // canonical Firestore value
            'notes': 'Resolved completed task',
          });

      await tester.pumpWidget(buildMaintenanceApp(currentUser: manager));
      await tester.pumpAndSettle();

      // All shows all 3
      expect(find.text('Pending maintenance task'), findsOneWidget);
      expect(find.text('Active in progress task'), findsOneWidget);
      expect(find.text('Resolved completed task'), findsOneWidget);

      // 4. Tap 'Pending' filter
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Pending maintenance task'), findsOneWidget);
      expect(find.text('Active in progress task'), findsNothing);
      expect(find.text('Resolved completed task'), findsNothing);

      // 4. Tap 'In Progress' filter
      await tester.tap(find.widgetWithText(ChoiceChip, 'In Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Pending maintenance task'), findsNothing);
      expect(find.text('Active in progress task'), findsOneWidget);
      expect(find.text('Resolved completed task'), findsNothing);

      // 5. Tap 'Completed' filter -> queries 'Resolved'
      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Resolved completed task'), findsOneWidget);
      expect(find.text('Pending maintenance task'), findsNothing);
      expect(find.text('Active in progress task'), findsNothing);
    },
  );

  testWidgets(
    '6 & 7. Actual MaintenanceModel data appears in task cards sorted by priority (Critical > High > Medium > Low)',
    (tester) async {
      setLargeViewport(tester);
      final manager = UserModel(
        id: 'mgr_01',
        name: 'Manager Bob',
        email: 'bob@machalert.com',
        role: AppConstants.roleManager,
      );

      final now = DateTime(2026, 10, 20);

      // Insert tasks out of priority order: Low, Critical, Medium, High
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('1')
          .set({
            'id': '1',
            'machineId': 'M-LOW',
            'machineName': 'Low Unit',
            'technicianId': 't_low',
            'technicianName': 'Low Tech',
            'priority': 'Low',
            'status': 'Pending',
            'notes': 'Low Priority Routine Inspection',
            'createdAt': Timestamp.fromDate(now),
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('2')
          .set({
            'id': '2',
            'machineId': 'M-CRIT',
            'machineName': 'Critical Unit',
            'technicianId': 't_crit',
            'technicianName': 'Crit Tech',
            'priority': 'Critical',
            'status': 'Pending',
            'notes': 'Critical Overheating Alert',
            'createdAt': Timestamp.fromDate(now),
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('3')
          .set({
            'id': '3',
            'machineId': 'M-MED',
            'machineName': 'Medium Unit',
            'technicianId': 't_med',
            'technicianName': 'Med Tech',
            'priority': 'Medium',
            'status': 'Pending',
            'notes': 'Medium Filter Check',
            'createdAt': Timestamp.fromDate(now),
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('4')
          .set({
            'id': '4',
            'machineId': 'M-HIGH',
            'machineName': 'High Unit',
            'technicianId': 't_high',
            'technicianName': 'High Tech',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'High Vibration Alert',
            'createdAt': Timestamp.fromDate(now),
          });

      await tester.pumpWidget(buildMaintenanceApp(currentUser: manager));
      await tester.pumpAndSettle();

      // 6. Data appears in task cards
      expect(find.text('Critical Overheating Alert'), findsOneWidget);
      expect(find.text('Critical Unit'), findsOneWidget);
      expect(find.text('Crit Tech'), findsOneWidget);
      expect(find.text('Assigned: 2026-10-20'), findsWidgets);

      // 7. Verify priority order Critical > High > Medium > Low
      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where(
            (data) =>
                data == 'Critical Overheating Alert' ||
                data == 'High Vibration Alert' ||
                data == 'Medium Filter Check' ||
                data == 'Low Priority Routine Inspection',
          )
          .toList();

      expect(titles, [
        'Critical Overheating Alert',
        'High Vibration Alert',
        'Medium Filter Check',
        'Low Priority Routine Inspection',
      ]);
    },
  );

  testWidgets(
    '8 & 16. Real-time stream emissions and task creation update the visible list live',
    (tester) async {
      final manager = UserModel(
        id: 'mgr_01',
        name: 'Manager Bob',
        email: 'bob@machalert.com',
        role: AppConstants.roleManager,
      );

      await tester.pumpWidget(buildMaintenanceApp(currentUser: manager));
      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('No maintenance tasks found'), findsOneWidget);

      // Add task via service
      await maintenanceService.createMaintenanceTask(
        MaintenanceModel(
          id: '',
          machineId: 'M-LIVE-01',
          machineName: 'Live Conveyor',
          technicianId: 'tech_01',
          technicianName: 'Live Technician',
          priority: 'High',
          status: 'Pending',
          notes: 'Emergency live inspection required',
        ),
      );

      // Stream automatically updates
      await tester.pumpAndSettle();

      expect(find.text('Emergency live inspection required'), findsOneWidget);
      expect(find.text('Live Conveyor'), findsOneWidget);
      expect(find.text('Live Technician'), findsOneWidget);
      expect(find.text('No maintenance tasks found'), findsNothing);
    },
  );

  testWidgets('9. Stream errors and retry behavior work', (tester) async {
    final manager = UserModel(
      id: 'mgr_01',
      name: 'Manager Bob',
      email: 'bob@machalert.com',
      role: AppConstants.roleManager,
    );

    final failingService = FailingMaintenanceService(maintenanceService);

    await tester.pumpWidget(
      buildMaintenanceApp(currentUser: manager, customService: failingService),
    );
    await tester.pumpAndSettle();

    // Error state displayed
    expect(find.text('Unable to load maintenance tasks'), findsOneWidget);
    expect(
      find.text(
        'Firestore is currently unavailable. Please check your network connection.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    // Recover failure and tap Retry
    failingService.shouldFail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load maintenance tasks'), findsNothing);
    expect(find.text('No maintenance tasks found'), findsOneWidget);
  });

  testWidgets(
    '17. Operators cannot access maintenance management functionality',
    (tester) async {
      final operator = UserModel(
        id: 'op_01',
        name: 'Operator Joe',
        email: 'joe@machalert.com',
        role: AppConstants.roleOperator,
      );

      await tester.pumpWidget(buildMaintenanceApp(currentUser: operator));
      await tester.pumpAndSettle();

      // Operator access restricted
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(
        find.text(
          'Maintenance tasks are only accessible to technicians and managers.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('create-maintenance-task-fab')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Tapping task card forwards selected MaintenanceModel details to MaintenanceDetailsScreen',
    (tester) async {
      final manager = UserModel(
        id: 'mgr_01',
        name: 'Manager Bob',
        email: 'bob@machalert.com',
        role: AppConstants.roleManager,
      );

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('MNT-REAL-01')
          .set({
            'id': 'MNT-REAL-01',
            'machineId': 'M-101',
            'machineName': 'Robotic Welder 01',
            'technicianId': 'tech_weld',
            'technicianName': 'Welding Specialist',
            'priority': 'Critical',
            'status': 'Pending',
            'notes': 'Inspect weld tip temperature sensor',
            'createdAt': Timestamp.fromDate(DateTime(2026, 10, 25)),
          });

      await tester.pumpWidget(buildMaintenanceApp(currentUser: manager));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inspect weld tip temperature sensor'));
      await tester.pumpAndSettle();

      expect(find.byType(MaintenanceDetailsScreen), findsOneWidget);
      expect(find.text('Maintenance Details'), findsOneWidget);
      expect(find.text('MNT-REAL-01'), findsOneWidget);
      expect(find.text('Robotic Welder 01'), findsOneWidget);
      expect(find.text('Welding Specialist'), findsOneWidget);
      expect(find.text('Critical'), findsWidgets);
      expect(find.text('2026-10-25'), findsOneWidget);
      expect(find.text('Inspect weld tip temperature sensor'), findsWidgets);
    },
  );
}
