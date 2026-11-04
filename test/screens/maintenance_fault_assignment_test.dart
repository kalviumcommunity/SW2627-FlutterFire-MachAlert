// ignore_for_file: subtype_of_sealed_class

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/screens/maintenance/maintenance_task_form_screen.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

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

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakeFirebaseAuth fakeAuth;
  late MaintenanceService maintenanceService;
  late MachineService machineService;
  late UserService userService;
  late FaultService faultService;

  late MachineModel machineA;
  late MachineModel machineB;
  late UserModel techAlex;
  late UserModel techBob;
  late FaultModel openFaultA1;
  late FaultModel inProgressFaultA2;
  late FaultModel resolvedFaultA3;
  late FaultModel openFaultB1;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth(
      initialUser: FakeUser(
        uid: 'mgr_uid_123',
        email: 'manager@machalert.com',
        displayName: 'Plant Manager',
      ),
    );

    maintenanceService = MaintenanceService(
      firestore: fakeFirestore,
      firebaseAuth: fakeAuth,
    );
    machineService = MachineService(firestore: fakeFirestore);
    userService = UserService(firestore: fakeFirestore);
    faultService = FaultService(
      firestore: fakeFirestore,
      firebaseAuth: fakeAuth,
    );

    machineA = MachineModel(
      id: 'MCH-01',
      name: 'CNC Milling Center',
      productionLine: 'Line A',
      status: AppConstants.machineStatusOperational,
      healthScore: 92.0,
    );
    machineB = MachineModel(
      id: 'MCH-02',
      name: 'Hydraulic Press',
      productionLine: 'Line B',
      status: AppConstants.machineStatusWarning,
      healthScore: 78.0,
    );

    techAlex = UserModel(
      id: 'tech_uid_alex_888',
      name: 'Alex Technician',
      email: 'alex@machalert.com',
      role: AppConstants.roleTechnician,
    );
    techBob = UserModel(
      id: 'tech_uid_bob_999',
      name: 'Bob Technician',
      email: 'bob@machalert.com',
      role: AppConstants.roleTechnician,
    );

    openFaultA1 = FaultModel(
      id: 'FLT-DOC-101',
      machineId: 'MCH-01',
      machineName: 'CNC Milling Center',
      type: 'Mechanical',
      severity: 'Critical',
      status: 'Open',
      description: 'Spindle bearing overheating',
      reportedBy: 'op_uid_1',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

    inProgressFaultA2 = FaultModel(
      id: 'FLT-DOC-102',
      machineId: 'MCH-01',
      machineName: 'CNC Milling Center',
      type: 'Electrical',
      severity: 'High',
      status: 'In Progress',
      description: 'Coolant pump voltage fluctuation',
      reportedBy: 'op_uid_2',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    );

    resolvedFaultA3 = FaultModel(
      id: 'FLT-DOC-103',
      machineId: 'MCH-01',
      machineName: 'CNC Milling Center',
      type: 'Hydraulic',
      severity: 'Low',
      status: 'Resolved',
      description: 'Minor fitting leak fixed',
      reportedBy: 'op_uid_1',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );

    openFaultB1 = FaultModel(
      id: 'FLT-DOC-201',
      machineId: 'MCH-02',
      machineName: 'Hydraulic Press',
      type: 'Hydraulic',
      severity: 'Critical',
      status: 'Open',
      description: 'Cylinder pressure drop',
      reportedBy: 'op_uid_3',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

    await machineService.addMachine(machineA);
    await machineService.addMachine(machineB);

    await fakeFirestore.collection('users').doc(techAlex.id).set(techAlex.toFirestoreMap());
    await fakeFirestore.collection('users').doc(techBob.id).set(techBob.toFirestoreMap());

    await fakeFirestore.collection('faults').doc(openFaultA1.id).set(openFaultA1.toFirestoreMap());
    await fakeFirestore.collection('faults').doc(inProgressFaultA2.id).set(inProgressFaultA2.toFirestoreMap());
    await fakeFirestore.collection('faults').doc(resolvedFaultA3.id).set(resolvedFaultA3.toFirestoreMap());
    await fakeFirestore.collection('faults').doc(openFaultB1.id).set(openFaultB1.toFirestoreMap());
  });

  Widget buildScreen() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MaintenanceTaskFormScreen(
                    maintenanceService: maintenanceService,
                    userService: userService,
                    machineService: machineService,
                    faultService: faultService,
                    initialMachines: [machineA, machineB],
                    initialTechnicians: [techAlex, techBob],
                    initialFaults: [
                      openFaultA1,
                      inProgressFaultA2,
                      resolvedFaultA3,
                      openFaultB1,
                    ],
                  ),
                ),
              );
            },
            child: const Text('Open Form'),
          ),
        ),
      ),
    );
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Technician dropdown shows readable names and never exposes raw Firebase UIDs',
    (tester) async {
      await openForm(tester);

      // Open technician dropdown
      await tester.tap(find.byKey(const ValueKey('maintenance-technician-dropdown')));
      await tester.pumpAndSettle();

      // Readable names are present
      expect(find.text('Alex Technician'), findsWidgets);
      expect(find.text('Bob Technician'), findsWidgets);

      // Raw Firebase UIDs are NEVER exposed in labels
      expect(find.textContaining('tech_uid_alex_888'), findsNothing);
      expect(find.textContaining('tech_uid_bob_999'), findsNothing);
    },
  );

  testWidgets(
    'Fault selector requires selecting a machine first; shows eligible faults for selected machine only',
    (tester) async {
      await openForm(tester);

      // Before selecting a machine, default option is None (Preventive Maintenance)
      expect(find.text('None (Preventive Maintenance)'), findsOneWidget);

      // 1. Select Machine A
      await tester.tap(find.byKey(const ValueKey('maintenance-machine-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CNC Milling Center (MCH-01)').last);
      await tester.pumpAndSettle();

      // Open Fault dropdown
      await tester.tap(find.byKey(const ValueKey('maintenance-fault-id-field')));
      await tester.pumpAndSettle();

      // Eligible faults for Machine A (Open & In Progress) must be displayed
      expect(find.textContaining('Spindle bearing overheating'), findsWidgets);
      expect(find.textContaining('Coolant pump voltage fluctuation'), findsWidgets);

      // Resolved faults on Machine A must NOT be listed
      expect(find.textContaining('Minor fitting leak fixed'), findsNothing);

      // Faults belonging to Machine B must NOT be listed under Machine A
      expect(find.textContaining('Cylinder pressure drop'), findsNothing);
    },
  );

  testWidgets(
    'Switching machine clears previously selected fault and reloads faults for new machine',
    (tester) async {
      await openForm(tester);

      // 1. Select Machine A
      await tester.tap(find.byKey(const ValueKey('maintenance-machine-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CNC Milling Center (MCH-01)').last);
      await tester.pumpAndSettle();

      // Select fault on Machine A
      await tester.tap(find.byKey(const ValueKey('maintenance-fault-id-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Spindle bearing overheating').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Spindle bearing overheating'), findsOneWidget);

      // 2. Switch Machine to Machine B
      await tester.tap(find.byKey(const ValueKey('maintenance-machine-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hydraulic Press (MCH-02)').last);
      await tester.pumpAndSettle();

      // Selected fault should be reset to None (Preventive Maintenance)
      expect(find.text('None (Preventive Maintenance)'), findsOneWidget);
      expect(find.textContaining('Spindle bearing overheating'), findsNothing);

      // Open Fault dropdown on Machine B
      await tester.tap(find.byKey(const ValueKey('maintenance-fault-id-field')));
      await tester.pumpAndSettle();

      // Now only Machine B faults appear
      expect(find.textContaining('Cylinder pressure drop'), findsWidgets);
      expect(find.textContaining('Spindle bearing overheating'), findsNothing);
    },
  );

  testWidgets(
    'Assigning maintenance with linked fault stores canonical fault document ID in Firestore and assigns technician',
    (tester) async {
      await openForm(tester);

      // 1. Select Machine A
      await tester.tap(find.byKey(const ValueKey('maintenance-machine-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CNC Milling Center (MCH-01)').last);
      await tester.pumpAndSettle();

      // 2. Select Technician Alex
      await tester.tap(find.byKey(const ValueKey('maintenance-technician-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex Technician').last);
      await tester.pumpAndSettle();

      // 3. Select Fault A1
      await tester.tap(find.byKey(const ValueKey('maintenance-fault-id-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Spindle bearing overheating').last);
      await tester.pumpAndSettle();

      // 4. Enter Notes
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-notes-field')),
        'Replace bearings and flush lubricating channel',
      );

      // 5. Submit
      await tester.tap(find.byKey(const ValueKey('maintenance-submit-task-button')));
      await tester.pumpAndSettle();

      expect(find.text('Maintenance task created successfully'), findsOneWidget);

      // Verify Firestore persisted document
      final snapshot = await fakeFirestore.collection(AppConstants.maintenanceCollection).get();
      expect(snapshot.docs.length, 1);
      final doc = snapshot.docs.first.data();

      // Canonical fault ID FLT-DOC-101 is saved (NOT machine ID or user UID)
      expect(doc['faultId'], equals('FLT-DOC-101'));
      expect(doc['faultId'], isNot(equals('MCH-01')));
      expect(doc['faultId'], isNot(equals('mgr_uid_123')));
      expect(doc['faultId'], isNot(equals('tech_uid_alex_888')));

      // Machine and technician assignments
      expect(doc['machineId'], equals('MCH-01'));
      expect(doc['machineName'], equals('CNC Milling Center'));
      expect(doc['technicianId'], equals('tech_uid_alex_888'));
      expect(doc['technicianName'], equals('Alex Technician'));
      expect(doc['status'], equals('Pending'));
      expect(doc['notes'], equals('Replace bearings and flush lubricating channel'));

      // Assigned technician can query this task immediately
      fakeAuth.setCurrentUser(FakeUser(
        uid: 'tech_uid_alex_888',
        email: 'alex@machalert.com',
        displayName: 'Alex Technician',
      ));
      final assignedTasks = await maintenanceService.getAssignedMaintenanceTasks();
      expect(assignedTasks.length, 1);
      expect(assignedTasks.first.faultId, equals('FLT-DOC-101'));
    },
  );

  testWidgets(
    'Preventive maintenance assignment without linked fault stores null faultId',
    (tester) async {
      await openForm(tester);

      // 1. Select Machine B
      await tester.tap(find.byKey(const ValueKey('maintenance-machine-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hydraulic Press (MCH-02)').last);
      await tester.pumpAndSettle();

      // 2. Select Technician Bob
      await tester.tap(find.byKey(const ValueKey('maintenance-technician-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob Technician').last);
      await tester.pumpAndSettle();

      // 3. Keep Fault dropdown on None (Preventive Maintenance)
      expect(find.text('None (Preventive Maintenance)'), findsOneWidget);

      // 4. Enter notes
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-notes-field')),
        'Monthly hydraulic pressure calibration',
      );

      // 5. Submit
      await tester.tap(find.byKey(const ValueKey('maintenance-submit-task-button')));
      await tester.pumpAndSettle();

      expect(find.text('Maintenance task created successfully'), findsOneWidget);

      final snapshot = await fakeFirestore.collection(AppConstants.maintenanceCollection).get();
      expect(snapshot.docs.length, 1);
      final doc = snapshot.docs.first.data();

      // faultId must be null for preventive maintenance
      expect(doc['faultId'], isNull);
      expect(doc['machineId'], equals('MCH-02'));
      expect(doc['technicianId'], equals('tech_uid_bob_999'));
    },
  );
}
