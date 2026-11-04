// ignore_for_file: subtype_of_sealed_class

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/faults/fault_history_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/storage_service.dart';
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

class MockStorageService extends Fake implements StorageService {
  @override
  Future<String> getSignedUrl(String path, {int expiresInSeconds = 3600}) async {
    return 'https://supabase-signed-url.example.com/$path?token=xyz';
  }
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakeFirebaseAuth fakeAuth;
  late FaultService faultService;
  late MockStorageService mockStorageService;

  late FaultModel operatorFaultA;
  late FaultModel operatorFaultB;

  const operatorAUid = 'operator_alice_111';
  const operatorBUid = 'operator_bob_222';
  const managerUid = 'manager_boss_333';
  const technicianUid = 'technician_dan_444';

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth(
      initialUser: FakeUser(
        uid: operatorAUid,
        email: 'alice@machalert.com',
        displayName: 'Alice Operator',
      ),
    );

    faultService = FaultService(
      firestore: fakeFirestore,
      firebaseAuth: fakeAuth,
    );
    mockStorageService = MockStorageService();

    operatorFaultA = FaultModel(
      id: 'FLT-A-001',
      machineId: 'MCH-01',
      machineName: 'CNC Milling Center',
      type: 'Mechanical',
      severity: 'Critical',
      status: 'Open',
      description: 'Motor vibration on spindle',
      reportedBy: operatorAUid,
      reportedByName: 'Alice Operator',
      storagePath: '$operatorAUid/spindle.jpg',
      storageProvider: 'supabase',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    );

    operatorFaultB = FaultModel(
      id: 'FLT-B-002',
      machineId: 'MCH-02',
      machineName: 'Hydraulic Press',
      type: 'Hydraulic',
      severity: 'High',
      status: 'In Progress',
      description: 'Hydraulic valve pressure drop',
      reportedBy: operatorBUid,
      reportedByName: 'Bob Operator',
      storagePath: '$operatorBUid/valve.jpg',
      storageProvider: 'supabase',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    );

    await fakeFirestore.collection('faults').doc(operatorFaultA.id).set(operatorFaultA.toFirestoreMap());
    await fakeFirestore.collection('faults').doc(operatorFaultB.id).set(operatorFaultB.toFirestoreMap());
  });

  Widget buildFaultHistoryScreen({
    required String role,
    required String uid,
    required String name,
  }) {
    final user = UserModel(
      id: uid,
      name: name,
      email: '$role@machalert.com',
      role: role,
    );

    fakeAuth.setCurrentUser(FakeUser(uid: uid, displayName: name));

    final appState = AppStateProvider()..setAuthenticated(user);
    final authService = AuthService(firebaseAuth: fakeAuth);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        Provider<AuthService>.value(value: authService),
        Provider<FaultService>.value(value: faultService),
        Provider<StorageService>.value(value: mockStorageService),
      ],
      child: MaterialApp(
        home: FaultHistoryScreen(
          faultService: faultService,
          storageService: mockStorageService,
          userService: UserService(firestore: fakeFirestore),
        ),
      ),
    );
  }

  test('FaultService.getFaultImageUrl allows Managers to view all plant-wide photos', () async {
    final urlA = await faultService.getFaultImageUrl(
      operatorFaultA,
      storageService: mockStorageService,
      callerRole: AppConstants.roleManager,
      callerUid: managerUid,
    );
    expect(urlA, isNotNull);
    expect(urlA, contains('spindle.jpg'));

    final urlB = await faultService.getFaultImageUrl(
      operatorFaultB,
      storageService: mockStorageService,
      callerRole: AppConstants.roleManager,
      callerUid: managerUid,
    );
    expect(urlB, isNotNull);
    expect(urlB, contains('valve.jpg'));
  });

  test('FaultService.getFaultImageUrl allows Technicians to view all plant-wide photos', () async {
    final urlA = await faultService.getFaultImageUrl(
      operatorFaultA,
      storageService: mockStorageService,
      callerRole: AppConstants.roleTechnician,
      callerUid: technicianUid,
    );
    expect(urlA, isNotNull);
    expect(urlA, contains('spindle.jpg'));

    final urlB = await faultService.getFaultImageUrl(
      operatorFaultB,
      storageService: mockStorageService,
      callerRole: AppConstants.roleTechnician,
      callerUid: technicianUid,
    );
    expect(urlB, isNotNull);
    expect(urlB, contains('valve.jpg'));
  });

  test('FaultService.getFaultImageUrl allows Operator to view their OWN photo only', () async {
    // Alice viewing her own fault photo -> permitted
    final ownUrl = await faultService.getFaultImageUrl(
      operatorFaultA,
      storageService: mockStorageService,
      callerRole: AppConstants.roleOperator,
      callerUid: operatorAUid,
    );
    expect(ownUrl, isNotNull);
    expect(ownUrl, contains('spindle.jpg'));

    // Alice viewing Bob's foreign photo -> DENIED (returns null)
    final foreignUrl = await faultService.getFaultImageUrl(
      operatorFaultB,
      storageService: mockStorageService,
      callerRole: AppConstants.roleOperator,
      callerUid: operatorAUid,
    );
    expect(foreignUrl, isNull);
  });

  testWidgets(
    'Operator in Fault History sees all plant-wide fault metadata, but only sees photo button for own fault',
    (tester) async {
      await tester.pumpWidget(
        buildFaultHistoryScreen(
          role: AppConstants.roleOperator,
          uid: operatorAUid,
          name: 'Alice Operator',
        ),
      );
      await tester.pumpAndSettle();

      // Alice can read plant-wide fault metadata
      expect(find.text('CNC Milling Center'), findsOneWidget);
      expect(find.text('Motor vibration on spindle'), findsOneWidget);
      expect(find.text('Hydraulic Press'), findsOneWidget);
      expect(find.text('Hydraulic valve pressure drop'), findsOneWidget);

      // Alice reported Fault A: photo button is present and clickable
      expect(find.byKey(ValueKey('fault-image-btn-${operatorFaultA.id}')), findsOneWidget);

      // Bob reported Fault B: Alice CANNOT access Bob's private photo (button is NOT rendered)
      expect(find.byKey(ValueKey('fault-image-btn-${operatorFaultB.id}')), findsNothing);
    },
  );

  testWidgets(
    'Manager in Fault History can access photos for all plant-wide faults',
    (tester) async {
      await tester.pumpWidget(
        buildFaultHistoryScreen(
          role: AppConstants.roleManager,
          uid: managerUid,
          name: 'Boss Manager',
        ),
      );
      await tester.pumpAndSettle();

      // Both photo buttons are present for manager
      expect(find.byKey(ValueKey('fault-image-btn-${operatorFaultA.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('fault-image-btn-${operatorFaultB.id}')), findsOneWidget);
    },
  );

  testWidgets(
    'Technician in Fault History can access photos for all plant-wide faults',
    (tester) async {
      await tester.pumpWidget(
        buildFaultHistoryScreen(
          role: AppConstants.roleTechnician,
          uid: technicianUid,
          name: 'Dan Technician',
        ),
      );
      await tester.pumpAndSettle();

      // Both photo buttons are present for technician
      expect(find.byKey(ValueKey('fault-image-btn-${operatorFaultA.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('fault-image-btn-${operatorFaultB.id}')), findsOneWidget);
    },
  );
}
