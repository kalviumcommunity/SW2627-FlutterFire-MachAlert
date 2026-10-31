import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

class _FakeAuthUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  _FakeAuthUser({required this.uid, this.email, this.displayName});
}

class _MockFirebaseAuth extends Fake implements FirebaseAuth {
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();

  void emitUser(User? user) => _controller.add(user);

  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  Future<void> signOut() async {
    emitUser(null);
  }

  void close() => _controller.close();
}

Widget _buildTestApp({
  required AppStateProvider appState,
  required AuthService authService,
  required MachineProvider machineProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      Provider<AuthService>.value(value: authService),
      ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  group('Authentication & AppStateProvider Workflow Regression', () {
    late FakeFirebaseFirestore fakeFirestore;
    late UserService userService;
    late _MockFirebaseAuth fakeAuth;
    late AuthService authService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      userService = UserService(firestore: fakeFirestore);
      fakeAuth = _MockFirebaseAuth();
      authService = AuthService(firebaseAuth: fakeAuth);
    });

    tearDown(() {
      fakeAuth.close();
    });

    test('1. Unauthenticated startup state initialization', () {
      final provider = AppStateProvider();
      expect(provider.status, equals(AppStatus.initializing));
      expect(provider.route, equals(AppRoute.login));
      expect(provider.user, isNull);
      expect(provider.isInitializing, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.isUnauthenticated, isFalse);
      expect(provider.hasActiveSubscription, isFalse);
      expect(provider.hasProfileSubscription, isFalse);

      provider.setUnauthenticated();
      expect(provider.status, equals(AppStatus.unauthenticated));
      expect(provider.isUnauthenticated, isTrue);
      expect(provider.user, isNull);
    });

    test(
      '2. Authenticated startup with Firestore profile role resolution',
      () async {
        await fakeFirestore
            .collection(AppConstants.usersCollection)
            .doc('user_tech_01')
            .set({
              'uid': 'user_tech_01',
              'displayName': 'Alice Technician',
              'email': 'alice@machalert.com',
              'role': 'technician',
            });

        final provider = AppStateProvider(
          authStream: fakeAuth.authStateChanges(),
          userService: userService,
        );
        addTearDown(() => provider.dispose());

        expect(provider.status, equals(AppStatus.initializing));

        fakeAuth.emitUser(
          _FakeAuthUser(
            uid: 'user_tech_01',
            email: 'alice@machalert.com',
            displayName: 'Alice Technician',
          ),
        );

        await pumpEventQueue(times: 20);

        expect(provider.status, equals(AppStatus.authenticated));
        expect(provider.isAuthenticated, isTrue);
        expect(provider.route, equals(AppRoute.home));
        expect(provider.user?.id, equals('user_tech_01'));
        expect(provider.user?.role, equals('technician'));
        expect(provider.user?.name, equals('Alice Technician'));
        expect(provider.hasProfileSubscription, isTrue);
      },
    );

    test('3. Missing Firestore profile leaves role unresolved (empty string) and fails closed without elevating privileges', () async {
      final provider = AppStateProvider(
        authStream: fakeAuth.authStateChanges(),
        userService: userService,
      );
      addTearDown(() => provider.dispose());

      // User exists in Auth, but not seeded in users/{uid} in Firestore
      fakeAuth.emitUser(
        _FakeAuthUser(
          uid: 'unprovisioned_user',
          email: 'newuser@machalert.com',
          displayName: 'New Hire',
        ),
      );

      await pumpEventQueue(times: 20);

      expect(provider.status, equals(AppStatus.authenticated));
      expect(provider.user?.id, equals('unprovisioned_user'));
      expect(provider.user?.role, isEmpty);
      expect(provider.user?.role == AppConstants.roleManager, isFalse);
      expect(provider.user?.role == AppConstants.roleTechnician, isFalse);
      expect(provider.user?.role == AppConstants.roleOperator, isFalse);
    });

    test('4. Unrecognized profile role string preserves raw value and denies manager privilege', () async {
      await fakeFirestore
          .collection(AppConstants.usersCollection)
          .doc('custom_role_user')
          .set({
            'uid': 'custom_role_user',
            'displayName': 'Guest Auditor',
            'email': 'auditor@machalert.com',
            'role': 'auditor_external',
          });

      final provider = AppStateProvider(
        authStream: fakeAuth.authStateChanges(),
        userService: userService,
      );
      addTearDown(() => provider.dispose());

      fakeAuth.emitUser(
        _FakeAuthUser(
          uid: 'custom_role_user',
          email: 'auditor@machalert.com',
          displayName: 'Guest Auditor',
        ),
      );

      await pumpEventQueue(times: 20);

      expect(provider.status, equals(AppStatus.authenticated));
      expect(provider.user?.role, equals('auditor_external'));
      expect(provider.user?.role == AppConstants.roleManager, isFalse);
    });

    test('5. Logout clears active session, user model, and stops profile subscription', () async {
      await fakeFirestore
          .collection(AppConstants.usersCollection)
          .doc('user_op_01')
          .set({
            'uid': 'user_op_01',
            'displayName': 'Bob Operator',
            'email': 'bob@machalert.com',
            'role': 'operator',
          });

      final provider = AppStateProvider(
        authStream: fakeAuth.authStateChanges(),
        userService: userService,
      );
      addTearDown(() => provider.dispose());

      fakeAuth.emitUser(
        _FakeAuthUser(uid: 'user_op_01', email: 'bob@machalert.com'),
      );
      await pumpEventQueue(times: 20);

      expect(provider.isAuthenticated, isTrue);
      expect(provider.hasProfileSubscription, isTrue);

      // Sign out
      await authService.signOut();
      await pumpEventQueue(times: 20);

      expect(provider.status, equals(AppStatus.unauthenticated));
      expect(provider.isUnauthenticated, isTrue);
      expect(provider.user, isNull);
      expect(provider.route, equals(AppRoute.login));
      expect(provider.hasProfileSubscription, isFalse);
    });

    test('6. Stale profile events from a previous user do not overwrite current user session', () async {
      final userAProfileController = StreamController<UserModel?>.broadcast();
      final userBProfileController = StreamController<UserModel?>.broadcast();

      final customUserService = _MockStreamUserService({
        'user_a': userAProfileController.stream,
        'user_b': userBProfileController.stream,
      });

      final provider = AppStateProvider(
        authStream: fakeAuth.authStateChanges(),
        userService: customUserService,
      );
      addTearDown(() {
        provider.dispose();
        userAProfileController.close();
        userBProfileController.close();
      });

      // User A logs in
      fakeAuth.emitUser(_FakeAuthUser(uid: 'user_a', email: 'a@machalert.com'));
      await pumpEventQueue(times: 10);
      userAProfileController.add(
        UserModel(
          id: 'user_a',
          name: 'User A',
          email: 'a@machalert.com',
          role: 'operator',
        ),
      );
      await pumpEventQueue(times: 10);
      expect(provider.user?.id, equals('user_a'));
      expect(provider.user?.role, equals('operator'));

      // Switch to User B
      fakeAuth.emitUser(_FakeAuthUser(uid: 'user_b', email: 'b@machalert.com'));
      await pumpEventQueue(times: 10);
      userBProfileController.add(
        UserModel(
          id: 'user_b',
          name: 'User B',
          email: 'b@machalert.com',
          role: 'technician',
        ),
      );
      await pumpEventQueue(times: 10);
      expect(provider.user?.id, equals('user_b'));
      expect(provider.user?.role, equals('technician'));

      // Late event arrives from User A's stream
      userAProfileController.add(
        UserModel(
          id: 'user_a',
          name: 'User A Tampered',
          email: 'a@machalert.com',
          role: 'manager',
        ),
      );
      await pumpEventQueue(times: 20);

      // Verify User B's state was NOT overwritten by User A's late event
      expect(provider.user?.id, equals('user_b'));
      expect(provider.user?.role, equals('technician'));
      expect(provider.user?.name, equals('User B'));
    });

    test(
      '7. Stream error handling safely transitions provider to unauthenticated',
      () async {
        final provider = AppStateProvider(
          authStream: fakeAuth.authStateChanges(),
          userService: userService,
        );
        addTearDown(() => provider.dispose());

        fakeAuth.emitError(Exception('Auth network stream crashed'));
        await pumpEventQueue(times: 20);

        expect(provider.status, equals(AppStatus.unauthenticated));
        expect(provider.user, isNull);
      },
    );

    test(
      '8. Navigation state manipulation maintains route and user consistency',
      () {
        final provider = AppStateProvider();
        final testUser = UserModel(
          id: 'test_nav_user',
          name: 'Nav User',
          email: 'nav@machalert.com',
          role: 'operator',
        );

        provider.setAuthenticated(testUser, route: AppRoute.home);
        expect(provider.status, equals(AppStatus.authenticated));
        expect(provider.route, equals(AppRoute.home));

        provider.navigateTo(AppRoute.signup);
        expect(provider.route, equals(AppRoute.signup));
        expect(provider.status, equals(AppStatus.authenticated));
        expect(provider.user?.id, equals('test_nav_user'));

        provider.setUnauthenticated(route: AppRoute.login);
        expect(provider.status, equals(AppStatus.unauthenticated));
        expect(provider.route, equals(AppRoute.login));
        expect(provider.user, isNull);
      },
    );

    test('9. Disposal safety prevents post-disposal exceptions', () async {
      final provider = AppStateProvider(
        authStream: fakeAuth.authStateChanges(),
        userService: userService,
      );

      provider.dispose();
      expect(provider.isDisposed, isTrue);

      // Emitting events after dispose must not throw
      expect(
        () => fakeAuth.emitUser(_FakeAuthUser(uid: 'late_user')),
        returnsNormally,
      );
      expect(
        () => fakeAuth.emitError(Exception('late_error')),
        returnsNormally,
      );
      await pumpEventQueue(times: 10);
    });
  });

  group('Role Dashboard UI & Privilege Separation Regression', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MachineService machineService;
    late MachineProvider machineProvider;
    late _MockFirebaseAuth fakeAuth;
    late AuthService authService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(machineService: machineService);
      fakeAuth = _MockFirebaseAuth();
      authService = AuthService(firebaseAuth: fakeAuth);

      // Seed mock machines
      await fakeFirestore
          .collection(AppConstants.machinesCollection)
          .doc('MCH-101')
          .set({
            'id': 'MCH-101',
            'name': 'Extruder Unit 01',
            'productionLine': 'Line 1',
            'status': 'Operational',
            'healthScore': 95,
          });
    });

    tearDown(() {
      fakeAuth.close();
    });

    testWidgets(
      '10. Unresolved role fallback UI renders safe dashboard without elevated controls',
      (tester) async {
        final appState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'user_guest',
              name: 'Guest User',
              email: 'guest@machalert.com',
              role: '', // Unresolved role
            ),
          );

        await tester.pumpWidget(
          _buildTestApp(
            appState: appState,
            authService: authService,
            machineProvider: machineProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, Guest User'), findsOneWidget);
        expect(find.text('Dashboard'), findsOneWidget);
        expect(find.text('Your role is being prepared.'), findsOneWidget);

        // Privileged features are NOT visible
        expect(find.text('Factory Overview'), findsNothing);
        expect(find.text('Maintenance Overview'), findsNothing);
        expect(find.text('Machine Operations'), findsNothing);
        expect(find.text('Report Fault'), findsNothing);
        expect(find.text('Assigned Maintenance'), findsNothing);
        expect(find.text('Maintenance'), findsNothing);
      },
    );

    testWidgets(
      '11. Operator role displays Machine Operations and hides manager/tech features',
      (tester) async {
        final appState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'op_001',
              name: 'Sam Operator',
              email: 'sam@machalert.com',
              role: 'operator',
            ),
          );

        await tester.pumpWidget(
          _buildTestApp(
            appState: appState,
            authService: authService,
            machineProvider: machineProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, Sam Operator'), findsOneWidget);
        expect(find.text('Operator Dashboard'), findsOneWidget);
        expect(find.text('Machine Operations'), findsOneWidget);

        // Operator actions
        expect(find.text('Machines'), findsOneWidget);
        expect(find.text('Report Fault'), findsOneWidget);
        expect(find.text('Fault History'), findsOneWidget);
        expect(find.text('My Reports'), findsOneWidget);

        // Forbidden actions
        expect(find.text('Factory Overview'), findsNothing);
        expect(find.text('Maintenance Overview'), findsNothing);
        expect(find.text('Assigned Maintenance'), findsNothing);
        expect(find.text('Maintenance'), findsNothing);
      },
    );

    testWidgets(
      '12. Technician role displays Maintenance Overview and assigned maintenance',
      (tester) async {
        final appState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'tech_001',
              name: 'Elena Technician',
              email: 'elena@machalert.com',
              role: 'technician',
            ),
          );

        await tester.pumpWidget(
          _buildTestApp(
            appState: appState,
            authService: authService,
            machineProvider: machineProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, Elena Technician'), findsOneWidget);
        expect(find.text('Technician Dashboard'), findsOneWidget);
        expect(find.text('Maintenance Overview'), findsOneWidget);

        // Technician actions & stats
        expect(find.text('Assigned Maintenance'), findsOneWidget);
        expect(find.text('Active Faults'), findsWidgets);
        expect(find.text('Fault History'), findsOneWidget);
        expect(find.text('Machines'), findsOneWidget);

        // Forbidden actions
        expect(find.text('Factory Overview'), findsNothing);
        expect(find.text('Report Fault'), findsNothing);
        expect(find.text('My Reports'), findsNothing);
      },
    );

    testWidgets(
      '13. Manager role displays Factory Overview and full management actions',
      (tester) async {
        final appState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'mgr_001',
              name: 'David Manager',
              email: 'david@machalert.com',
              role: 'manager',
            ),
          );

        await tester.pumpWidget(
          _buildTestApp(
            appState: appState,
            authService: authService,
            machineProvider: machineProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, David Manager'), findsOneWidget);
        expect(find.text('Manager Dashboard'), findsOneWidget);
        expect(find.text('Factory Overview'), findsOneWidget);

        // Manager actions
        expect(find.text('Machines'), findsWidgets);
        expect(find.text('Fault History'), findsOneWidget);
        expect(find.text('Faults'), findsOneWidget);
        expect(find.text('Maintenance'), findsOneWidget);

        // Operator/tech-only titles
        expect(find.text('Machine Operations'), findsNothing);
        expect(find.text('Assigned Maintenance'), findsNothing);
        expect(find.text('My Reports'), findsNothing);
      },
    );

    testWidgets(
      '14. MachineListScreen shows Add Machine FAB exclusively for managers',
      (tester) async {
        // 1. Operator navigation
        final operatorState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'op_002',
              name: 'Op User',
              email: 'op@machalert.com',
              role: 'operator',
            ),
          );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(
                value: operatorState,
              ),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: MaterialApp(
              home: MachineListScreen(
                machines: [
                  MachineModel(
                    id: 'MCH-101',
                    name: 'Machine 1',
                    productionLine: 'Line 1',
                    status: 'Operational',
                    healthScore: 90,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Add Machine'), findsNothing);

        // 2. Manager navigation
        final managerState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'mgr_002',
              name: 'Mgr User',
              email: 'mgr@machalert.com',
              role: 'manager',
            ),
          );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(
                value: managerState,
              ),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: MaterialApp(
              home: MachineListScreen(
                machines: [
                  MachineModel(
                    id: 'MCH-101',
                    name: 'Machine 1',
                    productionLine: 'Line 1',
                    status: 'Operational',
                    healthScore: 90,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Add Machine'), findsOneWidget);
      },
    );
  });
}

class _MockStreamUserService extends Fake implements UserService {
  final Map<String, Stream<UserModel?>> _streams;

  _MockStreamUserService(this._streams);

  @override
  Stream<UserModel?> streamUserProfile(String uid) {
    return _streams[uid] ?? const Stream.empty();
  }
}
