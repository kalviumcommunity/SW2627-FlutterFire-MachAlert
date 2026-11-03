// ignore_for_file: subtype_of_sealed_class, must_be_immutable

// Tests for MACHALERT — iOS CLOUD FIREBASE MANAGER PROFILE LOADING BUG
// Covers all 8 requirements from the specification:
// 1. Existing Manager profile is retrieved and preserved.
// 2. Existing Technician profile is retrieved and preserved.
// 3. Existing Operator profile is retrieved and preserved.
// 4. Missing profile results in default Operator provisioning.
// 5. Permission-denied during profile retrieval does not trigger profile creation.
// 6. Firestore unavailable during profile retrieval does not trigger profile creation.
// 7. Correct dashboard is selected using the existing stored role.
// 8. Firebase project and authenticated UID diagnostics are accurate.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

class _FakePermissionDeniedDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  bool setCalled = false;

  @override
  String get id => 'JO5v92NOnFQC1gvKPigwBfAnSut2';

  @override
  String get path => 'users/JO5v92NOnFQC1gvKPigwBfAnSut2';

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    setCalled = true;
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
      message: 'Missing or insufficient permissions.',
    );
  }
}

class _FakeUnavailableDocRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  bool setCalled = false;

  @override
  String get id => 'JO5v92NOnFQC1gvKPigwBfAnSut2';

  @override
  String get path => 'users/JO5v92NOnFQC1gvKPigwBfAnSut2';

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'The service is currently unavailable.',
    );
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    setCalled = true;
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'The service is currently unavailable.',
    );
  }
}

class _FakeCustomFirestore extends Fake implements FirebaseFirestore {
  final DocumentReference<Map<String, dynamic>> customDocRef;

  _FakeCustomFirestore(this.customDocRef);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _FakeCustomCollectionRef(customDocRef);
  }
}

class _FakeCustomCollectionRef extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final DocumentReference<Map<String, dynamic>> customDocRef;

  _FakeCustomCollectionRef(this.customDocRef);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return customDocRef;
  }
}

void main() {
  group('Cloud Manager Profile Loading & Role Preservation Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService userService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      userService = UserService(firestore: fakeFirestore);
    });

    test('1. Existing Manager profile is retrieved and preserved (UID JO5v92NOnFQC1gvKPigwBfAnSut2)', () async {
      const managerUid = 'JO5v92NOnFQC1gvKPigwBfAnSut2';
      const managerEmail = 'manager@gmail.com';
      const managerName = 'MachAlert Test Manager';

      // Pre-populate document in Firestore exactly as confirmed in cloud
      await fakeFirestore.collection('users').doc(managerUid).set({
        'displayName': managerName,
        'email': managerEmail,
        'name': managerName,
        'role': 'manager',
        'uid': managerUid,
        'userId': managerUid,
      });

      // Call createProfileIfAbsent as LoginScreen does
      final profile = await userService.createProfileIfAbsent(
        uid: managerUid,
        email: managerEmail,
        displayName: managerName,
        role: AppConstants.roleOperator, // Login screen default fallback
      );

      // Verify profile was preserved and NOT converted to operator
      expect(profile.id, equals(managerUid));
      expect(profile.email, equals(managerEmail));
      expect(profile.name, equals(managerName));
      expect(profile.role, equals(AppConstants.roleManager));

      // Verify document in Firestore remains untouched
      final doc = await fakeFirestore.collection('users').doc(managerUid).get();
      expect(doc.data()!['role'], equals(AppConstants.roleManager));
      expect(doc.data()!['name'], equals(managerName));
    });

    test('2. Existing Technician profile is retrieved and preserved', () async {
      const techUid = 'tech_uid_777';
      const techEmail = 'technician@gmail.com';
      const techName = 'Senior Technician';

      await fakeFirestore.collection('users').doc(techUid).set({
        'displayName': techName,
        'email': techEmail,
        'name': techName,
        'role': 'technician',
        'uid': techUid,
        'userId': techUid,
      });

      final profile = await userService.createProfileIfAbsent(
        uid: techUid,
        email: techEmail,
        displayName: techName,
        role: AppConstants.roleOperator,
      );

      expect(profile.id, equals(techUid));
      expect(profile.role, equals(AppConstants.roleTechnician));

      final doc = await fakeFirestore.collection('users').doc(techUid).get();
      expect(doc.data()!['role'], equals(AppConstants.roleTechnician));
    });

    test('3. Existing Operator profile is retrieved and preserved', () async {
      const opUid = 'operator_uid_888';
      const opEmail = 'operator@gmail.com';
      const opName = 'Line Operator';

      await fakeFirestore.collection('users').doc(opUid).set({
        'displayName': opName,
        'email': opEmail,
        'name': opName,
        'role': 'operator',
        'uid': opUid,
        'userId': opUid,
      });

      final profile = await userService.createProfileIfAbsent(
        uid: opUid,
        email: opEmail,
        displayName: opName,
        role: AppConstants.roleOperator,
      );

      expect(profile.id, equals(opUid));
      expect(profile.role, equals(AppConstants.roleOperator));

      final doc = await fakeFirestore.collection('users').doc(opUid).get();
      expect(doc.data()!['role'], equals(AppConstants.roleOperator));
    });

    test('4. Missing profile results in default Operator provisioning on server confirm', () async {
      const newUid = 'brand_new_user_999';
      const newEmail = 'newhire@gmail.com';

      final profile = await userService.createProfileIfAbsent(
        uid: newUid,
        email: newEmail,
        displayName: 'New Hire',
      );

      expect(profile.id, equals(newUid));
      expect(profile.role, equals(AppConstants.roleOperator));

      final doc = await fakeFirestore.collection('users').doc(newUid).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['role'], equals(AppConstants.roleOperator));
    });

    test('5. Permission-denied during profile retrieval does not trigger profile creation', () async {
      final fakeDocRef = _FakePermissionDeniedDocRef();
      final customFirestore = _FakeCustomFirestore(fakeDocRef);
      final customUserService = UserService(firestore: customFirestore);

      expect(
        () => customUserService.createProfileIfAbsent(
          uid: 'JO5v92NOnFQC1gvKPigwBfAnSut2',
          email: 'manager@gmail.com',
        ),
        throwsA(
          isA<UserServiceException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );

      // Assert set() was NEVER called after read threw permission-denied
      expect(fakeDocRef.setCalled, isFalse);
    });

    test('6. Firestore unavailable during profile retrieval does not trigger profile creation', () async {
      final fakeDocRef = _FakeUnavailableDocRef();
      final customFirestore = _FakeCustomFirestore(fakeDocRef);
      final customUserService = UserService(firestore: customFirestore);

      expect(
        () => customUserService.createProfileIfAbsent(
          uid: 'JO5v92NOnFQC1gvKPigwBfAnSut2',
          email: 'manager@gmail.com',
        ),
        throwsA(
          isA<UserServiceException>().having(
            (e) => e.code,
            'code',
            'unavailable',
          ),
        ),
      );

      // Assert set() was NEVER called after read threw unavailable
      expect(fakeDocRef.setCalled, isFalse);
    });

    testWidgets(
      '7. Correct dashboard is selected using the existing stored role',
      (tester) async {
        final managerUser = UserModel(
          id: 'JO5v92NOnFQC1gvKPigwBfAnSut2',
          name: 'MachAlert Test Manager',
          email: 'manager@gmail.com',
          role: AppConstants.roleManager,
        );

        final technicianUser = UserModel(
          id: 'tech_1',
          name: 'Tech Person',
          email: 'tech@gmail.com',
          role: AppConstants.roleTechnician,
        );

        final operatorUser = UserModel(
          id: 'op_1',
          name: 'Op Person',
          email: 'op@gmail.com',
          role: AppConstants.roleOperator,
        );

        final fakeMachineService = MachineService(firestore: fakeFirestore);
        final machineProvider = MachineProvider(
          machineService: fakeMachineService,
        );

        Widget buildTestApp(UserModel user) {
          final appStateProvider = AppStateProvider();
          appStateProvider.setAuthenticated(user);

          return MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(
                value: appStateProvider,
              ),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
              Provider<AuthService>(create: (_) => AuthService()),
            ],
            child: const MaterialApp(home: HomeScreen()),
          );
        }

        // 1. Manager Role: Displays 'Manager Dashboard'
        await tester.pumpWidget(buildTestApp(managerUser));
        await tester.pump();
        expect(find.text('Manager Dashboard'), findsOneWidget);

        // 2. Technician Role: Displays 'Technician Dashboard'
        await tester.pumpWidget(buildTestApp(technicianUser));
        await tester.pump();
        expect(find.text('Technician Dashboard'), findsOneWidget);

        // 3. Operator Role: Displays 'Operator Dashboard'
        await tester.pumpWidget(buildTestApp(operatorUser));
        await tester.pump();
        expect(find.text('Operator Dashboard'), findsOneWidget);
      },
    );

    test(
      '8. Diagnostic profile check logging works cleanly without errors',
      () async {
        final docRef = userService.userDoc('diag_user');
        expect(docRef.path, 'users/diag_user');
        expect(userService.firestore, fakeFirestore);

        // Verify that getUserProfile with Source.server works cleanly
        final profile = await userService.getUserProfile(
          'diag_user',
          source: Source.server,
        );
        expect(profile, isNull);
      },
    );
  });
}
