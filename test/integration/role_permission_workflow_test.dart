import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/faults/fault_reporting_screen.dart';
import 'package:mach_alert/screens/machines/machine_details_screen.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// Helpers & Fakes
// ---------------------------------------------------------------------------

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
  User? _currentUser;
  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();

  void setCurrentUser(User? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  Future<void> signOut() async {
    setCurrentUser(null);
  }

  void close() => _controller.close();
}

class _MockStorageService extends Fake implements StorageService {
  int uploadCallCount = 0;
  Uint8List? lastUploadedBytes;
  String? lastUploadedFileName;
  String? lastUploadedFolder;
  Map<String, String>? lastUploadedCustomMetadata;
  String downloadUrlToReturn =
      'https://firebasestorage.googleapis.com/v0/b/bucket/o/images%2Fsample.jpg?alt=media';
  Exception? exceptionToThrow;

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    String folder = StorageService.defaultFolder,
    Map<String, String>? customMetadata,
  }) async {
    uploadCallCount++;
    lastUploadedBytes = bytes;
    lastUploadedFileName = fileName;
    lastUploadedFolder = folder;
    lastUploadedCustomMetadata = customMetadata;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return downloadUrlToReturn;
  }

  @override
  Future<String> uploadFaultImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    return uploadImage(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: 'fault_images',
    );
  }
}

Uint8List createSampleImageBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
    'CAQAAAC1HAwCAAAAC0lEQVR42mP8/x8A'
    'AusB9Y9ZcNAAAAAASUVORK5CYII=',
  );
}

Future<bool> _isEmulatorRunning(int port) async {
  try {
    final socket = await Socket.connect(
      '127.0.0.1',
      port,
      timeout: const Duration(milliseconds: 300),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

String _createMockJwt(String uid) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': uid, 'user_id': uid, 'aud': 'machalert'}),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.';
}

void main() async {
  final firestoreEmulatorActive = await _isEmulatorRunning(8080);

  group('1. Operator Workflow Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth fakeAuth;
    late FaultService faultService;
    late MachineService machineService;
    late MachineProvider machineProvider;
    late _MockStorageService mockStorageService;

    final operatorUser = UserModel(
      id: 'op_user_42',
      name: 'Sam Operator',
      email: 'operator@machalert.com',
      role: AppConstants.roleOperator,
    );

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = _MockFirebaseAuth();
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'op_user_42',
          email: 'operator@machalert.com',
          displayName: 'Sam Operator',
        ),
      );
      faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(machineService: machineService);
      mockStorageService = _MockStorageService();

      // Seed machines
      await fakeFirestore
          .collection(AppConstants.machinesCollection)
          .doc('MCH-CNC-01')
          .set({
            'id': 'MCH-CNC-01',
            'name': 'CNC Milling Center',
            'productionLine': 'Machining Line A',
            'status': 'Operational',
            'healthScore': 88,
          });
    });

    tearDown(() {
      fakeAuth.close();
    });

    testWidgets(
      'Operator Dashboard displays operational actions and denies manager/tech features',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(operatorUser);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<AuthService>.value(
                value: AuthService(firebaseAuth: fakeAuth),
              ),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, Sam Operator'), findsOneWidget);
        expect(find.text('Operator Dashboard'), findsOneWidget);
        expect(find.text('Machine Operations'), findsOneWidget);

        // Permitted operator actions
        expect(find.text('Machines'), findsOneWidget);
        expect(find.text('Report Fault'), findsOneWidget);
        expect(find.text('Fault History'), findsOneWidget);
        expect(find.text('My Reports'), findsOneWidget);

        // Denied actions
        expect(find.text('Factory Overview'), findsNothing);
        expect(find.text('Maintenance Overview'), findsNothing);
        expect(find.text('Assigned Maintenance'), findsNothing);
        expect(find.text('Maintenance'), findsNothing);
      },
    );

    testWidgets(
      'Operator navigates to MachineListScreen with read-only view (no Add Machine FAB)',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(operatorUser);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: MaterialApp(
              home: MachineListScreen(
                machines: [
                  MachineModel(
                    id: 'MCH-CNC-01',
                    name: 'CNC Milling Center',
                    productionLine: 'Machining Line A',
                    status: 'Operational',
                    healthScore: 88,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('CNC Milling Center'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Add Machine'), findsNothing);
      },
    );

    testWidgets(
      'Operator navigates to MachineDetailsScreen without management popup menu',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(operatorUser);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: MaterialApp(
              home: MachineDetailsScreen(
                machine: MachineModel(
                  id: 'MCH-CNC-01',
                  name: 'CNC Milling Center',
                  productionLine: 'Machining Line A',
                  status: 'Operational',
                  healthScore: 88,
                ),
                canManage: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('MCH-CNC-01'), findsWidgets);
        // Popup menu with edit/delete must be completely absent for operator
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      },
    );

    testWidgets(
      'Operator successfully reports fault with derived UID and persisted fields',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(operatorUser);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<FaultService>.value(value: faultService),
              Provider<StorageService>.value(value: mockStorageService),
            ],
            child: MaterialApp(
              home: FaultReportingScreen(
                machines: [
                  MachineModel(
                    id: 'MCH-CNC-01',
                    name: 'CNC Milling Center',
                    productionLine: 'Machining Line A',
                    status: 'Operational',
                    healthScore: 88,
                  ),
                ],
                faultService: faultService,
                storageService: mockStorageService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select Fault Type from dropdown
        final typeDropdown = find.byType(DropdownButtonFormField<String>).last;
        await tester.ensureVisible(typeDropdown);
        await tester.tap(typeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hydraulic').last);
        await tester.pumpAndSettle();

        // Select Severity
        final severityChip = find.widgetWithText(ChoiceChip, 'High');
        await tester.ensureVisible(severityChip);
        await tester.tap(severityChip);
        await tester.pumpAndSettle();

        // Enter Description
        final descField = find.byType(TextFormField);
        await tester.ensureVisible(descField);
        await tester.enterText(
          descField,
          'Hydraulic pressure leak detected on main clamp cylinder.',
        );
        await tester.pumpAndSettle();

        // Submit Fault
        final submitButton = find.widgetWithText(
          FilledButton,
          'Submit Fault Report',
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Verify persisted fault document in Firestore
        final snapshot = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .get();
        expect(snapshot.docs.length, equals(1));

        final faultData = snapshot.docs.first.data();
        expect(faultData['machineId'], equals('MCH-CNC-01'));
        expect(faultData['type'], equals('Hydraulic'));
        expect(faultData['severity'], equals('High'));
        expect(
          faultData['description'],
          equals('Hydraulic pressure leak detected on main clamp cylinder.'),
        );
        expect(faultData['status'], equals('Open'));
        expect(
          faultData['reportedBy'],
          equals('op_user_42'),
        ); // Derived from authenticated user
        expect(faultData['reportedByName'], isNull);
      },
    );

    testWidgets(
      'Operator fault reporting rejects empty inputs and prevents false success feedback',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(operatorUser);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<FaultService>.value(value: faultService),
              Provider<StorageService>.value(value: mockStorageService),
            ],
            child: MaterialApp(
              home: FaultReportingScreen(
                machines: [
                  MachineModel(
                    id: 'MCH-CNC-01',
                    name: 'CNC Milling Center',
                    productionLine: 'Machining Line A',
                    status: 'Operational',
                    healthScore: 88,
                  ),
                ],
                faultService: faultService,
                storageService: mockStorageService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Attempt to submit empty form without description or severity
        final submitButton = find.widgetWithText(
          FilledButton,
          'Submit Fault Report',
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(find.text('Please describe the fault.'), findsOneWidget);
        expect(find.text('Please select a severity.'), findsOneWidget);

        final snapshot = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .get();
        expect(snapshot.docs, isEmpty);
      },
    );

    testWidgets(
      'Operator image upload failure shows safe error feedback and skips fault creation',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(operatorUser);
        mockStorageService.exceptionToThrow = StorageServiceException(
          code: 'unauthorized',
          message: 'Upload failed: storage permission denied.',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<FaultService>.value(value: faultService),
              Provider<StorageService>.value(value: mockStorageService),
            ],
            child: MaterialApp(
              home: FaultReportingScreen(
                machines: [
                  MachineModel(
                    id: 'MCH-CNC-01',
                    name: 'CNC Milling Center',
                    productionLine: 'Machining Line A',
                    status: 'Operational',
                    healthScore: 88,
                  ),
                ],
                faultService: faultService,
                storageService: mockStorageService,
                pickImage: (_) async => XFile.fromData(
                  createSampleImageBytes(),
                  name: 'fault_photo.jpg',
                  mimeType: 'image/jpeg',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pick image
        final picker = find.byKey(const ValueKey('fault-image-picker'));
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Gallery'));
        await tester.pumpAndSettle();

        // Fill valid form
        final typeDropdown = find.byType(DropdownButtonFormField<String>).last;
        await tester.ensureVisible(typeDropdown);
        await tester.tap(typeDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mechanical').last);
        await tester.pumpAndSettle();

        final severityChip = find.widgetWithText(ChoiceChip, 'Critical');
        await tester.ensureVisible(severityChip);
        await tester.tap(severityChip);
        await tester.pumpAndSettle();

        final descField = find.byType(TextFormField);
        await tester.ensureVisible(descField);
        await tester.enterText(
          descField,
          'Spindle bearing breakdown requiring shutdown.',
        );
        await tester.pumpAndSettle();

        // Submit
        final submitButton = find.widgetWithText(
          FilledButton,
          'Submit Fault Report',
        );
        await tester.ensureVisible(submitButton);
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        expect(
          find.text('Upload failed: storage permission denied.'),
          findsOneWidget,
        );

        // No corrupt fault persisted in Firestore
        final snapshot = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .get();
        expect(snapshot.docs, isEmpty);
      },
    );
  });

  group('2. Technician Workflow Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth fakeAuth;
    late MaintenanceService maintenanceService;

    final techUser = UserModel(
      id: 'tech_user_07',
      name: 'Alex Technician',
      email: 'alex@machalert.com',
      role: AppConstants.roleTechnician,
    );

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = _MockFirebaseAuth();
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'tech_user_07',
          email: 'alex@machalert.com',
          displayName: 'Alex Technician',
        ),
      );
      maintenanceService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      // Seed 2 maintenance tasks: 1 assigned to tech_user_07, 1 assigned to another tech
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('task_own')
          .set({
            'id': 'task_own',
            'machineId': 'MCH-01',
            'machineName': 'Conveyor A',
            'technicianId': 'tech_user_07',
            'technicianName': 'Alex Technician',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Fix loose belt',
            'createdAt': DateTime(2026, 10, 31, 10, 0),
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('task_other')
          .set({
            'id': 'task_other',
            'machineId': 'MCH-02',
            'machineName': 'Conveyor B',
            'technicianId': 'tech_user_99',
            'technicianName': 'Other Tech',
            'priority': 'Low',
            'status': 'Pending',
            'notes': 'Check motor',
            'createdAt': DateTime(2026, 10, 31, 11, 0),
          });
    });

    tearDown(() {
      fakeAuth.close();
    });

    testWidgets(
      'Technician Dashboard renders Maintenance Overview and assigned maintenance',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(techUser);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<AuthService>.value(
                value: AuthService(firebaseAuth: fakeAuth),
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, Alex Technician'), findsOneWidget);
        expect(find.text('Technician Dashboard'), findsOneWidget);
        expect(find.text('Maintenance Overview'), findsOneWidget);

        expect(find.text('Assigned Maintenance'), findsOneWidget);
        expect(find.text('Active Faults'), findsWidgets);
        expect(find.text('Fault History'), findsOneWidget);
        expect(find.text('Machines'), findsOneWidget);

        expect(find.text('Report Fault'), findsNothing);
        expect(find.text('Factory Overview'), findsNothing);
      },
    );

    test('Technician streams strictly assigned maintenance tasks with optional filters and internal UID derivation', () async {
      // 1. Unfiltered stream derives tech UID from FirebaseAuth.currentUser internally
      final tasks = await maintenanceService
          .streamAssignedMaintenanceTasks()
          .first;
      expect(tasks.length, equals(1));
      expect(tasks.first.id, equals('task_own'));
      expect(tasks.first.technicianId, equals('tech_user_07'));

      // 2. Filter by status: 'Pending' matches, 'Resolved' yields empty
      final pendingTasks = await maintenanceService
          .streamAssignedMaintenanceTasks(status: 'Pending')
          .first;
      expect(pendingTasks.length, equals(1));
      expect(pendingTasks.first.id, equals('task_own'));

      final resolvedTasks = await maintenanceService
          .streamAssignedMaintenanceTasks(status: 'Resolved')
          .first;
      expect(resolvedTasks, isEmpty);

      // 3. Filter by machineId: 'MCH-01' matches, 'MCH-99' yields empty
      final machineTasks = await maintenanceService
          .streamAssignedMaintenanceTasks(machineId: 'MCH-01')
          .first;
      expect(machineTasks.length, equals(1));

      final unassignedMachineTasks = await maintenanceService
          .streamAssignedMaintenanceTasks(machineId: 'MCH-99')
          .first;
      expect(unassignedMachineTasks, isEmpty);

      // 4. Filter by priority: 'High' matches, 'Low' yields empty (task_other is Low but assigned to other tech)
      final highPriorityTasks = await maintenanceService
          .streamAssignedMaintenanceTasks(priority: 'High')
          .first;
      expect(highPriorityTasks.length, equals(1));

      final lowPriorityTasks = await maintenanceService
          .streamAssignedMaintenanceTasks(priority: 'Low')
          .first;
      expect(lowPriorityTasks, isEmpty);

      // 5. Unauthenticated call throws MaintenanceServiceException('unauthenticated')
      fakeAuth.setCurrentUser(null);
      expect(
        () => maintenanceService.streamAssignedMaintenanceTasks(),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            equals('unauthenticated'),
          ),
        ),
      );
    });

    test(
      'Technician valid workflow transition Pending -> In Progress',
      () async {
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_own',
          status: 'In Progress',
          notes: 'Started inspection of conveyor belt tension.',
        );

        final updatedTask = await maintenanceService.getMaintenanceTaskById(
          'task_own',
        );
        expect(updatedTask?.status, equals('In Progress'));

        final history = await maintenanceService.getMaintenanceUpdateHistory(
          'task_own',
        );
        expect(history.length, equals(1));

        final historyEntry = history.first;
        expect(historyEntry.previousStatus, equals('Pending'));
        expect(historyEntry.newStatus, equals('In Progress'));
        expect(
          historyEntry.notes,
          equals('Started inspection of conveyor belt tension.'),
        );
        expect(historyEntry.updatedBy, equals('tech_user_07'));
        // Original assignment notes preserved intact
        expect(updatedTask?.notes, equals('Fix loose belt'));
      },
    );

    test(
      'Technician valid workflow transition In Progress -> Resolved',
      () async {
        // 1. Transition to In Progress
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_own',
          status: 'In Progress',
          notes: 'Under investigation',
        );

        // 2. Transition to Resolved
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_own',
          status: 'Resolved',
          notes: 'Tension calibrated and motor tested successfully.',
          proofImageUrl: 'https://example.com/repair_done.jpg',
        );

        final resolvedTask = await maintenanceService.getMaintenanceTaskById(
          'task_own',
        );
        expect(resolvedTask?.status, equals('Resolved'));

        final history = await maintenanceService.getMaintenanceUpdateHistory(
          'task_own',
        );
        expect(history.length, equals(2));

        final lastEntry = history.last;
        expect(lastEntry.previousStatus, equals('In Progress'));
        expect(lastEntry.newStatus, equals('Resolved'));
        expect(
          lastEntry.proofImageUrl,
          equals('https://example.com/repair_done.jpg'),
        );
      },
    );

    test(
      'Technician cannot skip status from Pending directly to Resolved',
      () async {
        expect(
          () => maintenanceService.updateMaintenanceStatus(
            taskId: 'task_own',
            status: 'Resolved',
            notes: 'Illegal skip',
          ),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              equals('invalid-status-transition'),
            ),
          ),
        );
      },
    );

    test(
      'Technician cannot modify an already Resolved task (terminal state)',
      () async {
        // Move to In Progress then Resolved
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_own',
          status: 'In Progress',
        );
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_own',
          status: 'Resolved',
          notes: 'Completed',
        );

        // Attempt modification on resolved task
        expect(
          () => maintenanceService.updateMaintenanceStatus(
            taskId: 'task_own',
            status: 'In Progress',
            notes: 'Reopen attempt',
          ),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              equals('task-already-resolved'),
            ),
          ),
        );
      },
    );

    test(
      'Same-status update requires technician notes or photo proof',
      () async {
        // Move to In Progress
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_own',
          status: 'In Progress',
        );

        // Attempt same status without notes or proof
        expect(
          () => maintenanceService.updateMaintenanceStatus(
            taskId: 'task_own',
            status: 'In Progress',
            notes: null,
            proofImageUrl: null,
          ),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              equals('no-status-change'),
            ),
          ),
        );

        // Same status with note succeeds as repair log entry
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_own',
          status: 'In Progress',
          notes: 'Checked lubrication levels, awaiting new bearing.',
        );

        final task = await maintenanceService.getMaintenanceTaskById(
          'task_own',
        );
        expect(task?.status, equals('In Progress'));

        final history = await maintenanceService.getMaintenanceUpdateHistory(
          'task_own',
        );
        expect(history.length, equals(2));
      },
    );
  });

  group('3. Manager Workflow Integration Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth fakeAuth;
    late MachineService machineService;
    late MachineProvider machineProvider;
    late MaintenanceService maintenanceService;

    final managerUser = UserModel(
      id: 'mgr_user_01',
      name: 'Sarah PlantManager',
      email: 'sarah@machalert.com',
      role: AppConstants.roleManager,
    );

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = _MockFirebaseAuth();
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'mgr_user_01',
          email: 'sarah@machalert.com',
          displayName: 'Sarah PlantManager',
        ),
      );
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(machineService: machineService);
      maintenanceService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      await fakeFirestore
          .collection(AppConstants.machinesCollection)
          .doc('MCH-100')
          .set({
            'id': 'MCH-100',
            'name': 'Packaging Robot',
            'productionLine': 'Line 4',
            'status': 'Operational',
            'healthScore': 94,
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('task_001')
          .set({
            'id': 'task_001',
            'machineId': 'MCH-100',
            'technicianId': 'tech_user_07',
            'priority': 'Medium',
            'status': 'Pending',
            'notes': 'Quarterly calibration',
          });
    });

    tearDown(() {
      fakeAuth.close();
    });

    testWidgets(
      'Manager Dashboard renders Factory Overview and manager navigation controls',
      (tester) async {
        final appState = AppStateProvider()..setAuthenticated(managerUser);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<AuthService>.value(
                value: AuthService(firebaseAuth: fakeAuth),
              ),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: const MaterialApp(home: HomeScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Welcome, Sarah PlantManager'), findsOneWidget);
        expect(find.text('Manager Dashboard'), findsOneWidget);
        expect(find.text('Factory Overview'), findsOneWidget);

        expect(find.text('Machines'), findsWidgets);
        expect(find.text('Fault History'), findsOneWidget);
        expect(find.text('Faults'), findsOneWidget);
        expect(find.text('Maintenance'), findsOneWidget);
      },
    );

    test('Manager machine lifecycle: Create, Update, Delete', () async {
      // 1. Create machine
      await machineService.addMachine(
        MachineModel(
          id: 'MCH-NEW-01',
          name: 'Stamping Press 05',
          productionLine: 'Press Shop',
          status: 'Operational',
          healthScore: 100,
        ),
      );

      final created = await machineService.getMachine('MCH-NEW-01');
      expect(created, isNotNull);
      expect(created?.name, equals('Stamping Press 05'));

      // 2. Update machine
      await machineService.updateMachine('MCH-NEW-01', {
        'name': 'Stamping Press 05 Refurbished',
        'healthScore': 98,
      });

      final updated = await machineService.getMachine('MCH-NEW-01');
      expect(updated?.name, equals('Stamping Press 05 Refurbished'));
      expect(updated?.healthScore, equals(98));

      // 3. Delete machine
      await machineService.deleteMachine('MCH-NEW-01');
      final deleted = await machineService.getMachine('MCH-NEW-01');
      expect(deleted, isNull);
    });

    test(
      'Manager views all maintenance tasks regardless of assigned technician',
      () async {
        final tasks = await maintenanceService.streamMaintenanceTasks().first;
        expect(tasks.isNotEmpty, isTrue);
        expect(tasks.first.id, equals('task_001'));
        expect(tasks.first.technicianId, equals('tech_user_07'));
      },
    );
  });

  group('4. Cross-Role Workflow Integration Scenarios', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _MockFirebaseAuth fakeAuth;
    late FaultService faultService;
    late MachineService machineService;
    late MaintenanceService maintenanceService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = _MockFirebaseAuth();

      faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );
      machineService = MachineService(firestore: fakeFirestore);
      maintenanceService = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      // Seed machine
      await machineService.addMachine(
        MachineModel(
          id: 'FLOW-MCH-01',
          name: 'Assembly Line Robot',
          productionLine: 'Module Assembly',
          status: 'Operational',
          healthScore: 92,
        ),
      );
    });

    tearDown(() {
      fakeAuth.close();
    });

    test('Scenario A: End-to-end Fault Reporting to Maintenance Resolution', () async {
      // Step 1: Operator reports machine fault
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'flow_operator',
          email: 'frank@machalert.com',
          displayName: 'Frank Operator',
        ),
      );

      final faultId = await faultService.addFault(
        FaultModel(
          id: '',
          machineId: 'FLOW-MCH-01',
          machineName: 'Assembly Line Robot',
          type: 'Electrical',
          severity: 'Critical',
          description: 'Drive motor power inverter overheating.',
          reportedBy: '', // Set by service from auth
          status: 'Open',
          createdAt: DateTime.now(),
        ),
      );

      expect(faultId.isNotEmpty, isTrue);
      final reportedFault = await faultService.getFaultById(faultId);
      expect(reportedFault?.reportedBy, equals('flow_operator'));
      expect(reportedFault?.status, equals('Open'));

      // Step 2: Manager reviews fault and assigns maintenance task
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'flow_manager',
          email: 'mona@machalert.com',
          displayName: 'Mona Manager',
        ),
      );

      final allFaults = await faultService.getFaults(machineId: 'FLOW-MCH-01');
      expect(allFaults.any((f) => f.id == faultId), isTrue);

      const taskId = 'FLOW-TASK-001';
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc(taskId)
          .set({
            'id': taskId,
            'machineId': 'FLOW-MCH-01',
            'machineName': 'Assembly Line Robot',
            'faultId': faultId,
            'technicianId': 'flow_technician',
            'technicianName': 'Tara Technician',
            'priority': 'Critical',
            'status': 'Pending',
            'notes': 'Replace cooling fan and verify inverter voltage.',
            'createdAt': DateTime.now(),
          });

      // Step 3: Technician claims, repairs, and resolves the task
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'flow_technician',
          email: 'tara@machalert.com',
          displayName: 'Tara Technician',
        ),
      );

      // Technician starts task
      await maintenanceService.updateMaintenanceStatus(
        taskId: taskId,
        status: 'In Progress',
        notes: 'Arrived at cell. Lockout/tagout completed.',
      );

      // Technician resolves task with photo proof
      await maintenanceService.updateMaintenanceStatus(
        taskId: taskId,
        status: 'Resolved',
        notes:
            'Inverter fan replaced. Operating temperature normalized at 42°C.',
        proofImageUrl:
            'https://firebasestorage.googleapis.com/v0/b/bucket/o/proof.jpg',
      );

      // Verify final synchronized state
      final resolvedTask = await maintenanceService.getMaintenanceTaskById(
        taskId,
      );
      expect(resolvedTask?.status, equals('Resolved'));

      final taskHistory = await maintenanceService.getMaintenanceUpdateHistory(
        taskId,
      );
      expect(taskHistory.length, equals(2));
      expect(taskHistory.last.updatedBy, equals('flow_technician'));
      expect(taskHistory.last.proofImageUrl, isNotNull);
    });

    test('Scenario B: Technician full repair lifecycle audit trail', () async {
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'flow_technician',
          email: 'tara@machalert.com',
          displayName: 'Tara Technician',
        ),
      );

      const taskId = 'TASK-LIFECYCLE-01';
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc(taskId)
          .set({
            'id': taskId,
            'machineId': 'FLOW-MCH-01',
            'technicianId': 'flow_technician',
            'priority': 'High',
            'status': 'Pending',
            'notes': 'Inspect gear teeth',
            'createdAt': DateTime.now(),
          });

      // 1. Pending -> In Progress
      await maintenanceService.updateMaintenanceStatus(
        taskId: taskId,
        status: 'In Progress',
        notes: 'Disassembly started',
      );

      // 2. In Progress -> In Progress (intermediate log)
      await maintenanceService.updateMaintenanceStatus(
        taskId: taskId,
        status: 'In Progress',
        notes: 'Gear wear within acceptable limits. Cleaning debris.',
      );

      // 3. In Progress -> Resolved
      await maintenanceService.updateMaintenanceStatus(
        taskId: taskId,
        status: 'Resolved',
        notes: 'Reassembled and torque verified.',
        proofImageUrl: 'https://example.com/gear_torque.png',
      );

      final task = await maintenanceService.getMaintenanceTaskById(taskId);
      expect(task?.status, equals('Resolved'));

      final historyEntries = await maintenanceService
          .getMaintenanceUpdateHistory(taskId);
      expect(historyEntries.length, equals(3));

      expect(historyEntries[0].previousStatus, equals('Pending'));
      expect(historyEntries[0].newStatus, equals('In Progress'));
      expect(historyEntries[1].previousStatus, equals('In Progress'));
      expect(historyEntries[1].newStatus, equals('In Progress'));
      expect(historyEntries[2].previousStatus, equals('In Progress'));
      expect(historyEntries[2].newStatus, equals('Resolved'));

      for (final entry in historyEntries) {
        expect(entry.updatedBy, equals('flow_technician'));
      }
    });

    test('Scenario C: Role isolation across consecutive logins using real provider state transitions', () async {
      final userService = UserService(firestore: fakeFirestore);
      final appState = AppStateProvider(
        authStream: fakeAuth.authStateChanges(),
        userService: userService,
      );
      addTearDown(() => appState.dispose());

      // Seed users in Firestore users/{uid} collection
      await fakeFirestore
          .collection(AppConstants.usersCollection)
          .doc('flow_operator')
          .set({
            'uid': 'flow_operator',
            'displayName': 'Frank Operator',
            'email': 'frank@machalert.com',
            'role': AppConstants.roleOperator,
          });
      await fakeFirestore
          .collection(AppConstants.usersCollection)
          .doc('flow_technician')
          .set({
            'uid': 'flow_technician',
            'displayName': 'Tara Technician',
            'email': 'tara@machalert.com',
            'role': AppConstants.roleTechnician,
          });
      await fakeFirestore
          .collection(AppConstants.usersCollection)
          .doc('flow_manager')
          .set({
            'uid': 'flow_manager',
            'displayName': 'Mona Manager',
            'email': 'mona@machalert.com',
            'role': AppConstants.roleManager,
          });

      // 1. Operator logs in
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'flow_operator',
          email: 'frank@machalert.com',
          displayName: 'Frank Operator',
        ),
      );
      await pumpEventQueue(times: 20);

      expect(appState.status, equals(AppStatus.authenticated));
      expect(appState.user?.id, equals('flow_operator'));
      expect(appState.user?.role, equals(AppConstants.roleOperator));
      expect(appState.user?.role == AppConstants.roleManager, isFalse);
      expect(appState.user?.role == AppConstants.roleTechnician, isFalse);

      // 2. Operator logs out
      fakeAuth.setCurrentUser(null);
      await pumpEventQueue(times: 20);

      expect(appState.status, equals(AppStatus.unauthenticated));
      expect(appState.user, isNull);
      expect(appState.route, equals(AppRoute.login));

      // 3. Technician logs in
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'flow_technician',
          email: 'tara@machalert.com',
          displayName: 'Tara Technician',
        ),
      );
      await pumpEventQueue(times: 20);

      expect(appState.status, equals(AppStatus.authenticated));
      expect(appState.user?.id, equals('flow_technician'));
      expect(appState.user?.role, equals(AppConstants.roleTechnician));
      expect(appState.user?.role == AppConstants.roleManager, isFalse);

      // 4. Technician logs out
      fakeAuth.setCurrentUser(null);
      await pumpEventQueue(times: 20);

      expect(appState.status, equals(AppStatus.unauthenticated));
      expect(appState.user, isNull);
      expect(appState.route, equals(AppRoute.login));

      // 5. Manager logs in
      fakeAuth.setCurrentUser(
        _FakeAuthUser(
          uid: 'flow_manager',
          email: 'mona@machalert.com',
          displayName: 'Mona Manager',
        ),
      );
      await pumpEventQueue(times: 20);

      expect(appState.status, equals(AppStatus.authenticated));
      expect(appState.user?.id, equals('flow_manager'));
      expect(appState.user?.role, equals(AppConstants.roleManager));

      // 6. Final logout
      fakeAuth.setCurrentUser(null);
      await pumpEventQueue(times: 20);

      expect(appState.status, equals(AppStatus.unauthenticated));
      expect(appState.user, isNull);
      expect(appState.route, equals(AppRoute.login));
    });
  });

  group('5. Live Firebase Emulator Role Authorization Checks', () {
    final opToken = _createMockJwt('sec_live_op');
    final mgrToken = _createMockJwt('sec_live_mgr');

    test(
      'Operator live denial on maintenance collection read (403)',
      () async {
        final client = HttpClient();
        try {
          final uri = Uri.parse(
            'http://127.0.0.1:8080/v1/projects/machalert/databases/(default)/documents/maintenance/any_task',
          );
          final req = await client.openUrl('GET', uri);
          req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $opToken');
          final res = await req.close();
          await res.drain<void>();
          expect(res.statusCode, equals(403));
        } finally {
          client.close(force: true);
        }
      },
      skip: !firestoreEmulatorActive
          ? 'Firestore emulator not active on 127.0.0.1:8080'
          : null,
    );

    test(
      'Operator live denial on machine creation (403)',
      () async {
        final client = HttpClient();
        try {
          final uri = Uri.parse(
            'http://127.0.0.1:8080/v1/projects/machalert/databases/(default)/documents/machines?documentId=MCH_LIVE_DENY',
          );
          final req = await client.postUrl(uri);
          req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $opToken');
          req.headers.contentType = ContentType.json;
          req.write(
            jsonEncode({
              'fields': {
                'id': {'stringValue': 'MCH_LIVE_DENY'},
                'name': {'stringValue': 'Illegal Press'},
                'productionLine': {'stringValue': 'Line X'},
                'status': {'stringValue': 'Operational'},
                'healthScore': {'integerValue': '90'},
              },
            }),
          );
          final res = await req.close();
          await res.drain<void>();
          expect(res.statusCode, equals(403));
        } finally {
          client.close(force: true);
        }
      },
      skip: !firestoreEmulatorActive
          ? 'Firestore emulator not active on 127.0.0.1:8080'
          : null,
    );

    test(
      'Manager live permission on machine creation (200)',
      () async {
        final client = HttpClient();
        try {
          // Seed manager role first using admin token
          final seedUri = Uri.parse(
            'http://127.0.0.1:8080/v1/projects/machalert/databases/(default)/documents/users/sec_live_mgr',
          );
          final seedReq = await client.openUrl('PATCH', seedUri);
          seedReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
          seedReq.headers.contentType = ContentType.json;
          seedReq.write(
            jsonEncode({
              'fields': {
                'uid': {'stringValue': 'sec_live_mgr'},
                'role': {'stringValue': 'manager'},
              },
            }),
          );
          final seedRes = await seedReq.close();
          await seedRes.drain<void>();

          // Create machine as manager
          final uri = Uri.parse(
            'http://127.0.0.1:8080/v1/projects/machalert/databases/(default)/documents/machines?documentId=MCH_LIVE_MGR_OK',
          );
          final req = await client.postUrl(uri);
          req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $mgrToken');
          req.headers.contentType = ContentType.json;
          req.write(
            jsonEncode({
              'fields': {
                'id': {'stringValue': 'MCH_LIVE_MGR_OK'},
                'name': {'stringValue': 'Approved Unit'},
                'productionLine': {'stringValue': 'Line A'},
                'status': {'stringValue': 'Operational'},
                'healthScore': {'integerValue': '100'},
              },
            }),
          );
          final res = await req.close();
          await res.drain<void>();
          expect(res.statusCode, equals(200));
        } finally {
          client.close(force: true);
        }
      },
      skip: !firestoreEmulatorActive
          ? 'Firestore emulator not active on 127.0.0.1:8080'
          : null,
    );
  });
}
