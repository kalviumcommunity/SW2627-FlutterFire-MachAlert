// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/services/fault_service.dart';
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
  String get id => 'err_fault_doc';

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
  group('FaultServiceException Tests', () {
    test('messageForErrorCode maps error codes to expected messages', () {
      expect(
        FaultServiceException.messageForErrorCode('permission-denied'),
        'You do not have permission to access or report this fault.',
      );
      expect(
        FaultServiceException.messageForErrorCode('not-found'),
        'The requested fault was not found.',
      );
      expect(
        FaultServiceException.messageForErrorCode('already-exists'),
        'A fault with this ID already exists.',
      );
      expect(
        FaultServiceException.messageForErrorCode('unavailable'),
        'Firestore is currently unavailable. Please check your network connection.',
      );
      expect(
        FaultServiceException.messageForErrorCode('deadline-exceeded'),
        'The operation timed out. Please try again.',
      );
      expect(
        FaultServiceException.messageForErrorCode('unauthenticated'),
        'User is not authenticated. Please log in.',
      );
      expect(
        FaultServiceException.messageForErrorCode('invalid-argument'),
        'Invalid fault data provided.',
      );
      expect(
        FaultServiceException.messageForErrorCode('invalid-id'),
        'A valid fault identifier is required.',
      );
      expect(
        FaultServiceException.messageForErrorCode('invalid-machine-id'),
        'Machine ID is required.',
      );
      expect(
        FaultServiceException.messageForErrorCode('invalid-type'),
        'The specified fault type is invalid.',
      );
      expect(
        FaultServiceException.messageForErrorCode('invalid-severity'),
        'The specified fault severity is invalid.',
      );
      expect(
        FaultServiceException.messageForErrorCode('invalid-description'),
        'Description is required.',
      );
      expect(
        FaultServiceException.messageForErrorCode('invalid-status'),
        'The specified fault status is invalid.',
      );
      expect(
        FaultServiceException.messageForErrorCode('some-random-code'),
        FaultServiceException.defaultErrorMessage,
      );
    });

    test('fromFirebaseException normalizes code with underscores', () {
      final fbException = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'PERMISSION_DENIED',
      );
      final exception = FaultServiceException.fromFirebaseException(
        fbException,
      );
      expect(exception.code, 'permission-denied');
      expect(
        exception.message,
        'You do not have permission to access or report this fault.',
      );
    });

    test('equality and toString work properly', () {
      final e1 = FaultServiceException(code: 'unauthenticated');
      final e2 = FaultServiceException(code: 'unauthenticated');
      final e3 = FaultServiceException(code: 'permission-denied');

      expect(e1, equals(e2));
      expect(e1 == e3, isFalse);
      expect(e1.hashCode, e2.hashCode);
      expect(e1.toString(), contains('unauthenticated'));
    });
  });

  group('FaultService - addFault Operation Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth fakeAuth;
    late FaultService faultService;

    const testUid = 'user_operator_123';
    final testUser = FakeUser(
      uid: testUid,
      email: 'operator@factory.com',
      displayName: 'Operator John',
    );

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(initialUser: testUser);
      faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );
    });

    test('valid fault creates a document and returns its ID', () async {
      final fault = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        machineName: 'CNC Milling Machine 01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description:
            'Spindle temperature is exceeding safe operational threshold.',
        reportedBy: 'caller_supplied_uid_to_ignore',
        reportedByName: 'Operator John',
      );

      final docId = await faultService.addFault(fault);

      expect(docId, isNotEmpty);

      final docSnapshot = await fakeFirestore
          .collection(AppConstants.faultsCollection)
          .doc(docId)
          .get();

      expect(docSnapshot.exists, isTrue);
      final data = docSnapshot.data()!;

      expect(data['id'], docId);
      expect(data['faultId'], docId);
      expect(data['machineId'], 'mock-cnc-01');
      expect(data['machineName'], 'CNC Milling Machine 01');
      expect(data['type'], AppConstants.faultTypeThermal);
      expect(data['severity'], AppConstants.severityHigh);
      expect(
        data['description'],
        'Spindle temperature is exceeding safe operational threshold.',
      );
      expect(data['reportedBy'], testUid);
      expect(data['reportedByName'], 'Operator John');
      expect(data['status'], AppConstants.faultStatusOpen);
      expect(data['createdAt'], isNotNull);
    });

    test('derives reportedBy strictly from FirebaseAuth currentUser, never caller UID', () async {
      final fault = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityMedium,
        description: 'Abnormal noise detected during compression cycle.',
        reportedBy: 'attacker_or_spoofed_uid',
      );

      final docId = await faultService.addFault(fault);

      final docSnapshot = await fakeFirestore
          .collection(AppConstants.faultsCollection)
          .doc(docId)
          .get();

      final data = docSnapshot.data()!;
      expect(data['reportedBy'], testUid);
      expect(data['reportedBy'], isNot('attacker_or_spoofed_uid'));
    });

    test(
      'sets default fault status to Open when status is omitted or empty',
      () async {
        final fault = FaultModel(
          id: '',
          machineId: 'mock-conveyor-03',
          type: AppConstants.faultTypeElectrical,
          severity: AppConstants.severityLow,
          description: 'Sensor indicator light is intermittently flickering.',
          reportedBy: 'temp',
          status: '',
        );

        final docId = await faultService.addFault(fault);

        final docSnapshot = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(docId)
            .get();

        expect(docSnapshot.data()!['status'], AppConstants.faultStatusOpen);
      },
    );

    test(
      'accepts explicit recognized status such as In Progress if provided',
      () async {
        final fault = FaultModel(
          id: '',
          machineId: 'mock-conveyor-03',
          type: AppConstants.faultTypeElectrical,
          severity: AppConstants.severityLow,
          description: 'Sensor indicator light is intermittently flickering.',
          reportedBy: 'temp',
          status: AppConstants.faultStatusInProgress,
        );

        final docId = await faultService.addFault(fault);

        final docSnapshot = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(docId)
            .get();

        expect(
          docSnapshot.data()!['status'],
          AppConstants.faultStatusInProgress,
        );
      },
    );

    test(
      'creation timestamp and server timestamp are handled correctly',
      () async {
        final customTime = DateTime.utc(2026, 10, 20, 15, 30);
        final faultWithCustomTime = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeOther,
          severity: AppConstants.severityLow,
          description: 'Lubrication level inspection required soon.',
          reportedBy: 'temp',
          createdAt: customTime,
        );

        final docIdWithCustomTime = await faultService.addFault(
          faultWithCustomTime,
        );
        final snapshotWithCustomTime = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(docIdWithCustomTime)
            .get();

        final storedTime = snapshotWithCustomTime.data()!['createdAt'];
        expect(storedTime, isA<Timestamp>());
        expect(
          (storedTime as Timestamp).toDate().isAtSameMomentAs(customTime),
          isTrue,
        );

        final faultWithoutTime = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeOther,
          severity: AppConstants.severityLow,
          description: 'Lubrication level inspection required soon.',
          reportedBy: 'temp',
          createdAt: null,
        );

        final docIdWithoutTime = await faultService.addFault(faultWithoutTime);
        final snapshotWithoutTime = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(docIdWithoutTime)
            .get();

        expect(snapshotWithoutTime.data()!['createdAt'], isNotNull);
      },
    );

    test(
      'missing authenticated user is rejected without Firestore write',
      () async {
        fakeAuth.setCurrentUser(null);

        final fault = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeThermal,
          severity: AppConstants.severityHigh,
          description:
              'Spindle temperature is exceeding safe operational threshold.',
          reportedBy: 'temp',
        );

        expect(
          () => faultService.addFault(fault),
          throwsA(
            isA<FaultServiceException>()
                .having((e) => e.code, 'code', 'unauthenticated')
                .having(
                  (e) => e.message,
                  'message',
                  'User is not authenticated. Please log in.',
                ),
          ),
        );

        final countSnapshot = await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .get();
        expect(countSnapshot.docs, isEmpty);
      },
    );

    test('invalid machineId is rejected without write', () async {
      final fault = FaultModel(
        id: '',
        machineId: '   ',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Spindle overheating.',
        reportedBy: 'temp',
      );

      expect(
        () => faultService.addFault(fault),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-machine-id')
              .having((e) => e.message, 'message', 'Machine ID is required.'),
        ),
      );

      final snapshot = await fakeFirestore
          .collection(AppConstants.faultsCollection)
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test('empty or invalid fault type is rejected without write', () async {
      final faultEmptyType = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: '',
        severity: AppConstants.severityHigh,
        description: 'Spindle overheating.',
        reportedBy: 'temp',
      );

      expect(
        () => faultService.addFault(faultEmptyType),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-type')
              .having((e) => e.message, 'message', 'Fault type is required.'),
        ),
      );

      final faultInvalidType = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: 'NonExistentCategory',
        severity: AppConstants.severityHigh,
        description: 'Spindle overheating.',
        reportedBy: 'temp',
      );

      expect(
        () => faultService.addFault(faultInvalidType),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-type')
              .having((e) => e.message, 'message', contains('Allowed types')),
        ),
      );

      final snapshot = await fakeFirestore
          .collection(AppConstants.faultsCollection)
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test('empty or invalid severity is rejected without write', () async {
      final faultEmptySev = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: '  ',
        description: 'Spindle overheating.',
        reportedBy: 'temp',
      );

      expect(
        () => faultService.addFault(faultEmptySev),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-severity')
              .having((e) => e.message, 'message', 'Severity is required.'),
        ),
      );

      final faultInvalidSev = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: 'Catastrophic',
        description: 'Spindle overheating.',
        reportedBy: 'temp',
      );

      expect(
        () => faultService.addFault(faultInvalidSev),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-severity')
              .having(
                (e) => e.message,
                'message',
                contains('Allowed severities'),
              ),
        ),
      );

      final snapshot = await fakeFirestore
          .collection(AppConstants.faultsCollection)
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test('empty description is rejected without write', () async {
      final fault = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: '   ',
        reportedBy: 'temp',
      );

      expect(
        () => faultService.addFault(fault),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-description')
              .having((e) => e.message, 'message', 'Description is required.'),
        ),
      );

      final snapshot = await fakeFirestore
          .collection(AppConstants.faultsCollection)
          .get();
      expect(snapshot.docs, isEmpty);
    });

    test('unrecognized status is rejected without write', () async {
      final fault = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Spindle overheating.',
        reportedBy: 'temp',
        status: 'Archived',
      );

      expect(
        () => faultService.addFault(fault),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-status')
              .having(
                (e) => e.message,
                'message',
                contains('Allowed statuses'),
              ),
        ),
      );

      final snapshot = await fakeFirestore
          .collection(AppConstants.faultsCollection)
          .get();
      expect(snapshot.docs, isEmpty);
    });
  });

  group('FaultService - Error Handling Tests', () {
    final validFault = FaultModel(
      id: '',
      machineId: 'mock-cnc-01',
      type: AppConstants.faultTypeThermal,
      severity: AppConstants.severityHigh,
      description: 'Spindle overheating issue with abnormal thermal spike.',
      reportedBy: 'temp',
    );

    final fakeAuth = FakeFirebaseAuth(
      initialUser: FakeUser(uid: 'operator_test_user'),
    );

    test(
      'surfaces permission-denied safely without swallowing exception',
      () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        final service = FaultService(
          firestore: errorFirestore,
          firebaseAuth: fakeAuth,
        );

        expect(
          () => service.addFault(validFault),
          throwsA(
            isA<FaultServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or report this fault.',
                ),
          ),
        );
      },
    );

    test('surfaces unavailable network error safely', () async {
      final errorFirestore = FakeErrorFirestore(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );

      final service = FaultService(
        firestore: errorFirestore,
        firebaseAuth: fakeAuth,
      );

      expect(
        () => service.addFault(validFault),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'unavailable')
              .having(
                (e) => e.message,
                'message',
                'Firestore is currently unavailable. Please check your network connection.',
              ),
        ),
      );
    });

    test('surfaces deadline-exceeded timeout error safely', () async {
      final errorFirestore = FakeErrorFirestore(
        FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded'),
      );

      final service = FaultService(
        firestore: errorFirestore,
        firebaseAuth: fakeAuth,
      );

      expect(
        () => service.addFault(validFault),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'deadline-exceeded')
              .having(
                (e) => e.message,
                'message',
                'The operation timed out. Please try again.',
              ),
        ),
      );
    });
  });

  group('FaultService - Query and Retrieval Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeFirebaseAuth fakeAuth;
    late FaultService faultService;

    final user = FakeUser(uid: 'user_1');

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      fakeAuth = FakeFirebaseAuth(initialUser: user);
      faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );
    });

    test('getFaultById returns model when document exists', () async {
      final fault = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Overheating spindle',
        reportedBy: 'user_1',
      );

      final id = await faultService.addFault(fault);
      final retrieved = await faultService.getFaultById(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, id);
      expect(retrieved.machineId, 'mock-cnc-01');
      expect(retrieved.type, AppConstants.faultTypeThermal);
      expect(retrieved.status, AppConstants.faultStatusOpen);
    });

    test('getFaultById returns null when document does not exist', () async {
      final retrieved = await faultService.getFaultById(
        'non_existent_fault_id',
      );
      expect(retrieved, isNull);
    });

    test('getFaultById throws on empty id', () async {
      expect(
        () => faultService.getFaultById('   '),
        throwsA(
          isA<FaultServiceException>().having(
            (e) => e.code,
            'code',
            'invalid-id',
          ),
        ),
      );
    });

    test('getFaults returns all faults and applies filters', () async {
      final f1 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Fault 1',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );

      final f2 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityLow,
        description: 'Fault 2',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusResolved,
      );

      final f3 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeHydraulic,
        severity: AppConstants.severityMedium,
        description: 'Fault 3',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );

      await faultService.addFault(f1);
      await faultService.addFault(f2);
      await faultService.addFault(f3);

      final allFaults = await faultService.getFaults();
      expect(allFaults.length, 3);

      final cncFaults = await faultService.getFaults(machineId: 'mock-cnc-01');
      expect(cncFaults.length, 2);

      final openFaults = await faultService.getFaults(
        status: AppConstants.faultStatusOpen,
      );
      expect(openFaults.length, 2);

      final cncResolved = await faultService.getFaults(
        machineId: 'mock-cnc-01',
        status: AppConstants.faultStatusResolved,
      );
      expect(cncResolved.length, 1);
      expect(cncResolved.first.description, 'Fault 2');
    });

    test('getFaults returns empty list on empty database', () async {
      final results = await faultService.getFaults();
      expect(results, isEmpty);
      expect(results, isA<List<FaultModel>>());
    });

    test(
      'getFaults ignores whitespace-only filters and returns matching records',
      () async {
        final fault = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeThermal,
          severity: AppConstants.severityHigh,
          description: 'Spindle overheating',
          reportedBy: 'user_1',
        );
        await faultService.addFault(fault);

        final results = await faultService.getFaults(
          machineId: '   ',
          status: '   ',
        );
        expect(results.length, 1);
        expect(results.first.machineId, 'mock-cnc-01');
      },
    );

    test(
      'getFaults surfaces Firestore permission-denied error safely',
      () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'PERMISSION_DENIED',
          ),
        );

        final service = FaultService(
          firestore: errorFirestore,
          firebaseAuth: fakeAuth,
        );

        expect(
          () => service.getFaults(),
          throwsA(
            isA<FaultServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or report this fault.',
                ),
          ),
        );
      },
    );

    test('getFaults returns only records matching severity', () async {
      final f1 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Fault High 1',
        reportedBy: 'user_1',
      );
      final f2 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityCritical,
        description: 'Fault Critical 2',
        reportedBy: 'user_1',
      );
      final f3 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeElectrical,
        severity: AppConstants.severityLow,
        description: 'Fault Low 3',
        reportedBy: 'user_1',
      );
      final f4 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeHydraulic,
        severity: AppConstants.severityHigh,
        description: 'Fault High 4',
        reportedBy: 'user_1',
      );

      final id1 = await faultService.addFault(f1);
      await faultService.addFault(f2);
      await faultService.addFault(f3);
      final id4 = await faultService.addFault(f4);

      final highFaults = await faultService.getFaults(
        severity: AppConstants.severityHigh,
      );
      expect(highFaults.length, 2);
      expect(highFaults.map((f) => f.id), unorderedEquals([id1, id4]));
      expect(
        highFaults.every((f) => f.severity == AppConstants.severityHigh),
        isTrue,
      );

      final trimmedHigh = await faultService.getFaults(
        severity: '  ${AppConstants.severityHigh}  ',
      );
      expect(trimmedHigh.length, 2);
      expect(trimmedHigh.map((f) => f.id), unorderedEquals([id1, id4]));

      final criticalFaults = await faultService.getFaults(
        severity: AppConstants.severityCritical,
      );
      expect(criticalFaults.length, 1);
      expect(criticalFaults.first.severity, AppConstants.severityCritical);
    });

    test(
      'getFaults combines machine ID, status and severity filters',
      () async {
        final f1 = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeThermal,
          severity: AppConstants.severityHigh,
          description: 'CNC Open High',
          reportedBy: 'user_1',
          status: AppConstants.faultStatusOpen,
        );
        final f2 = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeMechanical,
          severity: AppConstants.severityLow,
          description: 'CNC Open Low',
          reportedBy: 'user_1',
          status: AppConstants.faultStatusOpen,
        );
        final f3 = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeElectrical,
          severity: AppConstants.severityHigh,
          description: 'CNC Resolved High',
          reportedBy: 'user_1',
          status: AppConstants.faultStatusResolved,
        );
        final f4 = FaultModel(
          id: '',
          machineId: 'mock-press-02',
          type: AppConstants.faultTypeHydraulic,
          severity: AppConstants.severityHigh,
          description: 'Press Open High',
          reportedBy: 'user_1',
          status: AppConstants.faultStatusOpen,
        );

        final id1 = await faultService.addFault(f1);
        await faultService.addFault(f2);
        await faultService.addFault(f3);
        await faultService.addFault(f4);

        final results = await faultService.getFaults(
          machineId: 'mock-cnc-01',
          status: AppConstants.faultStatusOpen,
          severity: AppConstants.severityHigh,
        );

        expect(results.length, 1);
        expect(results.first.id, id1);
        expect(results.first.machineId, 'mock-cnc-01');
        expect(results.first.status, AppConstants.faultStatusOpen);
        expect(results.first.severity, AppConstants.severityHigh);
      },
    );

    test(
      'getFaults ignores whitespace-only filter values including severity',
      () async {
        final f1 = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeThermal,
          severity: AppConstants.severityHigh,
          description: 'Fault 1',
          reportedBy: 'user_1',
          status: AppConstants.faultStatusOpen,
        );
        final f2 = FaultModel(
          id: '',
          machineId: 'mock-press-02',
          type: AppConstants.faultTypeMechanical,
          severity: AppConstants.severityLow,
          description: 'Fault 2',
          reportedBy: 'user_1',
          status: AppConstants.faultStatusResolved,
        );

        final id1 = await faultService.addFault(f1);
        final id2 = await faultService.addFault(f2);

        // All filters whitespace-only: treated as omitted
        final allResults = await faultService.getFaults(
          machineId: '   ',
          status: ' \t ',
          severity: '  \n  ',
        );
        expect(allResults.length, 2);
        expect(allResults.map((f) => f.id), unorderedEquals([id1, id2]));

        // Valid severity with whitespace-only machineId and status
        final severityOnly = await faultService.getFaults(
          machineId: '   ',
          status: '   ',
          severity: '  ${AppConstants.severityHigh}  ',
        );
        expect(severityOnly.length, 1);
        expect(severityOnly.first.id, id1);

        // Valid machineId with whitespace-only severity
        final machineOnly = await faultService.getFaults(
          machineId: ' mock-press-02 ',
          severity: '   ',
        );
        expect(machineOnly.length, 1);
        expect(machineOnly.first.id, id2);
      },
    );

    test('getFaults returns an empty list for unmatched criteria', () async {
      final f1 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Fault 1',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );
      await faultService.addFault(f1);

      final noSeverityMatch = await faultService.getFaults(
        severity: AppConstants.severityCritical,
      );
      expect(noSeverityMatch, isEmpty);

      final noCombinedMatch = await faultService.getFaults(
        machineId: 'mock-cnc-01',
        status: AppConstants.faultStatusResolved,
        severity: AppConstants.severityHigh,
      );
      expect(noCombinedMatch, isEmpty);

      final noMachineMatch = await faultService.getFaults(
        machineId: 'non-existent-machine',
        severity: AppConstants.severityHigh,
      );
      expect(noMachineMatch, isEmpty);
    });

    test('streamFaults emits complete real-time document lifecycle: initial empty, added, updated, and deleted', () async {
      final iterator = StreamIterator(faultService.streamFaults());

      try {
        // 1. Initial snapshot: empty snapshot on empty collection
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current, isEmpty);

        // 2. Added fault: emits snapshot with newly created fault document
        final fault = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          machineName: 'CNC Milling Machine 01',
          type: AppConstants.faultTypeThermal,
          severity: AppConstants.severityHigh,
          description: 'Thermal sensor spike on spindle bearing',
          reportedBy: 'user_1',
          reportedByName: 'Operator 1',
        );
        final docId = await faultService.addFault(fault);

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        final added = iterator.current.first;
        expect(added.id, docId);
        expect(added.machineId, 'mock-cnc-01');
        expect(added.machineName, 'CNC Milling Machine 01');
        expect(added.type, AppConstants.faultTypeThermal);
        expect(added.severity, AppConstants.severityHigh);
        expect(added.description, 'Thermal sensor spike on spindle bearing');
        expect(added.status, AppConstants.faultStatusOpen);

        // 3. Updated fault status: emits snapshot with modified status
        await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(docId)
            .update({'status': AppConstants.faultStatusInProgress});

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        final updated = iterator.current.first;
        expect(updated.id, docId);
        expect(updated.status, AppConstants.faultStatusInProgress);

        // Further transition to Resolved
        await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(docId)
            .update({'status': AppConstants.faultStatusResolved});

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        final resolved = iterator.current.first;
        expect(resolved.id, docId);
        expect(resolved.status, AppConstants.faultStatusResolved);

        // 4. Deleted fault: emits empty snapshot following document removal
        await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(docId)
            .delete();

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current, isEmpty);
      } finally {
        await iterator.cancel();
      }
    });

    test('streamFaults filters by machineId, status, and combined conditions in real-time', () async {
      final f1 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'CNC Overheating',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );
      final f2 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityMedium,
        description: 'CNC Vibration',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusResolved,
      );
      final f3 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeHydraulic,
        severity: AppConstants.severityHigh,
        description: 'Press Leak',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );
      final f4 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeElectrical,
        severity: AppConstants.severityLow,
        description: 'Press Sensor Issue',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusInProgress,
      );

      final id1 = await faultService.addFault(f1);
      final id2 = await faultService.addFault(f2);
      final id3 = await faultService.addFault(f3);
      final id4 = await faultService.addFault(f4);

      // Filter by machineId only: emits only matching machine records
      final cncIterator = StreamIterator(
        faultService.streamFaults(machineId: 'mock-cnc-01'),
      );
      try {
        expect(await cncIterator.moveNext(), isTrue);
        expect(cncIterator.current.length, 2);
        expect(
          cncIterator.current.map((f) => f.id),
          unorderedEquals([id1, id2]),
        );
        expect(
          cncIterator.current.every((f) => f.machineId == 'mock-cnc-01'),
          isTrue,
        );
      } finally {
        await cncIterator.cancel();
      }

      // Filter by another machineId: emits matching press records (id3, id4)
      final pressIterator = StreamIterator(
        faultService.streamFaults(machineId: 'mock-press-02'),
      );
      try {
        expect(await pressIterator.moveNext(), isTrue);
        expect(pressIterator.current.length, 2);
        expect(
          pressIterator.current.map((f) => f.id),
          unorderedEquals([id3, id4]),
        );
        expect(
          pressIterator.current.every((f) => f.machineId == 'mock-press-02'),
          isTrue,
        );
      } finally {
        await pressIterator.cancel();
      }

      // Filter by status only: emits only matching status records
      final openIterator = StreamIterator(
        faultService.streamFaults(status: AppConstants.faultStatusOpen),
      );
      try {
        expect(await openIterator.moveNext(), isTrue);
        expect(openIterator.current.length, 2);
        expect(
          openIterator.current.map((f) => f.id),
          unorderedEquals([id1, id3]),
        );
        expect(
          openIterator.current.every(
            (f) => f.status == AppConstants.faultStatusOpen,
          ),
          isTrue,
        );
      } finally {
        await openIterator.cancel();
      }

      // Filter by In Progress status: emits id4
      final inProgressIterator = StreamIterator(
        faultService.streamFaults(status: AppConstants.faultStatusInProgress),
      );
      try {
        expect(await inProgressIterator.moveNext(), isTrue);
        expect(inProgressIterator.current.length, 1);
        expect(inProgressIterator.current.first.id, id4);
        expect(
          inProgressIterator.current.first.status,
          AppConstants.faultStatusInProgress,
        );
      } finally {
        await inProgressIterator.cancel();
      }

      // Combined filter matching a single record: applies both conditions
      final combinedIterator = StreamIterator(
        faultService.streamFaults(
          machineId: 'mock-cnc-01',
          status: AppConstants.faultStatusOpen,
        ),
      );
      try {
        expect(await combinedIterator.moveNext(), isTrue);
        expect(combinedIterator.current.length, 1);
        expect(combinedIterator.current.first.id, id1);
        expect(combinedIterator.current.first.machineId, 'mock-cnc-01');
        expect(
          combinedIterator.current.first.status,
          AppConstants.faultStatusOpen,
        );
      } finally {
        await combinedIterator.cancel();
      }

      // Combined filter matching press in-progress record (id4)
      final pressInProgressIterator = StreamIterator(
        faultService.streamFaults(
          machineId: 'mock-press-02',
          status: AppConstants.faultStatusInProgress,
        ),
      );
      try {
        expect(await pressInProgressIterator.moveNext(), isTrue);
        expect(pressInProgressIterator.current.length, 1);
        expect(pressInProgressIterator.current.first.id, id4);
        expect(
          pressInProgressIterator.current.first.machineId,
          'mock-press-02',
        );
      } finally {
        await pressInProgressIterator.cancel();
      }

      // Combined filter matching no records
      final noMatchIterator = StreamIterator(
        faultService.streamFaults(
          machineId: 'mock-press-02',
          status: AppConstants.faultStatusResolved,
        ),
      );
      try {
        expect(await noMatchIterator.moveNext(), isTrue);
        expect(noMatchIterator.current, isEmpty);
      } finally {
        await noMatchIterator.cancel();
      }

      // Active filtered stream updates when matching record is added in real time
      final liveCncIterator = StreamIterator(
        faultService.streamFaults(machineId: 'mock-cnc-01'),
      );
      try {
        expect(await liveCncIterator.moveNext(), isTrue);
        expect(liveCncIterator.current.length, 2);

        // Add a fault for mock-press-02: does not belong to mock-cnc-01 stream
        await faultService.addFault(
          FaultModel(
            id: '',
            machineId: 'mock-press-02',
            type: AppConstants.faultTypeThermal,
            severity: AppConstants.severityLow,
            description: 'Unrelated press issue',
            reportedBy: 'user_1',
          ),
        );

        // Add a fault for mock-cnc-01: stream emits updated list
        final newCncId = await faultService.addFault(
          FaultModel(
            id: '',
            machineId: 'mock-cnc-01',
            type: AppConstants.faultTypeThermal,
            severity: AppConstants.severityMedium,
            description: 'CNC Secondary Spindle Alert',
            reportedBy: 'user_1',
          ),
        );

        expect(await liveCncIterator.moveNext(), isTrue);
        expect(liveCncIterator.current.length, 3);
        expect(liveCncIterator.current.map((f) => f.id), contains(newCncId));
      } finally {
        await liveCncIterator.cancel();
      }
    });

    test('streamFaults trims whitespace around filter values and treats whitespace-only filters as omitted', () async {
      final f1 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'CNC Overheating',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );
      final f2 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityLow,
        description: 'Press Vibration',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusResolved,
      );

      final id1 = await faultService.addFault(f1);
      final id2 = await faultService.addFault(f2);

      // Whitespace around filter values is trimmed
      final trimmedBothIterator = StreamIterator(
        faultService.streamFaults(
          machineId: '   mock-cnc-01   ',
          status: '   ${AppConstants.faultStatusOpen}   ',
        ),
      );
      try {
        expect(await trimmedBothIterator.moveNext(), isTrue);
        expect(trimmedBothIterator.current.length, 1);
        expect(trimmedBothIterator.current.first.id, id1);
      } finally {
        await trimmedBothIterator.cancel();
      }

      // Whitespace-only filter values are treated as omitted (all records emitted)
      final whitespaceOnlyIterator = StreamIterator(
        faultService.streamFaults(machineId: '    ', status: '   \t  '),
      );
      try {
        expect(await whitespaceOnlyIterator.moveNext(), isTrue);
        expect(whitespaceOnlyIterator.current.length, 2);
        expect(
          whitespaceOnlyIterator.current.map((f) => f.id),
          unorderedEquals([id1, id2]),
        );
      } finally {
        await whitespaceOnlyIterator.cancel();
      }

      // Whitespace-only machineId with valid trimmed status
      final wsMachineValidStatusIterator = StreamIterator(
        faultService.streamFaults(
          machineId: '   ',
          status: '  ${AppConstants.faultStatusResolved}  ',
        ),
      );
      try {
        expect(await wsMachineValidStatusIterator.moveNext(), isTrue);
        expect(wsMachineValidStatusIterator.current.length, 1);
        expect(wsMachineValidStatusIterator.current.first.id, id2);
      } finally {
        await wsMachineValidStatusIterator.cancel();
      }

      // Valid trimmed machineId with whitespace-only status
      final validMachineWsStatusIterator = StreamIterator(
        faultService.streamFaults(
          machineId: '  mock-press-02  ',
          status: '   \n  ',
        ),
      );
      try {
        expect(await validMachineWsStatusIterator.moveNext(), isTrue);
        expect(validMachineWsStatusIterator.current.length, 1);
        expect(validMachineWsStatusIterator.current.first.id, id2);
      } finally {
        await validMachineWsStatusIterator.cancel();
      }
    });

    test('streamFaults filters by severity correctly', () async {
      final f1 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityCritical,
        description: 'Critical spindle emergency',
        reportedBy: 'user_1',
      );
      final f2 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityHigh,
        description: 'High spindle vibration',
        reportedBy: 'user_1',
      );
      final f3 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeElectrical,
        severity: AppConstants.severityCritical,
        description: 'Critical press relay failure',
        reportedBy: 'user_1',
      );

      final id1 = await faultService.addFault(f1);
      await faultService.addFault(f2);
      final id3 = await faultService.addFault(f3);

      final criticalIterator = StreamIterator(
        faultService.streamFaults(
          severity: '  ${AppConstants.severityCritical}  ',
        ),
      );
      try {
        expect(await criticalIterator.moveNext(), isTrue);
        expect(criticalIterator.current.length, 2);
        expect(
          criticalIterator.current.map((f) => f.id),
          unorderedEquals([id1, id3]),
        );
        expect(
          criticalIterator.current.every(
            (f) => f.severity == AppConstants.severityCritical,
          ),
          isTrue,
        );
      } finally {
        await criticalIterator.cancel();
      }

      final highIterator = StreamIterator(
        faultService.streamFaults(severity: AppConstants.severityHigh),
      );
      try {
        expect(await highIterator.moveNext(), isTrue);
        expect(highIterator.current.length, 1);
        expect(highIterator.current.first.severity, AppConstants.severityHigh);
        expect(
          highIterator.current.first.description,
          'High spindle vibration',
        );
      } finally {
        await highIterator.cancel();
      }
    });

    test('streamFaults applies combined machine ID, status and severity filters correctly', () async {
      final f1 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Target match',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );
      final f2 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityCritical,
        description: 'CNC Open Critical',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );
      final f3 = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityHigh,
        description: 'CNC InProgress High',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusInProgress,
      );
      final f4 = FaultModel(
        id: '',
        machineId: 'mock-press-02',
        type: AppConstants.faultTypeHydraulic,
        severity: AppConstants.severityHigh,
        description: 'Press Open High',
        reportedBy: 'user_1',
        status: AppConstants.faultStatusOpen,
      );

      final id1 = await faultService.addFault(f1);
      await faultService.addFault(f2);
      await faultService.addFault(f3);
      await faultService.addFault(f4);

      final combinedIterator = StreamIterator(
        faultService.streamFaults(
          machineId: '  mock-cnc-01  ',
          status: '  ${AppConstants.faultStatusOpen}  ',
          severity: '  ${AppConstants.severityHigh}  ',
        ),
      );
      try {
        expect(await combinedIterator.moveNext(), isTrue);
        expect(combinedIterator.current.length, 1);
        expect(combinedIterator.current.first.id, id1);
        expect(combinedIterator.current.first.machineId, 'mock-cnc-01');
        expect(
          combinedIterator.current.first.status,
          AppConstants.faultStatusOpen,
        );
        expect(
          combinedIterator.current.first.severity,
          AppConstants.severityHigh,
        );
      } finally {
        await combinedIterator.cancel();
      }

      // Combination matching zero records
      final noMatchIterator = StreamIterator(
        faultService.streamFaults(
          machineId: 'mock-cnc-01',
          status: AppConstants.faultStatusResolved,
          severity: AppConstants.severityHigh,
        ),
      );
      try {
        expect(await noMatchIterator.moveNext(), isTrue);
        expect(noMatchIterator.current, isEmpty);
      } finally {
        await noMatchIterator.cancel();
      }
    });

    test('severity-filtered stream updates when matching fault is added or changed and excludes non-matching records', () async {
      final initialLowFault = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityLow,
        description: 'Initial low severity fault',
        reportedBy: 'user_1',
      );
      final initialLowId = await faultService.addFault(initialLowFault);

      final criticalStream = faultService.streamFaults(
        severity: AppConstants.severityCritical,
      );
      final iterator = StreamIterator(criticalStream);

      try {
        // 1. Initial emission: excludes non-matching low fault
        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current, isEmpty);

        // 2. Add another non-matching record (Medium severity): remains excluded
        final mediumFault = FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeThermal,
          severity: AppConstants.severityMedium,
          description: 'Spindle warning',
          reportedBy: 'user_1',
        );
        await faultService.addFault(mediumFault);

        // 3. Add a matching fault to verify the stream update
        final matchingCritical = FaultModel(
          id: '',
          machineId: 'mock-press-02',
          type: AppConstants.faultTypeHydraulic,
          severity: AppConstants.severityCritical,
          description: 'Critical hydraulic line burst',
          reportedBy: 'user_1',
        );
        final critDocId = await faultService.addFault(matchingCritical);

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        expect(iterator.current.first.id, critDocId);
        expect(iterator.current.first.severity, AppConstants.severityCritical);
        expect(
          iterator.current.any((f) => f.id == initialLowId),
          isFalse,
          reason: 'Non-matching low severity record must remain excluded',
        );

        // 4. Update existing matching fault description: stream emits updated fault
        await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(critDocId)
            .update({'description': 'Updated: Emergency shutoff activated'});

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        expect(
          iterator.current.first.description,
          'Updated: Emergency shutoff activated',
        );

        // 5. Update the low severity fault to become Critical: stream updates and includes it
        await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(initialLowId)
            .update({'severity': AppConstants.severityCritical});

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 2);
        expect(
          iterator.current.map((f) => f.id),
          unorderedEquals([critDocId, initialLowId]),
        );

        // 6. Change severity of critDocId to Low: becomes excluded from stream
        await fakeFirestore
            .collection(AppConstants.faultsCollection)
            .doc(critDocId)
            .update({'severity': AppConstants.severityLow});

        expect(await iterator.moveNext(), isTrue);
        expect(iterator.current.length, 1);
        expect(iterator.current.first.id, initialLowId);
      } finally {
        await iterator.cancel();
      }
    });

    test('streamFaults surfaces PERMISSION_DENIED FirebaseException as user-safe FaultServiceException', () async {
      final errorFirestore = FakeErrorFirestore(
        FirebaseException(plugin: 'cloud_firestore', code: 'PERMISSION_DENIED'),
      );

      final service = FaultService(
        firestore: errorFirestore,
        firebaseAuth: fakeAuth,
      );

      final iterator = StreamIterator(service.streamFaults());
      try {
        await expectLater(
          iterator.moveNext(),
          throwsA(
            isA<FaultServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or report this fault.',
                ),
          ),
        );
      } finally {
        await iterator.cancel();
      }

      // Also verify error mapping when query filters including severity are applied
      final filteredIterator = StreamIterator(
        service.streamFaults(
          machineId: 'mock-cnc-01',
          status: AppConstants.faultStatusOpen,
          severity: AppConstants.severityHigh,
        ),
      );
      try {
        await expectLater(
          filteredIterator.moveNext(),
          throwsA(
            isA<FaultServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or report this fault.',
                ),
          ),
        );
      } finally {
        await filteredIterator.cancel();
      }
    });

    test('streamFaults surfaces UNAVAILABLE FirebaseException as user-safe FaultServiceException', () async {
      final errorFirestore = FakeErrorFirestore(
        FirebaseException(plugin: 'cloud_firestore', code: 'UNAVAILABLE'),
      );

      final service = FaultService(
        firestore: errorFirestore,
        firebaseAuth: fakeAuth,
      );

      final iterator = StreamIterator(service.streamFaults());
      try {
        await expectLater(
          iterator.moveNext(),
          throwsA(
            isA<FaultServiceException>()
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

    test('streamFaults wraps unexpected non-Firebase stream errors in unknown FaultServiceException with safe user message', () async {
      const rawInternalError =
          'Unexpected network socket disconnect with internal buffer overflow';
      final errorFirestore = FakeErrorFirestore(Exception(rawInternalError));

      final service = FaultService(
        firestore: errorFirestore,
        firebaseAuth: fakeAuth,
      );

      final iterator = StreamIterator(service.streamFaults());
      try {
        await expectLater(
          iterator.moveNext(),
          throwsA(
            isA<FaultServiceException>()
                .having((e) => e.code, 'code', 'unknown')
                .having(
                  (e) => e.message,
                  'message',
                  'A real-time fault stream error occurred. Please try again.',
                )
                .having(
                  (e) => e.message,
                  'message does not leak raw details',
                  isNot(contains(rawInternalError)),
                ),
          ),
        );
      } finally {
        await iterator.cancel();
      }
    });
  });
}
