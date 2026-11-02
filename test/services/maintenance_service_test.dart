// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/services/maintenance_service.dart';
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

class FakeErrorDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final Object exception;

  FakeErrorDocumentReference(this.exception);

  @override
  String get id => 'err_task_doc';

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    throw exception;
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    throw exception;
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    throw exception;
  }

  @override
  Future<void> delete() async {
    throw exception;
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream.error(exception);
  }
}

class FakeErrorCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final Object exception;

  FakeErrorCollectionReference(this.exception);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeErrorDocumentReference(exception);
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    throw exception;
  }

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return Stream.error(exception);
  }
}

class FakeErrorFirestore extends Fake implements FirebaseFirestore {
  final Object exception;

  FakeErrorFirestore(this.exception);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeErrorCollectionReference(exception);
  }
}

void main() {
  group('MaintenanceServiceException Tests', () {
    test('1. messageForErrorCode maps error codes to expected messages', () {
      expect(
        MaintenanceServiceException.messageForErrorCode('permission-denied'),
        'You do not have permission to access or modify this maintenance task.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('unauthenticated'),
        'User is not authenticated. Please log in.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('not-found'),
        'The requested maintenance task was not found.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('already-exists'),
        'A maintenance task with this ID already exists.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('unavailable'),
        'Firestore is currently unavailable. Please check your network connection.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('deadline-exceeded'),
        'The operation timed out. Please try again.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('invalid-id'),
        'A valid maintenance task identifier is required.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('invalid-machine-id'),
        'Machine ID is required.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode(
          'invalid-technician-id',
        ),
        'Technician ID is required.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('invalid-priority'),
        'The specified maintenance priority is invalid.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('invalid-status'),
        'The specified maintenance status is invalid.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('invalid-argument'),
        'Invalid maintenance data provided.',
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('unknown'),
        MaintenanceServiceException.defaultErrorMessage,
      );
      expect(
        MaintenanceServiceException.messageForErrorCode('custom_unrecognized'),
        MaintenanceServiceException.defaultErrorMessage,
      );
    });

    test('2. Safe generic exception mapping without raw exception leakage', () {
      const rawBackendLeak =
          'Internal database cluster unreachable at IP 10.0.0.12:9090';
      final fe = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'PERMISSION_DENIED',
        message: rawBackendLeak,
      );

      final mappedEx = MaintenanceServiceException.fromFirebaseException(fe);
      expect(mappedEx.code, 'permission-denied');
      expect(mappedEx.message, isNot(contains(rawBackendLeak)));
      expect(
        mappedEx.message,
        'You do not have permission to access or modify this maintenance task.',
      );

      final unknownFe = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'WEIRD_INTERNAL_PANIC',
        message: rawBackendLeak,
      );
      final mappedUnknown = MaintenanceServiceException.fromFirebaseException(
        unknownFe,
      );
      expect(mappedUnknown.code, 'weird-internal-panic');
      expect(mappedUnknown.message, isNot(contains(rawBackendLeak)));
      expect(
        mappedUnknown.message,
        MaintenanceServiceException.defaultErrorMessage,
      );
    });

    test('3. Equality and hashCode', () {
      final e1 = MaintenanceServiceException(code: 'permission-denied');
      final e2 = MaintenanceServiceException(
        code: 'permission-denied',
        message: 'You do not have permission to access or modify this maintenance task.',
      );
      final e3 = MaintenanceServiceException(code: 'not-found');
      final e4 = MaintenanceServiceException(
        code: 'permission-denied',
        message: 'Custom override message',
      );

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1, isNot(equals(e3)));
      expect(e1, isNot(equals(e4)));
      expect(e1.toString(), contains('MaintenanceServiceException'));
      expect(e1.toString(), contains('code: permission-denied'));
    });
  });

  group('Service Initialization and Helper Tests', () {
    test('exposes internal firestore and auth getters and defaults safely', () {
      final fakeFirestore = FakeFirebaseFirestore();
      final fakeAuth = FakeFirebaseAuth(
        initialUser: FakeUser(uid: 'tech_init'),
      );
      final service = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      expect(service.firestore, same(fakeFirestore));
      expect(service.auth, same(fakeAuth));
    });

    test('resolves maintenanceDoc reference and rejects blank IDs', () {
      final fakeFirestore = FakeFirebaseFirestore();
      final fakeAuth = FakeFirebaseAuth();
      final service = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      final docRef = service.maintenanceDoc('MNT-123');
      expect(docRef.path, '${AppConstants.maintenanceCollection}/MNT-123');

      expect(
        () => service.maintenanceDoc(''),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-id',
          ),
        ),
      );
      expect(
        () => service.maintenanceDoc('   \t  '),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-id',
          ),
        ),
      );
    });

    test('validates and normalizes priority values', () {
      expect(MaintenanceService.isRecognizedPriority('Critical'), isTrue);
      expect(MaintenanceService.isRecognizedPriority('critical'), isTrue);
      expect(MaintenanceService.isRecognizedPriority('HIGH'), isTrue);
      expect(MaintenanceService.isRecognizedPriority('Medium'), isTrue);
      expect(MaintenanceService.isRecognizedPriority('low'), isTrue);
      expect(MaintenanceService.isRecognizedPriority('Extreme'), isFalse);
      expect(MaintenanceService.isRecognizedPriority(null), isFalse);

      expect(
        MaintenanceService.validatePriority('critical'),
        AppConstants.severityCritical,
      );
      expect(
        MaintenanceService.validatePriority('  high  '),
        AppConstants.severityHigh,
      );
      expect(
        MaintenanceService.validatePriority('MEDIUM'),
        AppConstants.severityMedium,
      );
      expect(
        MaintenanceService.validatePriority('Low'),
        AppConstants.severityLow,
      );

      expect(
        () => MaintenanceService.validatePriority(''),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-priority',
          ),
        ),
      );
      expect(
        () => MaintenanceService.validatePriority('Urgent'),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-priority',
          ),
        ),
      );

      expect(MaintenanceService.normalizePriorityFilter(null), isNull);
      expect(MaintenanceService.normalizePriorityFilter('   '), isNull);
      expect(
        MaintenanceService.normalizePriorityFilter('  critical  '),
        AppConstants.severityCritical,
      );
    });

    test(
      'validates and normalizes status values and supports Completed alias',
      () {
        expect(MaintenanceService.isRecognizedStatus('Pending'), isTrue);
        expect(MaintenanceService.isRecognizedStatus('pending'), isTrue);
        expect(MaintenanceService.isRecognizedStatus('In Progress'), isTrue);
        expect(MaintenanceService.isRecognizedStatus('Resolved'), isTrue);
        expect(
          MaintenanceService.isRecognizedStatus(
            'Completed',
            allowCompletedAlias: true,
          ),
          isTrue,
        );
        expect(
          MaintenanceService.isRecognizedStatus(
            'Completed',
            allowCompletedAlias: false,
          ),
          isFalse,
        );
        expect(MaintenanceService.isRecognizedStatus('Archived'), isFalse);
        expect(MaintenanceService.isRecognizedStatus(null), isFalse);

        expect(
          MaintenanceService.validateStatus('pending'),
          AppConstants.maintenanceStatusPending,
        );
        expect(
          MaintenanceService.validateStatus('  in progress  '),
          AppConstants.maintenanceStatusInProgress,
        );
        expect(
          MaintenanceService.validateStatus('RESOLVED'),
          AppConstants.maintenanceStatusResolved,
        );
        // Completed normalized to canonical Resolved
        expect(
          MaintenanceService.validateStatus('Completed'),
          AppConstants.maintenanceStatusResolved,
        );
        expect(
          MaintenanceService.validateStatus('completed'),
          AppConstants.maintenanceStatusResolved,
        );

        expect(
          () => MaintenanceService.validateStatus(''),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
        expect(
          () => MaintenanceService.validateStatus('Closed'),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );

        expect(MaintenanceService.normalizeStatusFilter(null), isNull);
        expect(MaintenanceService.normalizeStatusFilter('   '), isNull);
        expect(
          MaintenanceService.normalizeStatusFilter('  Completed  '),
          AppConstants.maintenanceStatusResolved,
        );
        expect(
          MaintenanceService.normalizeStatusFilter('  Resolved  '),
          AppConstants.maintenanceStatusResolved,
        );
      },
    );

    test('validates machineId and technicianId non-empty requirements', () {
      expect(MaintenanceService.validateMachineId('  MCH-1  '), 'MCH-1');
      expect(
        () => MaintenanceService.validateMachineId('   '),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-machine-id',
          ),
        ),
      );

      expect(MaintenanceService.validateTechnicianId('  TECH-1  '), 'TECH-1');
      expect(
        () => MaintenanceService.validateTechnicianId(''),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-technician-id',
          ),
        ),
      );
    });
  });

  group('Task Creation Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth fakeAuth;
    late MaintenanceService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(
        initialUser: FakeUser(
          uid: 'tech_user_01',
          email: 'tech@machalert.com',
          displayName: 'John Tech',
        ),
      );
      service = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );
    });

    test(
      '4. Creates a valid maintenance task with an auto-generated ID',
      () async {
        final task = MaintenanceModel(
          id: '',
          machineId: 'MCH-01',
          technicianId: 'tech_user_01',
          priority: 'High',
          status: 'Pending',
        );

        final generatedId = await service.createMaintenanceTask(task);
        expect(generatedId, isNotEmpty);

        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc(generatedId)
            .get();
        expect(doc.exists, isTrue);
        expect(doc.id, generatedId);
        expect(doc.data()!['id'], generatedId);
      },
    );

    test(
      '5. Stores the expected machine, fault and technician information',
      () async {
        final task = MaintenanceModel(
          id: '',
          machineId: 'MCH-CNC-01',
          machineName: 'CNC Milling Center',
          faultId: 'FLT-987',
          technicianId: 'tech_user_01',
          technicianName: 'John Tech',
          priority: 'Critical',
          status: 'Pending',
          notes: 'Check hydraulic oil pressure and vibration.',
        );

        final id = await service.createMaintenanceTask(task);
        final snapshot = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc(id)
            .get();
        final data = snapshot.data()!;

        expect(data['machineId'], 'MCH-CNC-01');
        expect(data['machineName'], 'CNC Milling Center');
        expect(data['faultId'], 'FLT-987');
        expect(data['technicianId'], 'tech_user_01');
        expect(data['technicianName'], 'John Tech');
        expect(data['priority'], 'Critical');
        expect(data['status'], 'Pending');
        expect(data['notes'], 'Check hydraulic oil pressure and vibration.');
      },
    );

    test('6. Defaults status to Pending when omitted or empty', () async {
      final task = MaintenanceModel(
        id: '',
        machineId: 'MCH-02',
        technicianId: 'tech_user_01',
        priority: 'Medium',
        status: '',
      );

      final id = await service.createMaintenanceTask(task);
      final doc = await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc(id)
          .get();
      expect(doc.data()!['status'], AppConstants.maintenanceStatusPending);
    });

    test('7. Uses server timestamps for creation', () async {
      final task = MaintenanceModel(
        id: '',
        machineId: 'MCH-03',
        technicianId: 'tech_user_01',
        priority: 'Low',
        status: 'Pending',
      );

      final id = await service.createMaintenanceTask(task);
      final doc = await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc(id)
          .get();
      expect(doc.data()!['createdAt'], isNotNull);
      expect(doc.data()!['createdAt'], isA<Timestamp>());
    });

    test('8. Rejects missing authentication', () async {
      fakeAuth.setCurrentUser(null);

      final task = MaintenanceModel(
        id: '',
        machineId: 'MCH-01',
        technicianId: 'tech_user_01',
        priority: 'High',
        status: 'Pending',
      );

      expect(
        () => service.createMaintenanceTask(task),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );

      // Also verify empty UID rejects
      fakeAuth.setCurrentUser(FakeUser(uid: '   '));
      expect(
        () => service.createMaintenanceTask(task),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
    });

    test('9. Rejects blank machineId', () async {
      final task = MaintenanceModel(
        id: '',
        machineId: '   ',
        technicianId: 'tech_user_01',
        priority: 'High',
        status: 'Pending',
      );

      expect(
        () => service.createMaintenanceTask(task),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-machine-id',
          ),
        ),
      );
    });

    test('10. Rejects blank technicianId', () async {
      final task = MaintenanceModel(
        id: '',
        machineId: 'MCH-01',
        technicianId: '   ',
        priority: 'High',
        status: 'Pending',
      );

      expect(
        () => service.createMaintenanceTask(task),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-technician-id',
          ),
        ),
      );
    });

    test('11. Rejects invalid priority', () async {
      final task = MaintenanceModel(
        id: '',
        machineId: 'MCH-01',
        technicianId: 'tech_user_01',
        priority: 'Extreme_Urgent',
        status: 'Pending',
      );

      expect(
        () => service.createMaintenanceTask(task),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-priority',
          ),
        ),
      );
    });

    test('12. Rejects invalid initial status', () async {
      // Non-Pending statuses are rejected on creation
      final inProgressTask = MaintenanceModel(
        id: '',
        machineId: 'MCH-01',
        technicianId: 'tech_user_01',
        priority: 'High',
        status: 'In Progress',
      );
      expect(
        () => service.createMaintenanceTask(inProgressTask),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-status',
          ),
        ),
      );

      final resolvedTask = MaintenanceModel(
        id: '',
        machineId: 'MCH-01',
        technicianId: 'tech_user_01',
        priority: 'High',
        status: 'Resolved',
      );
      expect(
        () => service.createMaintenanceTask(resolvedTask),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-status',
          ),
        ),
      );

      final invalidTask = MaintenanceModel(
        id: '',
        machineId: 'MCH-01',
        technicianId: 'tech_user_01',
        priority: 'High',
        status: 'RandomStatus',
      );
      expect(
        () => service.createMaintenanceTask(invalidTask),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-status',
          ),
        ),
      );
    });

    test('13. Trims optional fields correctly', () async {
      final task = MaintenanceModel(
        id: '',
        machineId: '  MCH-TRIM  ',
        machineName: '  Conveyor Belt 01  ',
        faultId: '  FLT-TRIM-01  ',
        technicianId: '  tech_user_01  ',
        technicianName: '  Jane Doe  ',
        priority: '  medium  ',
        status: '  pending  ',
        notes: '  Replace sensor harness.  ',
      );

      final id = await service.createMaintenanceTask(task);
      final doc = await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc(id)
          .get();
      final data = doc.data()!;

      expect(data['machineId'], 'MCH-TRIM');
      expect(data['machineName'], 'Conveyor Belt 01');
      expect(data['faultId'], 'FLT-TRIM-01');
      expect(data['technicianId'], 'tech_user_01');
      expect(data['technicianName'], 'Jane Doe');
      expect(data['priority'], 'Medium');
      expect(data['status'], 'Pending');
      expect(data['notes'], 'Replace sensor harness.');
    });

    test(
      'handles Firestore write failures safely without raw error leakage',
      () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'PERMISSION_DENIED',
            message: 'Write denied by rule',
          ),
        );
        final errorService = MaintenanceService(
          firestore: errorFirestore,
          firebaseAuth: fakeAuth,
        );

        final task = MaintenanceModel(
          id: '',
          machineId: 'MCH-01',
          technicianId: 'tech_user_01',
          priority: 'High',
          status: 'Pending',
        );

        expect(
          () => errorService.createMaintenanceTask(task),
          throwsA(
            isA<MaintenanceServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or modify this maintenance task.',
                ),
          ),
        );
      },
    );
  });

  group('Task Retrieval Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth fakeAuth;
    late MaintenanceService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(initialUser: FakeUser(uid: 'tech_retrieval'));
      service = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      // Seed sample tasks
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('TASK-1')
          .set({
            'id': 'TASK-1',
            'machineId': 'MCH-100',
            'machineName': 'Lathe 100',
            'faultId': 'FLT-1',
            'technicianId': 'tech_alpha',
            'technicianName': 'Alpha Tech',
            'priority': 'Critical',
            'status': 'Pending',
            'notes': 'Spindle vibration check',
            'createdAt': Timestamp.now(),
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('TASK-2')
          .set({
            'id': 'TASK-2',
            'machineId': 'MCH-200',
            'machineName': 'Press 200',
            'faultId': 'FLT-2',
            'technicianId': 'tech_beta',
            'technicianName': 'Beta Tech',
            'priority': 'Low',
            'status': 'In Progress',
            'notes': 'Lubrication',
            'createdAt': Timestamp.now(),
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('TASK-3')
          .set({
            'id': 'TASK-3',
            'machineId': 'MCH-100',
            'machineName': 'Lathe 100',
            'technicianId': 'tech_alpha',
            'technicianName': 'Alpha Tech',
            'priority': 'High',
            'status': 'Resolved',
            'notes': 'Completed inspection',
            'createdAt': Timestamp.now(),
          });
    });

    test('14. Retrieves a maintenance document by ID', () async {
      final task = await service.getMaintenanceTaskById('TASK-1');
      expect(task, isNotNull);
      expect(task!.id, 'TASK-1');
      expect(task.machineId, 'MCH-100');
      expect(task.technicianId, 'tech_alpha');
      expect(task.priority, 'Critical');
      expect(task.status, 'Pending');
    });

    test('15. Returns null when the task does not exist', () async {
      final task = await service.getMaintenanceTaskById('NON-EXISTENT');
      expect(task, isNull);
    });

    test('16. Rejects an empty task ID', () async {
      expect(
        () => service.getMaintenanceTaskById(''),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-id',
          ),
        ),
      );
      expect(
        () => service.getMaintenanceTaskById('   '),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-id',
          ),
        ),
      );
    });

    test('17. Returns all tasks when no filters are supplied', () async {
      final tasks = await service.getMaintenanceTasks();
      expect(tasks.length, 3);
      // Verify sorted by priority: Critical (TASK-1), High (TASK-3), Low (TASK-2)
      expect(tasks.map((t) => t.id).toList(), ['TASK-1', 'TASK-3', 'TASK-2']);
    });
  });

  group('Filtering Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth fakeAuth;
    late MaintenanceService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(initialUser: FakeUser(uid: 'tech_1'));
      service = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      // Seed test dataset
      final tasks = [
        {
          'id': 'T-01',
          'machineId': 'M-01',
          'technicianId': 'tech_1',
          'priority': 'High',
          'status': 'Pending',
        },
        {
          'id': 'T-02',
          'machineId': 'M-01',
          'technicianId': 'tech_1',
          'priority': 'Critical',
          'status': 'In Progress',
        },
        {
          'id': 'T-03',
          'machineId': 'M-02',
          'technicianId': 'tech_1',
          'priority': 'Medium',
          'status': 'Resolved',
        },
        {
          'id': 'T-04',
          'machineId': 'M-02',
          'technicianId': 'tech_2',
          'priority': 'Critical',
          'status': 'Pending',
        },
        {
          'id': 'T-05',
          'machineId': 'M-03',
          'technicianId': 'tech_2',
          'priority': 'Low',
          'status': 'Resolved',
        },
      ];

      for (final t in tasks) {
        await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc(t['id']!)
            .set(t);
      }
    });

    test('18. Filters by technicianId', () async {
      final tasks = await service.getMaintenanceTasks(technicianId: 'tech_1');
      expect(tasks.length, 3);
      expect(tasks.every((t) => t.technicianId == 'tech_1'), isTrue);
    });

    test('19. Filters by machineId', () async {
      final tasks = await service.getMaintenanceTasks(machineId: 'M-01');
      expect(tasks.length, 2);
      expect(tasks.every((t) => t.machineId == 'M-01'), isTrue);
    });

    test('20. Filters by status', () async {
      final pendingTasks = await service.getMaintenanceTasks(status: 'Pending');
      expect(pendingTasks.length, 2);
      expect(pendingTasks.every((t) => t.status == 'Pending'), isTrue);

      final inProgressTasks = await service.getMaintenanceTasks(
        status: 'In Progress',
      );
      expect(inProgressTasks.length, 1);
      expect(inProgressTasks.first.id, 'T-02');
    });

    test('21. Filters by priority', () async {
      final criticalTasks = await service.getMaintenanceTasks(
        priority: 'Critical',
      );
      expect(criticalTasks.length, 2);
      expect(criticalTasks.every((t) => t.priority == 'Critical'), isTrue);
    });

    test(
      '22. Combines technicianId, machineId, status and priority filters',
      () async {
        final tasks = await service.getMaintenanceTasks(
          technicianId: 'tech_1',
          machineId: 'M-01',
          status: 'In Progress',
          priority: 'Critical',
        );
        expect(tasks.length, 1);
        expect(tasks.first.id, 'T-02');
      },
    );

    test('23. Trims filter values', () async {
      final tasks = await service.getMaintenanceTasks(
        technicianId: '  tech_1  ',
        machineId: '  M-01  ',
        status: '  Pending  ',
        priority: '  High  ',
      );
      expect(tasks.length, 1);
      expect(tasks.first.id, 'T-01');
    });

    test('24. Ignores whitespace-only optional filters', () async {
      final tasks = await service.getMaintenanceTasks(
        technicianId: '   ',
        machineId: '  \t  ',
        status: ' ',
        priority: '   ',
      );
      expect(tasks.length, 5);
    });

    test('25. Maps Completed query alias to canonical Resolved', () async {
      // Direct query with 'Completed'
      final completedTasks = await service.getMaintenanceTasks(
        status: 'Completed',
      );
      expect(completedTasks.length, 2);
      expect(completedTasks.map((t) => t.id).toSet(), {'T-03', 'T-05'});

      // Query with lowercase 'completed'
      final lowerCompleted = await service.getMaintenanceTasks(
        status: 'completed',
      );
      expect(lowerCompleted.length, 2);

      // Matches direct query with 'Resolved'
      final resolvedTasks = await service.getMaintenanceTasks(
        status: 'Resolved',
      );
      expect(resolvedTasks.length, 2);
      expect(resolvedTasks.map((t) => t.id).toSet(), {'T-03', 'T-05'});
    });

    test('26. Returns an empty list for unmatched filters', () async {
      final tasks = await service.getMaintenanceTasks(
        machineId: 'NON_EXISTENT_MACHINE',
      );
      expect(tasks, isEmpty);
    });

    test('rejects invalid status filter with typed exception', () async {
      expect(
        () => service.getMaintenanceTasks(status: 'invalid_status_xyz'),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-status',
          ),
        ),
      );
    });

    test('rejects invalid priority filter with typed exception', () async {
      expect(
        () => service.getMaintenanceTasks(priority: 'invalid_priority_xyz'),
        throwsA(
          isA<MaintenanceServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-priority',
          ),
        ),
      );
    });
  });

  group('Priority Sorting Tests', () {
    test('27. Sorts Critical, High, Medium, Low correctly', () {
      final tLow = MaintenanceModel(
        id: '1',
        machineId: 'm',
        technicianId: 't',
        priority: 'Low',
        status: 'Pending',
      );
      final tMed = MaintenanceModel(
        id: '2',
        machineId: 'm',
        technicianId: 't',
        priority: 'Medium',
        status: 'Pending',
      );
      final tHigh = MaintenanceModel(
        id: '3',
        machineId: 'm',
        technicianId: 't',
        priority: 'High',
        status: 'Pending',
      );
      final tCrit = MaintenanceModel(
        id: '4',
        machineId: 'm',
        technicianId: 't',
        priority: 'Critical',
        status: 'Pending',
      );

      final sorted = MaintenanceService.sortTasksByPriority([
        tLow,
        tMed,
        tHigh,
        tCrit,
      ]);

      expect(sorted.map((t) => t.id).toList(), ['4', '3', '2', '1']);
      expect(sorted.map((t) => t.priority).toList(), [
        'Critical',
        'High',
        'Medium',
        'Low',
      ]);
    });

    test('28. Maintains stable ordering for equal priorities', () {
      final tHigh1 = MaintenanceModel(
        id: 'H1',
        machineId: 'm',
        technicianId: 't',
        priority: 'High',
        status: 'Pending',
      );
      final tHigh2 = MaintenanceModel(
        id: 'H2',
        machineId: 'm',
        technicianId: 't',
        priority: 'High',
        status: 'Pending',
      );
      final tHigh3 = MaintenanceModel(
        id: 'H3',
        machineId: 'm',
        technicianId: 't',
        priority: 'High',
        status: 'Pending',
      );
      final tCrit = MaintenanceModel(
        id: 'C1',
        machineId: 'm',
        technicianId: 't',
        priority: 'Critical',
        status: 'Pending',
      );

      final sorted = MaintenanceService.sortTasksByPriority([
        tHigh1,
        tHigh2,
        tCrit,
        tHigh3,
      ]);

      expect(sorted.map((t) => t.id).toList(), ['C1', 'H1', 'H2', 'H3']);
    });

    test(
      '29. Handles unknown legacy priority values safely without crashing',
      () {
        final tCrit = MaintenanceModel(
          id: 'C',
          machineId: 'm',
          technicianId: 't',
          priority: 'Critical',
          status: 'Pending',
        );
        final tLow = MaintenanceModel(
          id: 'L',
          machineId: 'm',
          technicianId: 't',
          priority: 'Low',
          status: 'Pending',
        );
        final tLegacy1 = MaintenanceModel(
          id: 'LEG-1',
          machineId: 'm',
          technicianId: 't',
          priority: 'Urgent',
          status: 'Pending',
        );
        final tLegacy2 = MaintenanceModel(
          id: 'LEG-2',
          machineId: 'm',
          technicianId: 't',
          priority: '',
          status: 'Pending',
        );

        final sorted = MaintenanceService.sortTasksByPriority([
          tLegacy1,
          tLow,
          tCrit,
          tLegacy2,
        ]);

        expect(sorted.map((t) => t.id).toList(), ['C', 'L', 'LEG-1', 'LEG-2']);
      },
    );
  });

  group('Assigned-Task Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth fakeAuth;
    late MaintenanceService service;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(
        initialUser: FakeUser(uid: 'authenticated_technician'),
      );
      service = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      // Seed tasks
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('ASSIGNED-1')
          .set({
            'id': 'ASSIGNED-1',
            'machineId': 'M-1',
            'technicianId': 'authenticated_technician',
            'priority': 'High',
            'status': 'Pending',
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('OTHER-1')
          .set({
            'id': 'OTHER-1',
            'machineId': 'M-1',
            'technicianId': 'other_technician',
            'priority': 'Critical',
            'status': 'Pending',
          });
    });

    test('30. Automatically uses the authenticated Firebase UID', () async {
      final tasks = await service.getAssignedMaintenanceTasks();
      expect(tasks.length, 1);
      expect(tasks.first.id, 'ASSIGNED-1');
      expect(tasks.first.technicianId, 'authenticated_technician');
    });

    test('31. Does not accept a caller-supplied technician UID for assigned-task queries', () async {
      // getAssignedMaintenanceTasks has no technicianId parameter by design.
      // It always queries with the authenticated UID.
      final tasks = await service.getAssignedMaintenanceTasks(
        status: 'Pending',
      );
      expect(tasks.length, 1);
      expect(tasks.first.technicianId, 'authenticated_technician');
    });

    test(
      '32. Returns unauthenticated errors when no valid current user exists',
      () async {
        fakeAuth.setCurrentUser(null);

        expect(
          () => service.getAssignedMaintenanceTasks(),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              'unauthenticated',
            ),
          ),
        );

        expect(
          () => service.streamAssignedMaintenanceTasks(),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              'unauthenticated',
            ),
          ),
        );

        fakeAuth.setCurrentUser(FakeUser(uid: '   '));
        expect(
          () => service.getAssignedMaintenanceTasks(),
          throwsA(
            isA<MaintenanceServiceException>().having(
              (e) => e.code,
              'code',
              'unauthenticated',
            ),
          ),
        );
      },
    );
  });

  group('Real-Time Stream Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth fakeAuth;
    late MaintenanceService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(
        initialUser: FakeUser(uid: 'tech_stream_user'),
      );
      service = MaintenanceService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );
    });

    test('33-36. Stream emits lifecycle updates: initial, added, updated, and deleted', () async {
      final iterator = StreamIterator(service.streamMaintenanceTasks());

      try {
        // 33. Initial emission (empty collection)
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current, isEmpty);

        // 34. Added
        await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('STR-1')
            .set({
              'id': 'STR-1',
              'machineId': 'M-STR',
              'technicianId': 'tech_stream_user',
              'priority': 'Medium',
              'status': 'Pending',
            });

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        expect(iterator.current.first.id, 'STR-1');
        expect(iterator.current.first.status, 'Pending');

        // 35. Updated
        await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('STR-1')
            .update({'status': 'In Progress'});

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        expect(iterator.current.first.status, 'In Progress');

        // 36. Deleted
        await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('STR-1')
            .delete();

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current, isEmpty);
      } finally {
        await iterator.cancel();
      }
    });

    test('37. Applies combined filters in real time', () async {
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('M1-P')
          .set({
            'id': 'M1-P',
            'machineId': 'M-1',
            'technicianId': 'tech_stream_user',
            'priority': 'High',
            'status': 'Pending',
          });

      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('M1-R')
          .set({
            'id': 'M1-R',
            'machineId': 'M-1',
            'technicianId': 'tech_stream_user',
            'priority': 'Critical',
            'status': 'Resolved',
          });

      final filteredIterator = StreamIterator(
        service.streamMaintenanceTasks(
          machineId: 'M-1',
          status: 'Completed', // verifies Completed alias on real-time stream
        ),
      );

      try {
        expect(await filteredIterator.moveNext(), isTrue);
        expect(filteredIterator.current.length, 1);
        expect(filteredIterator.current.first.id, 'M1-R');
      } finally {
        await filteredIterator.cancel();
      }
    });

    test('38. Applies priority sorting to every stream emission', () async {
      final iterator = StreamIterator(service.streamMaintenanceTasks());

      try {
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current, isEmpty);

        // Add Low
        await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('T-LOW')
            .set({
              'id': 'T-LOW',
              'machineId': 'M',
              'technicianId': 'tech',
              'priority': 'Low',
              'status': 'Pending',
            });
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.first.id, 'T-LOW');

        // Add Critical
        await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('T-CRIT')
            .set({
              'id': 'T-CRIT',
              'machineId': 'M',
              'technicianId': 'tech',
              'priority': 'Critical',
              'status': 'Pending',
            });
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 2);
        // Critical must sort before Low
        expect(iterator.current.first.id, 'T-CRIT');
        expect(iterator.current.last.id, 'T-LOW');

        // Add High
        await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('T-HIGH')
            .set({
              'id': 'T-HIGH',
              'machineId': 'M',
              'technicianId': 'tech',
              'priority': 'High',
              'status': 'Pending',
            });
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 3);
        // Order: Critical, High, Low
        expect(iterator.current.map((t) => t.id).toList(), [
          'T-CRIT',
          'T-HIGH',
          'T-LOW',
        ]);
      } finally {
        await iterator.cancel();
      }
    });

    test('39. Handles stream failures safely', () async {
      final errorFirestore = FakeErrorFirestore(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'UNAVAILABLE',
          message: 'Connection dropped',
        ),
      );

      final errorService = MaintenanceService(
        firestore: errorFirestore,
        firebaseAuth: fakeAuth,
      );

      final iterator = StreamIterator(errorService.streamMaintenanceTasks());
      try {
        await expectLater(
          iterator.moveNext(),
          throwsA(
            isA<MaintenanceServiceException>()
                .having((e) => e.code, 'code', 'unavailable')
                .having(
                  (e) => e.message,
                  'message',
                  'Firestore is currently unavailable. Please check your network connection.',
                ),
          ),
        );
      } finally {
        await iterator.cancel();
      }
    });

    test('streamAssignedMaintenanceTasks streams tasks for authenticated technician', () async {
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('A1')
          .set({
            'id': 'A1',
            'machineId': 'M-1',
            'technicianId': 'tech_stream_user',
            'priority': 'High',
            'status': 'Pending',
          });
      await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('A2')
          .set({
            'id': 'A2',
            'machineId': 'M-1',
            'technicianId': 'different_tech',
            'priority': 'Critical',
            'status': 'Pending',
          });

      final iterator = StreamIterator(service.streamAssignedMaintenanceTasks());
      try {
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        expect(iterator.current.first.id, 'A1');
      } finally {
        await iterator.cancel();
      }
    });
  });
}
