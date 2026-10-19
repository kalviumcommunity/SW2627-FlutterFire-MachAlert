// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

class FakeErrorDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final FirebaseException exception;

  FakeErrorDocumentReference(this.exception);

  @override
  String get id => 'err_machine';

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

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    throw exception;
  }
}

void main() {
  group('MachineService Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MachineService machineService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      machineService = MachineService(firestore: fakeFirestore);
    });

    test('Canonical document path is machines/{machineId}', () {
      final docRef = machineService.machineDoc('MCH-LINE1-CNC01');
      expect(docRef.parent.id, AppConstants.machinesCollection);
      expect(docRef.id, 'MCH-LINE1-CNC01');
      expect(docRef.path, 'machines/MCH-LINE1-CNC01');
    });

    test(
      'machineDoc throws MachineServiceException for empty or whitespace ID',
      () {
        expect(
          () => machineService.machineDoc(''),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-id',
            ),
          ),
        );
        expect(
          () => machineService.machineDoc('   '),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-id',
            ),
          ),
        );
      },
    );

    group('Status validation & helpers', () {
      test(
        'isRecognizedStatus identifies recognized statuses case-insensitively',
        () {
          expect(MachineService.isRecognizedStatus('Operational'), isTrue);
          expect(MachineService.isRecognizedStatus('operational'), isTrue);
          expect(MachineService.isRecognizedStatus('Warning'), isTrue);
          expect(MachineService.isRecognizedStatus('critical'), isTrue);
          expect(
            MachineService.isRecognizedStatus('Under Maintenance'),
            isTrue,
          );
          expect(
            MachineService.isRecognizedStatus('under maintenance'),
            isTrue,
          );
          expect(MachineService.isRecognizedStatus('Broken'), isFalse);
          expect(MachineService.isRecognizedStatus(null), isFalse);
        },
      );

      test('validateStatus normalizes valid status to canonical casing', () {
        expect(
          MachineService.validateStatus('operational'),
          AppConstants.machineStatusOperational,
        );
        expect(
          MachineService.validateStatus('WARNING'),
          AppConstants.machineStatusWarning,
        );
        expect(
          MachineService.validateStatus('critical'),
          AppConstants.machineStatusCritical,
        );
        expect(
          MachineService.validateStatus('under maintenance'),
          AppConstants.machineStatusUnderMaintenance,
        );
      });

      test('validateStatus throws on empty or invalid status', () {
        expect(
          () => MachineService.validateStatus(''),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
        expect(
          () => MachineService.validateStatus('unknown_status'),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
      });
    });

    group('addMachine & createMachineFromMap', () {
      test('successfully adds a machine document with all fields', () async {
        final inspectionDate = DateTime(2026, 10, 10, 9, 30);
        final createdDate = DateTime(2026, 9, 1, 8, 0);

        final machine = MachineModel(
          id: 'MCH-LINE1-CNC01',
          name: 'CNC Milling Machine 01',
          productionLine: 'Line 1',
          modelNumber: 'Haas VF-2SS',
          status: AppConstants.machineStatusOperational,
          healthScore: 95.0,
          temperature: 68.5,
          vibration: 2.8,
          lastInspection: inspectionDate,
          createdAt: createdDate,
        );

        await machineService.addMachine(machine);

        final doc = await fakeFirestore
            .collection('machines')
            .doc('MCH-LINE1-CNC01')
            .get();

        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['id'], 'MCH-LINE1-CNC01');
        expect(data['machineId'], 'MCH-LINE1-CNC01');
        expect(data['name'], 'CNC Milling Machine 01');
        expect(data['productionLine'], 'Line 1');
        expect(data['modelNumber'], 'Haas VF-2SS');
        expect(data['status'], AppConstants.machineStatusOperational);
        expect(data['healthScore'], 95.0);
        expect(data['temperature'], 68.5);
        expect(data['vibration'], 2.8);
        expect(data['lastInspection'], isNotNull);
        expect(data['createdAt'], isNotNull);
        expect(data['updatedAt'], isNotNull);
      });

      test('createMachineFromMap generates document ID if missing', () async {
        final machine = await machineService.createMachineFromMap({
          'name': 'Hydraulic Press 02',
          'productionLine': 'Line 2',
          'status': 'Operational',
          'healthScore': 88.0,
        });

        expect(machine.id.isNotEmpty, isTrue);
        expect(machine.name, 'Hydraulic Press 02');
        expect(machine.productionLine, 'Line 2');

        final exists = await machineService.machineExists(machine.id);
        expect(exists, isTrue);
      });

      test('validates required fields on addMachine', () async {
        // Missing / empty id
        expect(
          () => machineService.addMachine(
            MachineModel(
              id: '',
              name: 'Drill',
              productionLine: 'Line 1',
              status: 'Operational',
              healthScore: 90,
            ),
          ),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-id',
            ),
          ),
        );

        // Missing / empty name
        expect(
          () => machineService.addMachine(
            MachineModel(
              id: 'M1',
              name: '  ',
              productionLine: 'Line 1',
              status: 'Operational',
              healthScore: 90,
            ),
          ),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-name',
            ),
          ),
        );

        // Missing / empty productionLine
        expect(
          () => machineService.addMachine(
            MachineModel(
              id: 'M1',
              name: 'Drill',
              productionLine: '',
              status: 'Operational',
              healthScore: 90,
            ),
          ),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-line',
            ),
          ),
        );

        // Invalid status
        expect(
          () => machineService.addMachine(
            MachineModel(
              id: 'M1',
              name: 'Drill',
              productionLine: 'Line 1',
              status: 'Malfunctioning',
              healthScore: 90,
            ),
          ),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
      });

      test('createMachineFromMap validates required fields and throws', () async {
        // Missing / empty name
        expect(
          () => machineService.createMachineFromMap({
            'productionLine': 'Line 1',
            'status': 'Operational',
          }),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-name',
            ),
          ),
        );

        // Missing / empty productionLine
        expect(
          () => machineService.createMachineFromMap({
            'name': 'Valid Name',
            'productionLine': '   ',
            'status': 'Operational',
          }),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-line',
            ),
          ),
        );

        // Invalid status
        expect(
          () => machineService.createMachineFromMap({
            'name': 'Valid Name',
            'productionLine': 'Line 1',
            'status': 'NonExistentStatus',
          }),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
      });

      test('addMachine writes matching canonical id and machineId with timestamps', () async {
        final machine = MachineModel(
          id: 'MCH-CANONICAL-01',
          name: 'Lathe Machine',
          productionLine: 'Line 2',
          status: 'Operational',
          healthScore: 90.0,
          createdAt: DateTime(2026, 10, 1),
        );

        await machineService.addMachine(machine);

        final doc = await fakeFirestore
            .collection('machines')
            .doc('MCH-CANONICAL-01')
            .get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['id'], 'MCH-CANONICAL-01');
        expect(data['machineId'], 'MCH-CANONICAL-01');
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['updatedAt'], isNotNull);
      });

      test('addMachine throws already-exists and preserves document when duplicate ID is added', () async {
        final initialMachine = MachineModel(
          id: 'M-ORIGINAL',
          name: 'Original Lathe',
          productionLine: 'Line Alpha',
          status: 'Operational',
          healthScore: 95.0,
        );
        await machineService.addMachine(initialMachine);

        final duplicateMachine = MachineModel(
          id: 'M-ORIGINAL',
          name: 'Overwriting Lathe',
          productionLine: 'Line Beta',
          status: 'Critical',
          healthScore: 10.0,
        );

        await expectLater(
          () => machineService.addMachine(duplicateMachine),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'already-exists')
                .having((e) => e.message, 'message', contains('already exists')),
          ),
        );

        final stored = await machineService.getMachineById('M-ORIGINAL');
        expect(stored, isNotNull);
        expect(stored!.name, 'Original Lathe');
        expect(stored.productionLine, 'Line Alpha');
        expect(stored.status, 'Operational');
        expect(stored.healthScore, 95.0);
      });
    });

    group('getMachineById & machineExists', () {
      test('returns null when machine does not exist', () async {
        final result = await machineService.getMachineById('non_existent');
        expect(result, isNull);

        final exists = await machineService.machineExists('non_existent');
        expect(exists, isFalse);
      });

      test(
        'retrieves existing machine accurately with getMachine alias',
        () async {
          await fakeFirestore.collection('machines').doc('MCH-100').set({
            'machineId': 'MCH-100',
            'name': 'Robotic Arm 01',
            'productionLine': 'Line 3',
            'modelNumber': 'KUKA KR-60',
            'status': 'Warning',
            'healthScore': 72.0,
            'temperature': 82.1,
            'vibration': 5.4,
            'createdAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
          });

          final machine = await machineService.getMachine('MCH-100');
          expect(machine, isNotNull);
          expect(machine!.id, 'MCH-100');
          expect(machine.name, 'Robotic Arm 01');
          expect(machine.productionLine, 'Line 3');
          expect(machine.modelNumber, 'KUKA KR-60');
          expect(machine.status, 'Warning');
          expect(machine.healthScore, 72.0);
          expect(machine.temperature, 82.1);
          expect(machine.vibration, 5.4);

          final exists = await machineService.machineExists('MCH-100');
          expect(exists, isTrue);
        },
      );
    });

    group('getMachines & getMachineList', () {
      setUp(() async {
        await fakeFirestore.collection('machines').doc('M1').set({
          'id': 'M1',
          'name': 'Lathe 1',
          'productionLine': 'Line 1',
          'status': 'Operational',
          'healthScore': 95.0,
        });
        await fakeFirestore.collection('machines').doc('M2').set({
          'id': 'M2',
          'name': 'Lathe 2',
          'productionLine': 'Line 1',
          'status': 'Warning',
          'healthScore': 65.0,
        });
        await fakeFirestore.collection('machines').doc('M3').set({
          'id': 'M3',
          'name': 'Press 1',
          'productionLine': 'Line 2',
          'status': 'Critical',
          'healthScore': 40.0,
        });
        await fakeFirestore.collection('machines').doc('M4').set({
          'id': 'M4',
          'name': 'Conveyor 1',
          'productionLine': 'Line 3',
          'status': 'Under Maintenance',
          'healthScore': 55.0,
        });
      });

      test('fetches all machines when no filter provided', () async {
        final list = await machineService.getMachineList();
        expect(list.length, 4);
      });

      test('filters machines by productionLine', () async {
        final line1Machines = await machineService.getMachines(
          productionLine: 'Line 1',
        );
        expect(line1Machines.length, 2);
        expect(
          line1Machines.every((m) => m.productionLine == 'Line 1'),
          isTrue,
        );

        final line2Machines = await machineService.getMachines(
          productionLine: 'Line 2',
        );
        expect(line2Machines.length, 1);
        expect(line2Machines.first.id, 'M3');
      });

      test('filters machines by status', () async {
        final warningMachines = await machineService.getMachines(
          status: 'Warning',
        );
        expect(warningMachines.length, 1);
        expect(warningMachines.first.id, 'M2');
      });

      test('filters machines by both productionLine and status', () async {
        final line1Operational = await machineService.getMachines(
          productionLine: 'Line 1',
          status: 'Operational',
        );
        expect(line1Operational.length, 1);
        expect(line1Operational.first.id, 'M1');

        final line1Critical = await machineService.getMachines(
          productionLine: 'Line 1',
          status: 'Critical',
        );
        expect(line1Critical, isEmpty);
      });

      test('getMachinesByLine retrieves machines for specified line', () async {
        final line1 = await machineService.getMachinesByLine('Line 1');
        expect(line1.length, 2);
        expect(line1.map((m) => m.id), containsAll(['M1', 'M2']));

        final nonExistent = await machineService.getMachinesByLine('Line 99');
        expect(nonExistent, isEmpty);
      });

      test('getMachinesByStatus retrieves machines with specified status', () async {
        final criticals = await machineService.getMachinesByStatus('Critical');
        expect(criticals.length, 1);
        expect(criticals.first.id, 'M3');

        final maintenance = await machineService.getMachinesByStatus(
          'under maintenance',
        );
        expect(maintenance.length, 1);
        expect(maintenance.first.id, 'M4');
      });

      test('getMachines throws on invalid status', () async {
        expect(
          () => machineService.getMachines(status: 'invalid_status'),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
      });

      test('getMachineById throws invalid-id on empty or whitespace id', () {
        expect(
          () => machineService.getMachineById(''),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-id',
            ),
          ),
        );
      });
    });

    group('updateMachine & updateMachineStatus', () {
      setUp(() async {
        await fakeFirestore.collection('machines').doc('MCH-UPD').set({
          'id': 'MCH-UPD',
          'name': 'Welding Unit',
          'productionLine': 'Line 2',
          'status': 'Operational',
          'healthScore': 90.0,
          'temperature': 50.0,
          'vibration': 1.5,
        });
      });

      test('updates arbitrary fields and touches updatedAt', () async {
        await machineService.updateMachine('MCH-UPD', {
          'temperature': 75.0,
          'healthScore': 80.0,
          'modelNumber': 'WeldPro-900',
        });

        final doc = await fakeFirestore
            .collection('machines')
            .doc('MCH-UPD')
            .get();
        final data = doc.data()!;
        expect(data['temperature'], 75.0);
        expect(data['healthScore'], 80.0);
        expect(data['modelNumber'], 'WeldPro-900');
        expect(data['name'], 'Welding Unit');
        expect(data['updatedAt'], isNotNull);
      });

      test(
        'updateMachine validates status when status field is present',
        () async {
          await machineService.updateMachine('MCH-UPD', {'status': 'critical'});

          final doc = await fakeFirestore
              .collection('machines')
              .doc('MCH-UPD')
              .get();
          expect(doc.data()!['status'], AppConstants.machineStatusCritical);

          expect(
            () => machineService.updateMachine('MCH-UPD', {
              'status': 'broken_down',
            }),
            throwsA(
              isA<MachineServiceException>().having(
                (e) => e.code,
                'code',
                'invalid-status',
              ),
            ),
          );
        },
      );

      test('updateMachine throws when fields map is empty', () async {
        expect(
          () => machineService.updateMachine('MCH-UPD', {}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-argument',
            ),
          ),
        );
      });

      test('updateMachineStatus updates operational status safely', () async {
        await machineService.updateMachineStatus(
          'MCH-UPD',
          AppConstants.machineStatusUnderMaintenance,
        );

        final machine = await machineService.getMachineById('MCH-UPD');
        expect(machine!.status, AppConstants.machineStatusUnderMaintenance);
      });

      test(
        'updateMachine converts DateTime lastInspection to Timestamp',
        () async {
          final inspection = DateTime(2026, 10, 15, 12, 0);
          await machineService.updateMachine('MCH-UPD', {
            'lastInspection': inspection,
          });

          final doc = await fakeFirestore
              .collection('machines')
              .doc('MCH-UPD')
              .get();
          expect(doc.data()!['lastInspection'], isA<Timestamp>());
        },
      );

      test('updateMachineModel updates mutable fields from MachineModel', () async {
        final updatedModel = MachineModel(
          id: 'MCH-UPD',
          name: 'Upgraded Welding Unit',
          productionLine: 'Line 3',
          modelNumber: 'WeldPro-950X',
          status: AppConstants.machineStatusWarning,
          healthScore: 78.0,
          temperature: 84.5,
          vibration: 4.2,
          lastInspection: DateTime(2026, 10, 18, 9, 0),
        );

        await machineService.updateMachineModel(updatedModel);

        final doc = await fakeFirestore.collection('machines').doc('MCH-UPD').get();
        final data = doc.data()!;
        expect(data['name'], 'Upgraded Welding Unit');
        expect(data['productionLine'], 'Line 3');
        expect(data['modelNumber'], 'WeldPro-950X');
        expect(data['status'], AppConstants.machineStatusWarning);
        expect(data['healthScore'], 78.0);
        expect(data['temperature'], 84.5);
        expect(data['vibration'], 4.2);
        expect(data['lastInspection'], isA<Timestamp>());
        expect(data['updatedAt'], isNotNull);
      });

      test('updateMachine throws not-found when updating non-existent machine', () async {
        expect(
          () => machineService.updateMachine('NON-EXISTENT-ID', {'name': 'New Machine'}),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'not-found')
                .having((e) => e.message, 'message', 'The requested machine was not found.'),
          ),
        );
      });

      test('updateMachine throws on empty name or empty production line', () async {
        expect(
          () => machineService.updateMachine('MCH-UPD', {'name': '   '}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-name',
            ),
          ),
        );

        expect(
          () => machineService.updateMachine('MCH-UPD', {'productionLine': ''}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-line',
            ),
          ),
        );
      });

      test('successful partial update updates only specified fields while preserving existing document data', () async {
        final initialCreatedAt = Timestamp.fromDate(DateTime(2026, 9, 1));
        await fakeFirestore.collection('machines').doc('MCH-PARTIAL').set({
          'id': 'MCH-PARTIAL',
          'machineId': 'MCH-PARTIAL',
          'name': 'Original Name',
          'productionLine': 'Line 1',
          'status': 'Operational',
          'healthScore': 95.0,
          'createdAt': initialCreatedAt,
          'updatedAt': initialCreatedAt,
        });

        // Partial update: only line and temperature
        await machineService.updateMachine('MCH-PARTIAL', {
          'productionLine': 'Line 3',
          'temperature': 74.2,
        });

        final doc = await fakeFirestore.collection('machines').doc('MCH-PARTIAL').get();
        final data = doc.data()!;
        expect(data['name'], 'Original Name'); // Preserved
        expect(data['productionLine'], 'Line 3'); // Updated
        expect(data['temperature'], 74.2); // Added/Updated
        expect(data['healthScore'], 95.0); // Preserved
        expect(data['createdAt'], initialCreatedAt); // Preserved
        expect(data['updatedAt'], isNotNull);
      });

      test('updateMachine throws invalid-argument for out-of-range or invalid numeric values', () async {
        // Negative health score
        expect(
          () => machineService.updateMachine('MCH-UPD', {'healthScore': -1.0}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-argument',
            ),
          ),
        );

        // Health score > 100
        expect(
          () => machineService.updateMachine('MCH-UPD', {'healthScore': 105.0}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-argument',
            ),
          ),
        );

        // Health score non-numeric
        expect(
          () => machineService.updateMachine('MCH-UPD', {'healthScore': 'good'}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-argument',
            ),
          ),
        );

        // Non-numeric temperature
        expect(
          () => machineService.updateMachine('MCH-UPD', {'temperature': 'boiling'}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-argument',
            ),
          ),
        );

        // Non-numeric vibration
        expect(
          () => machineService.updateMachine('MCH-UPD', {'vibration': 'shaky'}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-argument',
            ),
          ),
        );
      });

      test('updateMachine throws invalid-status when updating status to unrecognized status', () async {
        expect(
          () => machineService.updateMachine('MCH-UPD', {'status': 'Exploded'}),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
      });

      test('updateMachineModel throws not-found when updating non-existent machine', () async {
        final missingMachine = MachineModel(
          id: 'DOES-NOT-EXIST',
          name: 'Ghost Machine',
          productionLine: 'Line 1',
          status: 'Operational',
          healthScore: 85.0,
        );

        expect(
          () => machineService.updateMachineModel(missingMachine),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'not-found')
                .having((e) => e.message, 'message', 'The requested machine was not found.'),
          ),
        );
      });

      test('updateMachineStatus normalizes status casing and throws on invalid status', () async {
        await machineService.updateMachineStatus('MCH-UPD', 'warning');
        final machine = await machineService.getMachineById('MCH-UPD');
        expect(machine!.status, 'Warning');

        expect(
          () => machineService.updateMachineStatus('MCH-UPD', 'invalid_status'),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );

        expect(
          () => machineService.updateMachineStatus('MCH-UPD', ''),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-status',
            ),
          ),
        );
      });
    });

    group('deleteMachine', () {
      test('successfully deletes an existing machine', () async {
        await fakeFirestore.collection('machines').doc('MCH-DEL').set({
          'id': 'MCH-DEL',
          'name': 'Obsolete Sorter',
          'productionLine': 'Line 1',
          'status': 'Critical',
        });

        expect(await machineService.machineExists('MCH-DEL'), isTrue);

        await machineService.deleteMachine('MCH-DEL');

        expect(await machineService.machineExists('MCH-DEL'), isFalse);
        final fetched = await machineService.getMachineById('MCH-DEL');
        expect(fetched, isNull);
      });

      test('deleting a non-existent machine is safe and completes without error', () async {
        expect(await machineService.machineExists('MCH-GHOST'), isFalse);

        await machineService.deleteMachine('MCH-GHOST');

        expect(await machineService.machineExists('MCH-GHOST'), isFalse);
      });

      test('deleteMachine throws invalid-id for empty or whitespace id', () {
        expect(
          () => machineService.deleteMachine(''),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-id',
            ),
          ),
        );

        expect(
          () => machineService.deleteMachine('   '),
          throwsA(
            isA<MachineServiceException>().having(
              (e) => e.code,
              'code',
              'invalid-id',
            ),
          ),
        );
      });
    });

    group('Real-time Streams', () {
      test('streamMachine emits updates in real time', () async {
        final stream = machineService.streamMachine('MCH-STR');
        final emissions = <MachineModel?>[];
        final sub = stream.listen(emissions.add);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.isNotEmpty, isTrue);
        expect(emissions.last, isNull);

        // Add document
        await machineService.addMachine(
          MachineModel(
            id: 'MCH-STR',
            name: 'Laser Cutter',
            productionLine: 'Line 2',
            status: AppConstants.machineStatusOperational,
            healthScore: 99.0,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last, isNotNull);
        expect(emissions.last!.name, 'Laser Cutter');
        expect(emissions.last!.healthScore, 99.0);

        // Update document
        await machineService.updateMachineStatus(
          'MCH-STR',
          AppConstants.machineStatusWarning,
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last!.status, AppConstants.machineStatusWarning);

        // Delete document
        await machineService.deleteMachine('MCH-STR');

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last, isNull);

        await sub.cancel();
      });

      test(
        'streamMachines emits full and filtered lists in real time',
        () async {
          final stream = machineService.streamMachines(
            productionLine: 'Line 3',
          );
          final emissions = <List<MachineModel>>[];
          final sub = stream.listen(emissions.add);

          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(emissions.last, isEmpty);

          // Add machine in Line 1 (should NOT match filter)
          await machineService.addMachine(
            MachineModel(
              id: 'L1-01',
              name: 'Line 1 Machine',
              productionLine: 'Line 1',
              status: 'Operational',
              healthScore: 90,
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(emissions.last, isEmpty);

          // Add machine in Line 3 (should match filter)
          await machineService.addMachine(
            MachineModel(
              id: 'L3-01',
              name: 'Line 3 Machine',
              productionLine: 'Line 3',
              status: 'Operational',
              healthScore: 85,
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(emissions.last.length, 1);
          expect(emissions.last.first.id, 'L3-01');

          await sub.cancel();
        },
      );

      test('streamMachinesByLine emits filtered machines in real time', () async {
        final stream = machineService.streamMachinesByLine('Line 2');
        final emissions = <List<MachineModel>>[];
        final sub = stream.listen(emissions.add);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last, isEmpty);

        await machineService.addMachine(
          MachineModel(
            id: 'L2-STR',
            name: 'Line 2 Press',
            productionLine: 'Line 2',
            status: 'Operational',
            healthScore: 92,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last.length, 1);
        expect(emissions.last.first.id, 'L2-STR');

        await sub.cancel();
      });

      test('streamMachinesByStatus emits filtered machines in real time', () async {
        final stream = machineService.streamMachinesByStatus('Critical');
        final emissions = <List<MachineModel>>[];
        final sub = stream.listen(emissions.add);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last, isEmpty);

        await machineService.addMachine(
          MachineModel(
            id: 'CRIT-STR',
            name: 'Critical Robot',
            productionLine: 'Line 1',
            status: 'Critical',
            healthScore: 35,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(emissions.last.length, 1);
        expect(emissions.last.first.id, 'CRIT-STR');

        await sub.cancel();
      });
    });

    group('Firestore Exception Handling', () {
      test(
        'maps permission-denied FirebaseException to MachineServiceException',
        () async {
          final errorFirestore = FakeErrorFirestore(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
              message: 'Insufficient permissions',
            ),
          );
          final errorService = MachineService(firestore: errorFirestore);

          expect(
            () => errorService.getMachineById('MCH-ERR'),
            throwsA(
              isA<MachineServiceException>()
                  .having((e) => e.code, 'code', 'permission-denied')
                  .having(
                    (e) => e.message,
                    'message',
                    'You do not have permission to access or modify this machine.',
                  ),
            ),
          );
        },
      );

      test('getMachines maps permission-denied FirebaseException to MachineServiceException', () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Query not allowed',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          () => errorService.getMachines(),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'permission-denied'),
          ),
        );
      });

      test('getMachines maps unavailable FirebaseException to MachineServiceException', () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Network offline',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          () => errorService.getMachines(),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'unavailable'),
          ),
        );
      });

      test('streamMachine propagates permission-denied FirebaseException as MachineServiceException', () {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Read denied',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          errorService.streamMachine('MCH-ERR'),
          emitsError(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'permission-denied'),
          ),
        );
      });

      test('streamMachines propagates unavailable FirebaseException as MachineServiceException', () {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Backend down',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          errorService.streamMachines(),
          emitsError(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'unavailable'),
          ),
        );
      });

      test(
        'maps unavailable FirebaseException to MachineServiceException',
        () async {
          final errorFirestore = FakeErrorFirestore(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
              message: 'Network offline',
            ),
          );
          final errorService = MachineService(firestore: errorFirestore);

          expect(
            () => errorService.addMachine(
              MachineModel(
                id: 'MCH-NET',
                name: 'Offline Machine',
                productionLine: 'Line 1',
                status: 'Operational',
                healthScore: 100,
              ),
            ),
            throwsA(
              isA<MachineServiceException>()
                  .having((e) => e.code, 'code', 'unavailable')
                  .having(
                    (e) => e.message,
                    'message',
                    contains('network connection'),
                  ),
            ),
          );
        },
      );

      test(
        'maps deadline-exceeded FirebaseException to MachineServiceException',
        () async {
          final errorFirestore = FakeErrorFirestore(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'deadline-exceeded',
              message: 'Operation timed out',
            ),
          );
          final errorService = MachineService(firestore: errorFirestore);

          expect(
            () => errorService.deleteMachine('MCH-TO'),
            throwsA(
              isA<MachineServiceException>()
                  .having((e) => e.code, 'code', 'deadline-exceeded')
                  .having(
                    (e) => e.message,
                    'message',
                    'The operation timed out. Please try again.',
                  ),
            ),
          );
        },
      );

      test('addMachine maps permission-denied FirebaseException to MachineServiceException', () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Create denied',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          () => errorService.addMachine(
            MachineModel(
              id: 'MCH-DENIED',
              name: 'Denied Machine',
              productionLine: 'Line 1',
              status: 'Operational',
              healthScore: 90.0,
            ),
          ),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or modify this machine.',
                ),
          ),
        );
      });

      test('updateMachine maps permission-denied FirebaseException to MachineServiceException', () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Update denied',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          () => errorService.updateMachine('MCH-UPD', {'name': 'New Name'}),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or modify this machine.',
                ),
          ),
        );
      });

      test('deleteMachine maps permission-denied FirebaseException to MachineServiceException', () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
            message: 'Delete denied',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          () => errorService.deleteMachine('MCH-DEL'),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'permission-denied')
                .having(
                  (e) => e.message,
                  'message',
                  'You do not have permission to access or modify this machine.',
                ),
          ),
        );
      });

      test('updateMachine maps unavailable FirebaseException to MachineServiceException', () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Firestore down',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          () => errorService.updateMachine('MCH-UPD', {'name': 'New Name'}),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'unavailable')
                .having(
                  (e) => e.message,
                  'message',
                  contains('network connection'),
                ),
          ),
        );
      });

      test('deleteMachine maps unavailable FirebaseException to MachineServiceException', () async {
        final errorFirestore = FakeErrorFirestore(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Firestore down',
          ),
        );
        final errorService = MachineService(firestore: errorFirestore);

        expect(
          () => errorService.deleteMachine('MCH-DEL'),
          throwsA(
            isA<MachineServiceException>()
                .having((e) => e.code, 'code', 'unavailable')
                .having(
                  (e) => e.message,
                  'message',
                  contains('network connection'),
                ),
          ),
        );
      });

      test('MachineServiceException equality and toString', () {
        final ex1 = MachineServiceException(code: 'not-found');
        final ex2 = MachineServiceException(code: 'not-found');
        final ex3 = MachineServiceException(code: 'invalid-status');

        expect(ex1, equals(ex2));
        expect(ex1.hashCode, equals(ex2.hashCode));
        expect(ex1, isNot(equals(ex3)));
        expect(ex1.toString(), contains('not-found'));
      });
    });
  });
}
