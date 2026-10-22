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
  final FirebaseException exception;

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
  final FirebaseException exception;

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
  final FirebaseException exception;

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
      final exception = FaultServiceException.fromFirebaseException(fbException);
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
        description: 'Spindle temperature is exceeding safe operational threshold.',
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

    test('sets default fault status to Open when status is omitted or empty', () async {
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
    });

    test('accepts explicit recognized status such as In Progress if provided', () async {
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

      expect(docSnapshot.data()!['status'], AppConstants.faultStatusInProgress);
    });

    test('creation timestamp and server timestamp are handled correctly', () async {
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

      final docIdWithCustomTime = await faultService.addFault(faultWithCustomTime);
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
    });

    test('missing authenticated user is rejected without Firestore write', () async {
      fakeAuth.setCurrentUser(null);

      final fault = FaultModel(
        id: '',
        machineId: 'mock-cnc-01',
        type: AppConstants.faultTypeThermal,
        severity: AppConstants.severityHigh,
        description: 'Spindle temperature is exceeding safe operational threshold.',
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
    });

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
              .having(
                (e) => e.message,
                'message',
                contains('Allowed types'),
              ),
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
              .having((e) => e.message, 'message', contains('Allowed statuses')),
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

    test('surfaces permission-denied safely without swallowing exception', () async {
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
    });

    test('surfaces unavailable network error safely', () async {
      final errorFirestore = FakeErrorFirestore(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
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
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'deadline-exceeded',
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
      final retrieved = await faultService.getFaultById('non_existent_fault_id');
      expect(retrieved, isNull);
    });

    test('getFaultById throws on empty id', () async {
      expect(
        () => faultService.getFaultById('   '),
        throwsA(
          isA<FaultServiceException>()
              .having((e) => e.code, 'code', 'invalid-id'),
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

      final openFaults = await faultService.getFaults(status: AppConstants.faultStatusOpen);
      expect(openFaults.length, 2);

      final cncResolved = await faultService.getFaults(
        machineId: 'mock-cnc-01',
        status: AppConstants.faultStatusResolved,
      );
      expect(cncResolved.length, 1);
      expect(cncResolved.first.description, 'Fault 2');
    });

    test('streamFaults emits real-time updates', () async {
      final stream = faultService.streamFaults();

      expect(
        stream,
        emitsInOrder([
          isEmpty,
          hasLength(1),
        ]),
      );

      await Future<void>.delayed(Duration.zero);

      await faultService.addFault(
        FaultModel(
          id: '',
          machineId: 'mock-cnc-01',
          type: AppConstants.faultTypeThermal,
          severity: AppConstants.severityHigh,
          description: 'Streaming test fault',
          reportedBy: 'user_1',
        ),
      );
    });
  });
}
