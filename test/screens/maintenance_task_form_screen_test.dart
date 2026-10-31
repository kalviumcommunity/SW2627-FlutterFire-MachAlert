// ignore_for_file: subtype_of_sealed_class

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/screens/maintenance/maintenance_task_form_screen.dart';
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

  late MachineModel sampleMachine1;
  late MachineModel sampleMachine2;
  late UserModel sampleTech1;
  late UserModel sampleTech2;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth(
      initialUser: FakeUser(
        uid: 'manager_1',
        email: 'manager@machalert.com',
        displayName: 'Boss Manager',
      ),
    );

    maintenanceService = MaintenanceService(
      firestore: fakeFirestore,
      firebaseAuth: fakeAuth,
    );
    machineService = MachineService(firestore: fakeFirestore);
    userService = UserService(firestore: fakeFirestore);

    sampleMachine1 = MachineModel(
      id: 'MCH-01',
      name: 'CNC Milling Center',
      productionLine: 'Line A',
      status: AppConstants.machineStatusOperational,
      healthScore: 95.0,
    );
    sampleMachine2 = MachineModel(
      id: 'MCH-02',
      name: 'Hydraulic Press',
      productionLine: 'Line B',
      status: AppConstants.machineStatusWarning,
      healthScore: 80.0,
    );

    sampleTech1 = UserModel(
      id: 'tech_01',
      name: 'Alex Technician',
      email: 'alex@machalert.com',
      role: AppConstants.roleTechnician,
    );
    sampleTech2 = UserModel(
      id: 'tech_02',
      name: 'Bob Technician',
      email: 'bob@machalert.com',
      role: AppConstants.roleTechnician,
    );

    await machineService.addMachine(sampleMachine1);
    await machineService.addMachine(sampleMachine2);

    await fakeFirestore
        .collection('users')
        .doc(sampleTech1.id)
        .set(sampleTech1.toFirestoreMap());
    await fakeFirestore
        .collection('users')
        .doc(sampleTech2.id)
        .set(sampleTech2.toFirestoreMap());
  });

  Widget buildFormScreen({
    List<MachineModel>? initialMachines,
    List<UserModel>? initialTechnicians,
  }) {
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
                    initialMachines: initialMachines,
                    initialTechnicians: initialTechnicians,
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
    await tester.tap(find.text('Open Form'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    '12. Task assignment form loads valid machine and technician choices',
    (tester) async {
      await tester.pumpWidget(buildFormScreen());
      await openForm(tester);

      expect(find.text('Create Maintenance Task'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('maintenance-machine-dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-technician-dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-priority-dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-fault-id-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-notes-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-submit-task-button')),
        findsOneWidget,
      );

      // Open machine dropdown and verify options
      await tester.tap(
        find.byKey(const ValueKey('maintenance-machine-dropdown')),
      );
      await tester.pumpAndSettle();

      expect(find.text('CNC Milling Center (MCH-01)'), findsWidgets);
      expect(find.text('Hydraulic Press (MCH-02)'), findsWidgets);

      // Select Machine 1
      await tester.tap(find.text('CNC Milling Center (MCH-01)').last);
      await tester.pumpAndSettle();

      // Open technician dropdown and verify options
      await tester.tap(
        find.byKey(const ValueKey('maintenance-technician-dropdown')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alex Technician (tech_01)'), findsWidgets);
      expect(find.text('Bob Technician (tech_02)'), findsWidgets);
    },
  );

  testWidgets('13. Form validation prevents incomplete assignments', (
    tester,
  ) async {
    await tester.pumpWidget(buildFormScreen());
    await openForm(tester);

    // Tap submit without selecting machine or technician
    await tester.tap(
      find.byKey(const ValueKey('maintenance-submit-task-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Please select a machine'), findsOneWidget);
    expect(find.text('Please select a technician'), findsOneWidget);
  });

  testWidgets(
    '14. Successful task submission creates a Pending MaintenanceModel with correct values',
    (tester) async {
      await tester.pumpWidget(buildFormScreen());
      await openForm(tester);

      // 1. Select Machine
      await tester.tap(
        find.byKey(const ValueKey('maintenance-machine-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CNC Milling Center (MCH-01)').last);
      await tester.pumpAndSettle();

      // 2. Select Technician
      await tester.tap(
        find.byKey(const ValueKey('maintenance-technician-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex Technician (tech_01)').last);
      await tester.pumpAndSettle();

      // 3. Select Priority Critical
      await tester.tap(
        find.byKey(const ValueKey('maintenance-priority-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Critical').last);
      await tester.pumpAndSettle();

      // 4. Enter Fault ID and Notes
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-fault-id-field')),
        'FLT-999',
      );
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-notes-field')),
        'Inspect spindle vibration and gearbox lubricant',
      );

      // 5. Submit
      await tester.tap(
        find.byKey(const ValueKey('maintenance-submit-task-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Maintenance task created successfully'),
        findsOneWidget,
      );

      // Verify Firestore persisted document
      final snapshot = await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .get();

      expect(snapshot.docs.length, 1);
      final data = snapshot.docs.first.data();

      expect(data['machineId'], 'MCH-01');
      expect(data['machineName'], 'CNC Milling Center');
      expect(data['technicianId'], 'tech_01');
      expect(data['technicianName'], 'Alex Technician');
      expect(data['priority'], 'Critical');
      expect(data['status'], 'Pending');
      expect(data['faultId'], 'FLT-999');
      expect(data['notes'], 'Inspect spindle vibration and gearbox lubricant');
    },
  );

  testWidgets(
    '15. Creation failure displays a safe message and preserves form inputs',
    (tester) async {
      // Simulate unauthenticated user
      fakeAuth.setCurrentUser(null);

      await tester.pumpWidget(buildFormScreen());
      await openForm(tester);

      // Select Machine
      await tester.tap(
        find.byKey(const ValueKey('maintenance-machine-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CNC Milling Center (MCH-01)').last);
      await tester.pumpAndSettle();

      // Select Technician
      await tester.tap(
        find.byKey(const ValueKey('maintenance-technician-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex Technician (tech_01)').last);
      await tester.pumpAndSettle();

      // Enter Notes
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-notes-field')),
        'Draft maintenance notes',
      );

      // Submit
      await tester.tap(
        find.byKey(const ValueKey('maintenance-submit-task-button')),
      );
      await tester.pumpAndSettle();

      // Safe user-facing message displayed
      expect(
        find.text('User is not authenticated. Please log in.'),
        findsOneWidget,
      );

      // Form inputs preserved
      expect(find.text('Draft maintenance notes'), findsOneWidget);
    },
  );
}
