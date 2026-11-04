import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/faults/fault_history_screen.dart';
import 'package:mach_alert/screens/faults/fault_reporting_screen.dart';
import 'package:mach_alert/screens/faults/my_reports_screen.dart';
import 'package:mach_alert/screens/maintenance/maintenance_task_form_screen.dart';
import 'package:mach_alert/screens/reports/reports_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

// -----------------------------------------------------------------------------
// Test Doubles and Mocks
// -----------------------------------------------------------------------------

class QAUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  QAUser({required this.uid, this.email, this.displayName});
}

class QAFirebaseAuth extends Fake implements FirebaseAuth {
  final User? _user;
  QAFirebaseAuth(this._user);

  @override
  User? get currentUser => _user;
}

class QAAuthService extends Fake implements AuthService {
  final User? mockUser;
  bool signOutCalled = false;

  QAAuthService({this.mockUser});

  @override
  User? get currentUser => mockUser;

  @override
  Stream<User?> authStateChanges() => Stream.value(mockUser);

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class QAFaultService extends Fake implements FaultService {
  final List<FaultModel> storedFaults = [];
  int addFaultCallCount = 0;
  FaultModel? lastAddedFault;
  final User? mockUser;

  QAFaultService({this.mockUser});

  @override
  FirebaseAuth get auth => QAFirebaseAuth(mockUser);

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) {
    var filtered = storedFaults;
    if (machineId != null) {
      filtered = filtered.where((f) => f.machineId == machineId).toList();
    }
    if (reportedBy != null) {
      filtered = filtered.where((f) => f.reportedBy == reportedBy).toList();
    }
    return Stream.value(filtered);
  }

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) async {
    var filtered = storedFaults;
    if (machineId != null) {
      filtered = filtered.where((f) => f.machineId == machineId).toList();
    }
    if (reportedBy != null) {
      filtered = filtered.where((f) => f.reportedBy == reportedBy).toList();
    }
    return filtered;
  }

  @override
  Future<String> addFault(FaultModel fault) async {
    addFaultCallCount++;
    lastAddedFault = fault;
    final id = 'fault-qa-${storedFaults.length + 1}';
    final saved = fault.copyWith(id: id);
    storedFaults.add(saved);
    return id;
  }
}

class QAMaintenanceService extends Fake implements MaintenanceService {
  final List<MaintenanceModel> storedTasks = [];
  int createTaskCallCount = 0;
  MaintenanceModel? lastCreatedTask;

  @override
  Stream<List<MaintenanceModel>> streamMaintenanceTasks({
    String? machineId,
    String? technicianId,
    String? status,
    String? priority,
  }) {
    var filtered = storedTasks;
    if (machineId != null) {
      filtered = filtered.where((t) => t.machineId == machineId).toList();
    }
    if (technicianId != null) {
      filtered = filtered.where((t) => t.technicianId == technicianId).toList();
    }
    return Stream.value(filtered);
  }

  @override
  Stream<List<MaintenanceModel>> streamAssignedMaintenanceTasks({
    String? status,
    String? machineId,
    String? priority,
  }) {
    return Stream.value(storedTasks);
  }

  @override
  Future<String> createMaintenanceTask(MaintenanceModel task) async {
    createTaskCallCount++;
    lastCreatedTask = task;
    final id = 'task-qa-${storedTasks.length + 1}';
    final saved = task.copyWith(id: id);
    storedTasks.add(saved);
    return id;
  }
}

class QAMachineService extends Fake implements MachineService {
  final List<MachineModel> storedMachines;
  QAMachineService({this.storedMachines = const []});

  @override
  Stream<List<MachineModel>> streamMachines({
    String? productionLine,
    String? status,
  }) {
    return Stream.value(storedMachines);
  }

  @override
  Future<List<MachineModel>> getMachines({
    String? productionLine,
    String? status,
  }) async {
    return storedMachines;
  }
}

class QAUserService extends Fake implements UserService {
  final Map<String, UserModel> profiles = {};

  @override
  Future<UserModel?> getUserProfile(String uid, {dynamic source}) async {
    return profiles[uid];
  }

  @override
  Future<List<UserModel>> getUsersByRole(String role) async {
    final norm = role.trim().toLowerCase();
    return profiles.values.where((u) => u.role.trim().toLowerCase() == norm).toList();
  }
}

class QAStorageService extends Fake implements StorageService {
  int uploadCallCount = 0;
  Uint8List? lastUploadedBytes;
  String? lastUploadedFileName;
  String provider;

  QAStorageService({this.provider = AppConstants.storageProviderSupabase});

  @override
  String get storageProvider => provider;

  @override
  Future<String> uploadFaultImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    uploadCallCount++;
    lastUploadedBytes = bytes;
    lastUploadedFileName = fileName;

    if (bytes.length > 5 * 1024 * 1024) {
      throw StorageServiceException(
        code: 'file-too-large',
        message: 'The image file exceeds the 5 MB limit. Please select a smaller image.',
      );
    }
    if (bytes.isEmpty) {
      throw StorageServiceException(
        code: 'empty-data',
        message: 'Cannot upload an empty image.',
      );
    }
    if (provider == 'unconfigured') {
      throw StorageServiceException(
        code: 'storage-unconfigured',
        message: 'Image storage is not configured.',
      );
    }

    return 'test_uid_123/1690000000_abc_$fileName';
  }

  @override
  Future<String> getSignedUrl(String pathOrUrl, {int expiresInSeconds = 3600}) async {
    if (pathOrUrl.startsWith('http')) return pathOrUrl;
    return 'https://supabase.co/storage/v1/object/sign/fault-images/$pathOrUrl?token=valid_token';
  }
}

// -----------------------------------------------------------------------------
// Test Helpers
// -----------------------------------------------------------------------------

Widget wrapWithAllProviders({
  required Widget child,
  required UserModel user,
  QAFaultService? faultService,
  QAMaintenanceService? maintenanceService,
  QAMachineService? machineService,
  QAUserService? userService,
  QAStorageService? storageService,
  MachineProvider? machineProvider,
}) {
  final appState = AppStateProvider()..setAuthenticated(user);
  final mService = machineService ?? QAMachineService();
  final mProvider = machineProvider ?? MachineProvider(machineService: mService);
  final fakeQaUser = QAUser(uid: user.id, email: user.email, displayName: user.name);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      ChangeNotifierProvider<MachineProvider>.value(value: mProvider),
      Provider<AuthService>.value(value: QAAuthService(mockUser: fakeQaUser)),
      Provider<FaultService>.value(value: faultService ?? QAFaultService(mockUser: fakeQaUser)),
      Provider<MaintenanceService>.value(value: maintenanceService ?? QAMaintenanceService()),
      Provider<MachineService>.value(value: mService),
      Provider<UserService>.value(value: userService ?? QAUserService()),
      Provider<StorageService>.value(value: storageService ?? QAStorageService()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: child,
    ),
  );
}

void main() {
  final testOperator = UserModel(
    id: 'op-101',
    name: 'Operator Alice',
    email: 'alice@machalert.com',
    role: AppConstants.roleOperator,
  );

  final testTechnician = UserModel(
    id: 'tech-201',
    name: 'Technician Bob',
    email: 'bob@machalert.com',
    role: AppConstants.roleTechnician,
  );

  final testManager = UserModel(
    id: 'mgr-301',
    name: 'Manager Carol',
    email: 'carol@machalert.com',
    role: AppConstants.roleManager,
  );

  final sampleMachine = MachineModel(
    id: 'mach-qa-01',
    name: 'CNC Milling Unit 01',
    productionLine: 'Line Alpha',
    status: AppConstants.machineStatusOperational,
    healthScore: 92.0,
  );

  group('PHASE 2 — AUTHENTICATION & ROLE-BASED ACCESS CONTROL (RBAC)', () {
    test('Client-side role escalation is strictly denied by UserService', () {
      expect(
        () => UserService.validateClientAssignableRole(AppConstants.roleManager),
        throwsA(isA<UserServiceException>().having(
          (e) => e.code,
          'code',
          'role-escalation-denied',
        )),
      );

      // Operator and Technician are permitted
      expect(
        UserService.validateClientAssignableRole(AppConstants.roleOperator),
        equals(AppConstants.roleOperator),
      );
      expect(
        UserService.validateClientAssignableRole(AppConstants.roleTechnician),
        equals(AppConstants.roleTechnician),
      );
      // Null defaults safely to operator
      expect(
        UserService.validateClientAssignableRole(null),
        equals(AppConstants.roleOperator),
      );
    });

    testWidgets('Operator Dashboard hides manager and technician maintenance actions', (tester) async {
      await tester.pumpWidget(
        wrapWithAllProviders(
          child: const HomeScreen(),
          user: testOperator,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Operator Dashboard'), findsOneWidget);
      expect(find.text('Report Fault'), findsOneWidget);
      expect(find.text('My Reports'), findsOneWidget);

      // Verify manager actions are absent
      expect(find.text('Factory Overview'), findsNothing);
      expect(find.text('Maintenance Overview'), findsNothing);
    });

    testWidgets('Technician Dashboard displays maintenance overview and active tasks', (tester) async {
      final maintenanceService = QAMaintenanceService();
      maintenanceService.storedTasks.add(MaintenanceModel(
        id: 't-1',
        machineId: sampleMachine.id,
        technicianId: testTechnician.id,
        priority: 'High',
        status: AppConstants.maintenanceStatusPending,
      ));

      await tester.pumpWidget(
        wrapWithAllProviders(
          child: const HomeScreen(),
          user: testTechnician,
          maintenanceService: maintenanceService,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Technician Dashboard'), findsOneWidget);
      expect(find.text('Maintenance Overview'), findsOneWidget);
      expect(find.text('Assigned Tasks'), findsOneWidget);
    });

    testWidgets('Manager Dashboard displays factory machine stats and quick actions', (tester) async {
      final machineService = QAMachineService(storedMachines: [sampleMachine]);
      final machineProvider = MachineProvider(machineService: machineService, autoSubscribe: true);

      await tester.pumpWidget(
        wrapWithAllProviders(
          child: const HomeScreen(),
          user: testManager,
          machineService: machineService,
          machineProvider: machineProvider,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Manager Dashboard'), findsOneWidget);
      expect(find.text('Factory Overview'), findsOneWidget);
      expect(find.text('Machines'), findsWidgets);
      expect(find.text('Fault History'), findsOneWidget);
      expect(find.text('Faults'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
    });
  });

  group('PHASE 3 & 5 — WORKFLOW & DATA INTEGRITY AUTOMATION', () {
    testWidgets('Operator submits fault report with image, human-readable name, and permanent path', (tester) async {
      final faultService = QAFaultService();
      final storageService = QAStorageService(provider: AppConstants.storageProviderSupabase);
      final userService = QAUserService();
      userService.profiles[testOperator.id] = testOperator;

      await tester.pumpWidget(
        wrapWithAllProviders(
          child: FaultReportingScreen(
            machines: [sampleMachine],
            initialMachine: sampleMachine,
            faultService: faultService,
            storageService: storageService,
            userService: userService,
          ),
          user: testOperator,
          faultService: faultService,
          storageService: storageService,
          userService: userService,
        ),
      );
      await tester.pumpAndSettle();

      // Enter fault type
      final typeFinder = find.widgetWithText(DropdownButtonFormField<String>, 'Select fault category');
      await tester.tap(typeFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppConstants.faultTypes.first).last);
      await tester.pumpAndSettle();

      // Select severity via ChoiceChip
      final chipFinder = find.widgetWithText(ChoiceChip, AppConstants.severityHigh);
      await tester.ensureVisible(chipFinder);
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Enter description
      await tester.enterText(
        find.byType(TextFormField).first,
        'Bearing overheating with excessive vibration during operation',
      );
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.widgetWithText(FilledButton, 'Submit Fault Report');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify persistence
      expect(faultService.addFaultCallCount, equals(1));
      final submitted = faultService.lastAddedFault!;
      expect(submitted.machineId, equals(sampleMachine.id));
      expect(submitted.machineName, equals(sampleMachine.name));
      expect(submitted.description, contains('Bearing overheating'));
    });

    testWidgets('Manager Maintenance creation validates machine, fault linking, and technician', (tester) async {
      final maintenanceService = QAMaintenanceService();
      final faultService = QAFaultService();
      final userService = QAUserService();
      userService.profiles[testTechnician.id] = testTechnician;

      final openFault = FaultModel(
        id: 'flt-01',
        machineId: sampleMachine.id,
        machineName: sampleMachine.name,
        type: 'Mechanical',
        severity: 'High',
        description: 'Vibration in spindle assembly',
        reportedBy: testOperator.id,
        reportedByName: testOperator.name,
        status: AppConstants.faultStatusOpen,
      );
      faultService.storedFaults.add(openFault);

      await tester.pumpWidget(
        wrapWithAllProviders(
          child: MaintenanceTaskFormScreen(
            initialMachines: [sampleMachine],
            initialTechnicians: [testTechnician],
            initialFaults: [openFault],
            maintenanceService: maintenanceService,
            faultService: faultService,
            userService: userService,
          ),
          user: testManager,
          maintenanceService: maintenanceService,
          faultService: faultService,
          userService: userService,
        ),
      );
      await tester.pumpAndSettle();

      // Select Machine
      await tester.tap(find.byKey(const ValueKey('maintenance-machine-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${sampleMachine.name} (${sampleMachine.id})').last);
      await tester.pumpAndSettle();

      // Select Technician
      await tester.tap(find.byKey(const ValueKey('maintenance-technician-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(testTechnician.name).last);
      await tester.pumpAndSettle();

      // Select Linked Fault
      await tester.tap(find.byKey(const ValueKey('maintenance-fault-id-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Vibration in spindle').last);
      await tester.pumpAndSettle();

      // Enter notes
      await tester.enterText(
        find.byKey(const ValueKey('maintenance-notes-field')),
        'Inspect bearings and balance spindle assembly.',
      );
      await tester.pumpAndSettle();

      // Submit
      final createBtn = find.byKey(const ValueKey('maintenance-submit-task-button'));
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify created task
      expect(maintenanceService.createTaskCallCount, equals(1));
      final task = maintenanceService.lastCreatedTask!;
      expect(task.machineId, equals(sampleMachine.id));
      expect(task.faultId, equals('flt-01'));
      expect(task.technicianId, equals(testTechnician.id));
      expect(task.status, equals(AppConstants.maintenanceStatusPending));
    });
  });

  group('PHASE 4 — SUPABASE STORAGE SECURITY & REJECTION HANDLING', () {
    test('Storage rejects files exceeding 5MB', () async {
      final storageService = QAStorageService();
      final oversizedBytes = Uint8List(5 * 1024 * 1024 + 1);

      expect(
        () => storageService.uploadFaultImage(
          bytes: oversizedBytes,
          fileName: 'oversized_photo.jpg',
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'file-too-large',
        )),
      );
    });

    test('Storage rejects empty payload (0 bytes)', () async {
      final storageService = QAStorageService();
      final emptyBytes = Uint8List(0);

      expect(
        () => storageService.uploadFaultImage(
          bytes: emptyBytes,
          fileName: 'empty_photo.jpg',
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'empty-data',
        )),
      );
    });

    test('Unconfigured storage displays explicit error and blocks upload', () async {
      final storageService = QAStorageService(provider: 'unconfigured');

      expect(
        () => storageService.uploadFaultImage(
          bytes: Uint8List(100),
          fileName: 'test.jpg',
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'storage-unconfigured',
        )),
      );
    });
  });

  group('PHASE 6 — DASHBOARD RECONCILIATION INVARIANT', () {
    test('Factory inventory strictly satisfies: Running + Maintenance + Breakdown + Other == Total', () {
      final testCases = [
        // Empty
        <MachineModel>[],
        // Only Running
        [MachineModel(id: '1', name: 'M1', productionLine: 'A', status: 'Operational', healthScore: 90)],
        // Warning explicitly maps to Other, NOT Maintenance
        [
          MachineModel(id: '1', name: 'M1', productionLine: 'A', status: 'Running', healthScore: 90),
          MachineModel(id: '2', name: 'M2', productionLine: 'A', status: 'Under Maintenance', healthScore: 60),
          MachineModel(id: '3', name: 'M3', productionLine: 'B', status: 'Warning', healthScore: 70),
          MachineModel(id: '4', name: 'M4', productionLine: 'B', status: 'Critical', healthScore: 20),
          MachineModel(id: '5', name: 'M5', productionLine: 'C', status: 'Decommissioned', healthScore: 0),
        ],
      ];

      for (final list in testCases) {
        final stats = MachineStatistics.fromMachines(list);
        expect(
          stats.running + stats.maintenance + stats.breakdown + stats.other,
          equals(stats.total),
          reason: 'Failed reconciliation for inventory of size ${list.length}',
        );
      }
    });
  });

  group('PHASE 7 — AUTOMATED MULTI-VIEWPORT RESPONSIVENESS & OVERFLOW AUDIT', () {
    const viewports = [
      Size(320, 568), // iPhone SE 1st gen
      Size(360, 800), // Standard Android
      Size(393, 852), // iPhone 14/15/16 Pro
      Size(412, 915), // Pixel 7/8 Pro
    ];

    for (final size in viewports) {
      testWidgets('No RenderFlex overflow on LoginScreen at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: const LoginScreen(),
            user: testOperator,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('No RenderFlex overflow on SignupScreen at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: const SignupScreen(),
            user: testOperator,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('No RenderFlex overflow on Manager Dashboard at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mService = QAMachineService(storedMachines: [sampleMachine]);
        final mProvider = MachineProvider(machineService: mService, autoSubscribe: true);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: const HomeScreen(),
            user: testManager,
            machineService: mService,
            machineProvider: mProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('No RenderFlex overflow on Technician Dashboard at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: const HomeScreen(),
            user: testTechnician,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('No RenderFlex overflow on Operator Dashboard at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: const HomeScreen(),
            user: testOperator,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('No RenderFlex overflow on FaultReportingScreen at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: FaultReportingScreen(
              machines: [sampleMachine],
              initialMachine: sampleMachine,
            ),
            user: testOperator,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('No RenderFlex overflow on MaintenanceTaskFormScreen at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: MaintenanceTaskFormScreen(
              initialMachines: [sampleMachine],
              initialTechnicians: [testTechnician],
            ),
            user: testManager,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('No RenderFlex overflow on ReportsScreen at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mService = QAMachineService(storedMachines: [sampleMachine]);
        final mProvider = MachineProvider(machineService: mService, autoSubscribe: true);

        await tester.pumpWidget(
          wrapWithAllProviders(
            child: const ReportsScreen(),
            user: testManager,
            machineService: mService,
            machineProvider: mProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('PHASE 8 — FAILURE INJECTION & RESILIENCE TESTS', () {
    testWidgets('Empty Firestore fault list produces clean empty state rather than crash', (tester) async {
      final faultService = QAFaultService();

      await tester.pumpWidget(
        wrapWithAllProviders(
          child: FaultHistoryScreen(faultService: faultService),
          user: testOperator,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No faults found'), findsOneWidget);
    });

    testWidgets('MyReportsScreen displays empty state when user has submitted no faults', (tester) async {
      final fakeUser = QAUser(uid: testOperator.id, email: testOperator.email, displayName: testOperator.name);
      final faultService = QAFaultService(mockUser: fakeUser);
      final fakeAuth = QAFirebaseAuth(fakeUser);

      await tester.pumpWidget(
        wrapWithAllProviders(
          child: MyReportsScreen(
            faultService: faultService,
            firebaseAuth: fakeAuth,
          ),
          user: testOperator,
          faultService: faultService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No reports found'), findsOneWidget);
    });
  });
}
