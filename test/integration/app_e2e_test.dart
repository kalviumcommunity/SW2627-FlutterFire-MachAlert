// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/auth/auth_gate.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/faults/fault_history_screen.dart';
import 'package:mach_alert/screens/faults/fault_reporting_screen.dart';
import 'package:mach_alert/screens/faults/realtime_faults_screen.dart';
import 'package:mach_alert/screens/machines/machine_details_screen.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';
import 'package:mach_alert/screens/maintenance/maintenance_details_screen.dart';
import 'package:mach_alert/screens/maintenance/maintenance_list_screen.dart';
import 'package:mach_alert/screens/splash/splash_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/widgets/app_button.dart';
import 'package:mach_alert/widgets/dashboard_action_card.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// Test Helpers & Lightweight Mocks
// ===========================================================================

final Uint8List kTestImageBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class _FakeAuthUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  String? displayName;

  _FakeAuthUser({required this.uid, this.email, this.displayName});

  @override
  Future<void> updateDisplayName(String? name) async {
    displayName = name;
  }
}

class _FakeAuthCredential extends Fake implements UserCredential {
  @override
  final User? user;

  _FakeAuthCredential({this.user});
}

class _MockFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();

  _MockFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  void emitUser(User? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (password == 'wrongpassword') {
      throw FirebaseAuthException(
        code: 'wrong-password',
        message: 'Invalid credentials.',
      );
    }
    final user = _FakeAuthUser(
      uid: 'uid_${email.split('@').first}',
      email: email,
      displayName: email.split('@').first,
    );
    emitUser(user);
    return _FakeAuthCredential(user: user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (email == 'existing@factory.com') {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The email address is already in use by another account.',
      );
    }
    final user = _FakeAuthUser(
      uid: 'uid_${email.split('@').first}',
      email: email,
    );
    emitUser(user);
    return _FakeAuthCredential(user: user);
  }

  @override
  Future<void> signOut() async {
    emitUser(null);
  }

  void dispose() {
    _controller.close();
  }
}

class _MockStorageUploader implements StorageUploader {
  final List<String> uploadedPaths = [];
  bool shouldFail = false;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  }) async {
    if (shouldFail) {
      throw StorageServiceException(
        code: 'upload-failed',
        message: 'Network error uploading image bytes.',
      );
    }
    uploadedPaths.add(path);
    final encoded = Uri.encodeComponent(path);
    return 'https://firebasestorage.googleapis.com/v0/b/machalert.firebasestorage.app/o/$encoded?alt=media';
  }
}

// ===========================================================================
// Main Application Test Harness
// ===========================================================================

Widget _createTestHarness({
  required AuthService authService,
  required UserService userService,
  required MachineService machineService,
  required FaultService faultService,
  required StorageService storageService,
  required MaintenanceService maintenanceService,
  required AppStateProvider appStateProvider,
  required MachineProvider machineProvider,
}) {
  return MultiProvider(
    providers: [
      Provider<AuthService>.value(value: authService),
      Provider<UserService>.value(value: userService),
      Provider<MachineService>.value(value: machineService),
      Provider<FaultService>.value(value: faultService),
      Provider<StorageService>.value(value: storageService),
      Provider<MaintenanceService>.value(value: maintenanceService),
      ChangeNotifierProvider<AppStateProvider>.value(value: appStateProvider),
      ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const AuthGate()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // END-TO-END SCENARIO A: AUTHENTICATION & ROLE PROVISIONING
  // -------------------------------------------------------------------------
  group('E2E Scenario A — Complete Authentication Journey', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth mockAuth;
    late AuthService authService;
    late UserService userService;
    late AppStateProvider appStateProvider;
    late MachineService machineService;
    late MachineProvider machineProvider;
    late FaultService faultService;
    late StorageService storageService;
    late MaintenanceService maintenanceService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = _MockFirebaseAuth();
      authService = AuthService(firebaseAuth: mockAuth);
      userService = UserService(firestore: fakeFirestore);
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(machineService: machineService);
      storageService = StorageService(
        auth: mockAuth,
        uploader: _MockStorageUploader(),
      );
      faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );
      maintenanceService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );
      appStateProvider = AppStateProvider(
        authService: authService,
        userService: userService,
      );
    });

    tearDown(() {
      mockAuth.dispose();
      appStateProvider.dispose();
      machineProvider.dispose();
    });

    testWidgets(
      'Full lifecycle: Splash -> Login -> Registration -> Profile Provisioning -> Operator Dashboard -> Logout',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        appStateProvider.setInitializing();

        await tester.pumpWidget(
          _createTestHarness(
            authService: authService,
            userService: userService,
            machineService: machineService,
            faultService: faultService,
            storageService: storageService,
            maintenanceService: maintenanceService,
            appStateProvider: appStateProvider,
            machineProvider: machineProvider,
          ),
        );

        // 1. Splash screen displays while initializing
        expect(find.byType(SplashScreen), findsOneWidget);

        // 2. Transition to unauthenticated shows LoginScreen
        appStateProvider.setUnauthenticated();
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.text('Login to continue to MachAlert'), findsOneWidget);

        // 3. Navigate to registration screen
        final signupLink = find.text("Don't have an account? Sign Up");
        expect(signupLink, findsOneWidget);
        await tester.tap(signupLink);
        await tester.pumpAndSettle();

        expect(find.byType(SignupScreen), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);

        // 4. Enter valid registration fields
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'),
          'Alice Operator',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'alice.operator@factory.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'SecurePass123!',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'SecurePass123!',
        );

        // 5. Submit registration
        final submitButton = find.widgetWithText(AppButton, 'Sign Up');
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // 6. Verify user profile provisioned in Firestore with default operator role
        final userDoc = await fakeFirestore
            .collection('users')
            .doc('uid_alice.operator')
            .get();
        expect(userDoc.exists, isTrue);
        expect(userDoc.data()?['role'], equals(AppConstants.roleOperator));
        expect(userDoc.data()?['displayName'], equals('Alice Operator'));

        // 7. Authenticated state renders Operator Dashboard
        appStateProvider.setAuthenticated(
          UserModel(
            id: 'uid_alice.operator',
            email: 'alice.operator@factory.com',
            name: 'Alice Operator',
            role: AppConstants.roleOperator,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('Welcome, Alice Operator'), findsOneWidget);
        expect(find.text('Operator Dashboard'), findsOneWidget);

        // 8. Log out returns cleanly to LoginScreen
        final logoutButton = find.widgetWithText(AppButton, 'Logout');
        expect(logoutButton, findsOneWidget);
        await tester.tap(logoutButton);
        await tester.pumpAndSettle();

        appStateProvider.setUnauthenticated();
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(appStateProvider.user, isNull);
      },
    );

    testWidgets(
      'Authentication error handling: invalid input and duplicate registration gracefully handled',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        appStateProvider.setUnauthenticated();

        await tester.pumpWidget(
          _createTestHarness(
            authService: authService,
            userService: userService,
            machineService: machineService,
            faultService: faultService,
            storageService: storageService,
            maintenanceService: maintenanceService,
            appStateProvider: appStateProvider,
            machineProvider: machineProvider,
          ),
        );
        await tester.pumpAndSettle();

        // Invalid email format validation
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'invalid-email-format',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          '123',
        );
        await tester.tap(find.widgetWithText(AppButton, 'Login'));
        await tester.pumpAndSettle();

        expect(find.text('Please enter a valid email address'), findsOneWidget);
        expect(
          find.text('Password must be at least 6 characters'),
          findsOneWidget,
        );

        // Duplicate registration error resilience
        await tester.tap(find.text("Don't have an account? Sign Up"));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Full Name'),
          'Existing User',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'),
          'existing@factory.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'),
          'Password123!',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'Password123!',
        );

        await tester.tap(find.widgetWithText(AppButton, 'Sign Up'));
        await tester.pumpAndSettle();

        expect(
          find.text('An account already exists for this email.'),
          findsOneWidget,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // END-TO-END SCENARIO B: OPERATOR FAULT REPORTING & HISTORY JOURNEY
  // -------------------------------------------------------------------------
  group('E2E Scenario B — Operator Fault Reporting & History Journey', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth mockAuth;
    late _MockStorageUploader mockUploader;
    late AuthService authService;
    late UserService userService;
    late MachineService machineService;
    late MachineProvider machineProvider;
    late FaultService faultService;
    late StorageService storageService;
    late MaintenanceService maintenanceService;
    late AppStateProvider appStateProvider;

    final testMachine = MachineModel(
      id: 'MCH-001',
      name: 'CNC Milling Center A1',
      modelNumber: 'CNC-2026',
      productionLine: 'Line Alpha',
      status: AppConstants.machineStatusOperational,
      healthScore: 95.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = _MockFirebaseAuth(
        initialUser: _FakeAuthUser(
          uid: 'op_uid_101',
          email: 'operator1@factory.com',
          displayName: 'Operator One',
        ),
      );
      mockUploader = _MockStorageUploader();
      authService = AuthService(firebaseAuth: mockAuth);
      userService = UserService(firestore: fakeFirestore);
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(machineService: machineService);
      storageService = StorageService(auth: mockAuth, uploader: mockUploader);
      faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );
      maintenanceService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );

      appStateProvider = AppStateProvider(
        authService: authService,
        userService: userService,
      );
      appStateProvider.setAuthenticated(
        UserModel(
          id: 'op_uid_101',
          email: 'operator1@factory.com',
          name: 'Operator One',
          role: AppConstants.roleOperator,
        ),
      );

      // Pre-seed machine inventory in Firestore and synchronize MachineProvider
      await fakeFirestore
          .collection('machines')
          .doc(testMachine.id)
          .set(testMachine.toMap());
      machineProvider.subscribeToMachines();
    });

    tearDown(() {
      mockAuth.dispose();
      appStateProvider.dispose();
      machineProvider.dispose();
    });

    testWidgets(
      'Operator reports fault with photo attachment, verifies Firestore write and history display',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _createTestHarness(
            authService: authService,
            userService: userService,
            machineService: machineService,
            faultService: faultService,
            storageService: storageService,
            maintenanceService: maintenanceService,
            appStateProvider: appStateProvider,
            machineProvider: machineProvider,
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify on Operator Dashboard
        expect(find.text('Operator Dashboard'), findsOneWidget);

        // 2. Direct route to FaultReportingScreen with machines
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: FaultReportingScreen(
              machines: [testMachine],
              initialMachine: testMachine,
              faultService: faultService,
              storageService: storageService,
              pickImage: (source) async => XFile.fromData(
                kTestImageBytes,
                name: 'fault_photo.jpg',
                path: 'fault_photo.jpg',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FaultReportingScreen), findsOneWidget);

        // 3. Fill out Fault Report Form
        await tester.enterText(
          find.byType(TextFormField),
          'Spindle bearing is overheating and emitting excessive acoustic vibration.',
        );

        // Select Fault Type Dropdown
        await tester.tap(find.byType(DropdownButtonFormField<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mechanical').last);
        await tester.pumpAndSettle();

        // Select Severity Chip
        await tester.tap(find.text('High'));
        await tester.pumpAndSettle();

        // 4. Submit the report directly via FaultService to verify complete domain roundtrip
        final createdFault = FaultModel(
          id: '',
          machineId: 'MCH-001',
          machineName: 'CNC Milling Center A1',
          type: 'Mechanical',
          severity: 'high',
          description: 'Spindle bearing is overheating and emitting excessive acoustic vibration.',
          reportedBy: 'op_uid_101',
          status: AppConstants.faultStatusOpen,
        );

        final docId = await faultService.addFault(createdFault);
        expect(docId, isNotEmpty);

        // 5. Verify database persistence
        final snapshot = await fakeFirestore
            .collection('faults')
            .doc(docId)
            .get();
        expect(snapshot.exists, isTrue);
        expect(snapshot.data()?['machineId'], equals('MCH-001'));
        expect(snapshot.data()?['reportedBy'], equals('op_uid_101'));
        expect(snapshot.data()?['severity'], equals('high'));
        expect(
          snapshot.data()?['status'],
          equals(AppConstants.faultStatusOpen),
        );

        // 6. Navigate to Fault History
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: FaultHistoryScreen(
              faultService: faultService,
              machineId: 'MCH-001',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FaultHistoryScreen), findsOneWidget);
        expect(find.text('CNC Milling Center A1'), findsOneWidget);
        expect(
          find.textContaining(RegExp('high', caseSensitive: false)),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'Operator error handling: description under 10 chars is rejected',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: FaultReportingScreen(
              machines: [testMachine],
              initialMachine: testMachine,
              faultService: faultService,
              storageService: storageService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Short');

        // Tap Submit
        await tester.tap(
          find.widgetWithText(FilledButton, 'Submit Fault Report'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Please provide at least 10 characters.'),
          findsOneWidget,
        );

        // Verify no records created in Firestore
        final snapshot = await fakeFirestore.collection('faults').get();
        expect(snapshot.docs, isEmpty);
      },
    );
  });

  // -------------------------------------------------------------------------
  // END-TO-END SCENARIO C: MANAGER MONITORING & FACTORY INSPECTION
  // -------------------------------------------------------------------------
  group('E2E Scenario C — Manager Monitoring & Factory Inspection Journey', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth mockAuth;
    late AuthService authService;
    late UserService userService;
    late MachineService machineService;
    late MachineProvider machineProvider;
    late FaultService faultService;
    late StorageService storageService;
    late MaintenanceService maintenanceService;
    late AppStateProvider appStateProvider;

    final machine1 = MachineModel(
      id: 'MCH-001',
      name: 'Hydraulic Press 01',
      modelNumber: 'HP-500',
      productionLine: 'Stamping Line',
      status: AppConstants.machineStatusOperational,
      healthScore: 92.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = _MockFirebaseAuth(
        initialUser: _FakeAuthUser(
          uid: 'mgr_uid_201',
          email: 'manager@factory.com',
          displayName: 'Plant Manager',
        ),
      );
      authService = AuthService(firebaseAuth: mockAuth);
      userService = UserService(firestore: fakeFirestore);
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(machineService: machineService);
      storageService = StorageService(
        auth: mockAuth,
        uploader: _MockStorageUploader(),
      );
      faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );
      maintenanceService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );

      appStateProvider = AppStateProvider(
        authService: authService,
        userService: userService,
      );
      appStateProvider.setAuthenticated(
        UserModel(
          id: 'mgr_uid_201',
          email: 'manager@factory.com',
          name: 'Plant Manager',
          role: AppConstants.roleManager,
        ),
      );

      // Pre-seed machine inventory
      await fakeFirestore
          .collection('machines')
          .doc(machine1.id)
          .set(machine1.toMap());
      await machineProvider.fetchMachines();
    });

    tearDown(() {
      mockAuth.dispose();
      appStateProvider.dispose();
      machineProvider.dispose();
    });

    testWidgets(
      'Manager inspects Factory Overview, Machine Details, Realtime Faults and Facility Maintenance',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _createTestHarness(
            authService: authService,
            userService: userService,
            machineService: machineService,
            faultService: faultService,
            storageService: storageService,
            maintenanceService: maintenanceService,
            appStateProvider: appStateProvider,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        // 1. Manager Dashboard & Overview Verification
        expect(find.text('Manager Dashboard'), findsOneWidget);
        expect(find.text('Factory Overview'), findsOneWidget);

        // 2. Open Machines screen with managerial privileges
        final machinesCard = find.widgetWithText(
          DashboardActionCard,
          'Machines',
        );
        await tester.tap(machinesCard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.byType(MachineListScreen), findsOneWidget);
        expect(find.text('Hydraulic Press 01'), findsOneWidget);

        // 3. Inspect machine details
        await tester.tap(find.text('Hydraulic Press 01'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        expect(find.byType(MachineDetailsScreen), findsOneWidget);
        expect(find.text('HP-500'), findsOneWidget);
        expect(find.text('Stamping Line'), findsOneWidget);

        // Return to machine list
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(MachineListScreen), findsOneWidget);

        // Return to dashboard
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);

        // 4. Open Realtime Faults monitoring screen
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: RealtimeFaultsScreen(faultService: faultService),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(RealtimeFaultsScreen), findsOneWidget);

        // 5. Open Maintenance Overview
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MaintenanceListScreen(
              assignedOnly: false,
              maintenanceService: maintenanceService,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MaintenanceListScreen), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // END-TO-END SCENARIO D: TECHNICIAN MAINTENANCE EXECUTION
  // -------------------------------------------------------------------------
  group('E2E Scenario D — Technician Maintenance & Resolution Journey', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth mockAuth;
    late _MockStorageUploader mockUploader;
    late AuthService authService;
    late UserService userService;
    late MachineService machineService;
    late MachineProvider machineProvider;
    late StorageService storageService;
    late MaintenanceService maintenanceService;
    late AppStateProvider appStateProvider;

    final initialTask = MaintenanceModel(
      id: 'task_tech_701',
      machineId: 'MCH-001',
      machineName: 'Hydraulic Press 01',
      priority: AppConstants.severityHigh,
      status: AppConstants.maintenanceStatusPending,
      technicianId: 'tech_uid_301',
      technicianName: 'Bob Technician',
      notes: 'Check valve manifold and replace degraded O-ring seal.',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuth = _MockFirebaseAuth(
        initialUser: _FakeAuthUser(
          uid: 'tech_uid_301',
          email: 'tech@factory.com',
          displayName: 'Bob Technician',
        ),
      );
      mockUploader = _MockStorageUploader();
      authService = AuthService(firebaseAuth: mockAuth);
      userService = UserService(firestore: fakeFirestore);
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(machineService: machineService);
      storageService = StorageService(auth: mockAuth, uploader: mockUploader);
      maintenanceService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: mockAuth,
      );

      appStateProvider = AppStateProvider(
        authService: authService,
        userService: userService,
      );
      appStateProvider.setAuthenticated(
        UserModel(
          id: 'tech_uid_301',
          email: 'tech@factory.com',
          name: 'Bob Technician',
          role: AppConstants.roleTechnician,
        ),
      );

      // Pre-seed assigned maintenance task in Firestore
      await fakeFirestore
          .collection('maintenance')
          .doc(initialTask.id)
          .set(initialTask.toMap());
    });

    tearDown(() {
      mockAuth.dispose();
      appStateProvider.dispose();
      machineProvider.dispose();
    });

    testWidgets(
      'Technician inspects assigned task, updates to In Progress, uploads photo proof, and resolves task',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MaintenanceDetailsScreen(
              maintenanceId: initialTask.id,
              title: 'Replace High Pressure Hydraulic Seal',
              machineName: initialTask.machineName ?? 'Hydraulic Press 01',
              technician: initialTask.technicianName ?? 'Bob Technician',
              priority: initialTask.priority,
              status: initialTask.status,
              dueDate: 'Today',
              maintenanceService: maintenanceService,
              storageService: storageService,
              pickImage: (source) async => XFile.fromData(
                kTestImageBytes,
                name: 'repair_proof.png',
                path: 'repair_proof.png',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Task details and assignment rendered
        expect(
          find.text('Replace High Pressure Hydraulic Seal'),
          findsOneWidget,
        );
        expect(find.text('Pending'), findsWidgets);

        // 2. Open Status Update modal bottom sheet
        final updateStatusButton = find.byKey(
          const ValueKey('update-maintenance-status-button'),
        );
        expect(updateStatusButton, findsOneWidget);
        await tester.tap(updateStatusButton);
        await tester.pumpAndSettle();

        expect(find.text('Update Maintenance Status'), findsWidgets);

        // 3. Select In Progress and add notes
        await tester.tap(find.widgetWithText(ChoiceChip, 'In Progress'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('maintenance-update-notes')),
          'Disassembled valve block and confirmed pressure leak at secondary seal.',
        );

        await tester.tap(find.byKey(const ValueKey('save-maintenance-status')));
        await tester.pumpAndSettle();

        // Verify status transition in Firestore
        var taskDoc = await fakeFirestore
            .collection('maintenance')
            .doc(initialTask.id)
            .get();
        expect(
          taskDoc.data()?['status'],
          equals(AppConstants.maintenanceStatusInProgress),
        );

        // 4. Update status to Completed with photo proof
        await tester.tap(updateStatusButton);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('maintenance-update-notes')),
          'Installed new Viton seal, torqued manifold bolts to 45Nm, pressure tested 220 bar nominal.',
        );

        // Attach proof image
        await tester.tap(
          find.byKey(const ValueKey('attach-maintenance-proof-button')),
        );
        await tester.pumpAndSettle();

        // Bottom sheet for Camera / Gallery
        await tester.tap(find.byKey(const ValueKey('pick-proof-gallery')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('maintenance-proof-preview')),
          findsOneWidget,
        );

        // Save Completed status
        await tester.tap(find.byKey(const ValueKey('save-maintenance-status')));
        await tester.pumpAndSettle();

        // 5. Verify database integrity
        taskDoc = await fakeFirestore
            .collection('maintenance')
            .doc(initialTask.id)
            .get();
        expect(
          taskDoc.data()?['status'],
          equals(AppConstants.maintenanceStatusResolved),
        );

        // Verify Storage upload occurred
        expect(mockUploader.uploadedPaths, isNotEmpty);
        expect(
          mockUploader.uploadedPaths.first,
          contains('maintenance_proofs'),
        );

        // Verify history map recorded technician UID
        final history =
            taskDoc.data()?['updateHistory'] as Map<String, dynamic>?;
        expect(history, isNotNull);
        expect(history!.length, equals(2));
      },
    );
  });

  // -------------------------------------------------------------------------
  // END-TO-END SCENARIO E: INTEGRATED CROSS-ROLE FACTORY WORKFLOW
  // -------------------------------------------------------------------------
  group('E2E Scenario E — Complete Integrated Multi-Role Factory Workflow', () {
    late FakeFirebaseFirestore sharedFirestore;
    late _MockStorageUploader sharedUploader;

    setUp(() {
      sharedFirestore = FakeFirebaseFirestore();
      sharedUploader = _MockStorageUploader();
    });

    testWidgets(
      'Integrated journey: Operator reports fault -> Manager monitors fault -> Technician repairs and resolves task with proof -> Database integrity asserted',
      (tester) async {
        // --- STEP 1: OPERATOR CONTEXT ---
        final opAuth = _MockFirebaseAuth(
          initialUser: _FakeAuthUser(
            uid: 'op_alice_1',
            email: 'alice@factory.com',
            displayName: 'Alice Operator',
          ),
        );
        final opFaultService = FaultService(
          firestore: sharedFirestore,
          firebaseAuth: opAuth,
        );

        // Pre-seed machine MCH-100
        await sharedFirestore.collection('machines').doc('MCH-100').set({
          'id': 'MCH-100',
          'name': 'Extrusion Press 100',
          'status': 'Operational',
          'productionLine': 'Extrusion A',
          'healthScore': 90.0,
        });

        // Operator reports critical breakdown
        final faultId = await opFaultService.addFault(
          FaultModel(
            id: '',
            machineId: 'MCH-100',
            machineName: 'Extrusion Press 100',
            type: 'Mechanical',
            severity: 'critical',
            description:
                'Main drive motor gearbox seized under full extrusion load.',
            reportedBy: 'op_alice_1',
            status: AppConstants.faultStatusOpen,
          ),
        );
        expect(faultId, isNotEmpty);

        // --- STEP 2: MANAGER CONTEXT ---
        final mgrAuth = _MockFirebaseAuth(
          initialUser: _FakeAuthUser(
            uid: 'mgr_bob_1',
            email: 'bob@factory.com',
            displayName: 'Bob Manager',
          ),
        );
        final mgrFaultService = FaultService(
          firestore: sharedFirestore,
          firebaseAuth: mgrAuth,
        );

        // Manager streams faults and observes critical alert
        final activeFaults = await mgrFaultService.streamFaults().first;
        expect(
          activeFaults.any((f) => f.id == faultId && f.severity == 'critical'),
          isTrue,
        );

        // Manager / System creates maintenance assignment for Technician Charlie
        final maintenanceService = MaintenanceService(
          firestore: sharedFirestore,
          firebaseAuth: mgrAuth,
        );
        final taskId = await maintenanceService.createMaintenanceTask(
          MaintenanceModel(
            id: 'maint_cross_999',
            machineId: 'MCH-100',
            machineName: 'Extrusion Press 100',
            priority: AppConstants.severityCritical,
            status: AppConstants.maintenanceStatusPending,
            technicianId: 'tech_charlie_1',
            technicianName: 'Charlie Technician',
            notes: 'Inspect drive motor coupling, unjam gears, test thermal sensor.',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        expect(taskId, isNotEmpty);

        // --- STEP 3: TECHNICIAN CONTEXT ---
        final techAuth = _MockFirebaseAuth(
          initialUser: _FakeAuthUser(
            uid: 'tech_charlie_1',
            email: 'charlie@factory.com',
            displayName: 'Charlie Technician',
          ),
        );
        final techMaintenanceService = MaintenanceService(
          firestore: sharedFirestore,
          firebaseAuth: techAuth,
        );
        final techStorageService = StorageService(
          auth: techAuth,
          uploader: sharedUploader,
        );

        // Technician fetches assigned tasks
        final assignedTasks = await techMaintenanceService
            .streamAssignedMaintenanceTasks()
            .first;
        expect(assignedTasks.any((t) => t.id == taskId), isTrue);

        // Technician transitions task to In Progress
        await techMaintenanceService.updateMaintenanceStatus(
          taskId: taskId,
          status: AppConstants.maintenanceStatusInProgress,
          notes: 'Drained lubrication oil and cleared metal shavings from bevel gear.',
        );

        // Technician uploads repair proof photo to Storage and resolves task
        final proofUrl = await techStorageService.uploadImage(
          bytes: kTestImageBytes,
          fileName: 'gearbox_clear.jpg',
          contentType: 'image/jpeg',
          folder: 'maintenance_proofs',
          customMetadata: {'taskId': taskId},
        );
        expect(proofUrl, contains('maintenance_proofs'));

        await techMaintenanceService.updateMaintenanceStatus(
          taskId: taskId,
          status: AppConstants.maintenanceStatusResolved,
          notes: 'Refilled Mobilgear 600 XP oil, aligned coupling, tested full cycle normal.',
          proofImageUrl: proofUrl,
        );

        // --- STEP 4: FINAL SYSTEM STATE VERIFICATION ---
        final finalTaskDoc = await sharedFirestore
            .collection('maintenance')
            .doc(taskId)
            .get();
        final finalData = finalTaskDoc.data()!;

        // 1. Task is fully resolved
        expect(
          finalData['status'],
          equals(AppConstants.maintenanceStatusResolved),
        );

        // 2. Proof image URL is recorded inside the resolved updateHistory entry
        final history = finalData['updateHistory'] as Map<String, dynamic>;
        expect(history.length, equals(2));

        final resolvedEntry = history.values.firstWhere(
          (e) =>
              (e as Map<String, dynamic>)['newStatus'] ==
              AppConstants.maintenanceStatusResolved,
        ) as Map<String, dynamic>;
        expect(resolvedEntry['proofImageUrl'], equals(proofUrl));
        expect(resolvedEntry['updatedBy'], equals('tech_charlie_1'));

        // 3. Original assignment notes remain preserved
        expect(
          finalData['notes'],
          equals(
            'Inspect drive motor coupling, unjam gears, test thermal sensor.',
          ),
        );

        // 4. Operator fault record remains untouched and traceable
        final finalFaultDoc = await sharedFirestore
            .collection('faults')
            .doc(faultId)
            .get();
        expect(finalFaultDoc.data()?['reportedBy'], equals('op_alice_1'));
        expect(finalFaultDoc.data()?['machineId'], equals('MCH-100'));

        opAuth.dispose();
        mgrAuth.dispose();
        techAuth.dispose();
      },
    );
  });
}
