import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/utils/app_constants.dart';

void main() {
  group('UserModel Tests', () {
    final now = DateTime(2026, 10, 7, 10, 30);

    test('can be created successfully', () {
      final user = UserModel(
        id: 'u123',
        name: 'Jane Doe',
        email: 'jane@factory.com',
        role: 'operator',
        createdAt: now,
      );

      expect(user.id, 'u123');
      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@factory.com');
      expect(user.role, 'operator');
      expect(user.createdAt, now);
    });

    test('toMap returns expected values', () {
      final user = UserModel(
        id: 'u123',
        name: 'Jane Doe',
        email: 'jane@factory.com',
        role: 'operator',
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['id'], 'u123');
      expect(map['name'], 'Jane Doe');
      expect(map['email'], 'jane@factory.com');
      expect(map['role'], 'operator');
      expect(map['createdAt'], now.toIso8601String());
    });

    test('fromMap recreates model correctly with id and ISO timestamp', () {
      final map = {
        'id': 'u123',
        'name': 'Jane Doe',
        'email': 'jane@factory.com',
        'role': 'operator',
        'createdAt': now.toIso8601String(),
      };

      final user = UserModel.fromMap(map);
      expect(user.id, 'u123');
      expect(user.name, 'Jane Doe');
      expect(user.email, 'jane@factory.com');
      expect(user.role, 'operator');
      expect(user.createdAt, now);
    });

    test('fromMap handles docId and userId fallback and epoch millis', () {
      final map = {
        'userId': 'u999',
        'name': 'Bob Smith',
        'email': 'bob@factory.com',
        'role': 'technician',
        'createdAt': now.millisecondsSinceEpoch,
      };

      final user = UserModel.fromMap(map, 'doc_override');
      expect(user.id, 'doc_override');
      expect(user.name, 'Bob Smith');
      expect(user.email, 'bob@factory.com');
      expect(user.role, 'technician');
      expect(
        user.createdAt?.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
    });

    test('copyWith works as expected', () {
      final user = UserModel(
        id: 'u123',
        name: 'Jane Doe',
        email: 'jane@factory.com',
        role: 'operator',
      );

      final updated = user.copyWith(role: 'manager');
      expect(updated.id, 'u123');
      expect(updated.role, 'manager');
      expect(updated.name, 'Jane Doe');
    });

    test('convenience getters uid and displayName match id and name', () {
      final user = UserModel(
        id: 'user_xyz',
        name: 'Alice Johnson',
        email: 'alice@factory.com',
        role: 'technician',
      );

      expect(user.uid, 'user_xyz');
      expect(user.displayName, 'Alice Johnson');
    });

    test('updatedAt is serialized and deserialized correctly', () {
      final updated = DateTime(2026, 10, 8, 14, 0);
      final user = UserModel(
        id: 'u456',
        name: 'Mark Davis',
        email: 'mark@factory.com',
        role: 'operator',
        createdAt: now,
        updatedAt: updated,
      );

      final map = user.toMap();
      expect(map['updatedAt'], updated.toIso8601String());

      final reconstituted = UserModel.fromMap(map);
      expect(reconstituted.updatedAt, updated);
    });

    test('hasRecognizedRole returns true only for valid roles', () {
      expect(
        UserModel(
          id: '1',
          name: 'A',
          email: 'a@a.com',
          role: 'operator',
        ).hasRecognizedRole,
        isTrue,
      );
      expect(
        UserModel(
          id: '2',
          name: 'B',
          email: 'b@b.com',
          role: 'technician',
        ).hasRecognizedRole,
        isTrue,
      );
      expect(
        UserModel(
          id: '3',
          name: 'C',
          email: 'c@c.com',
          role: 'manager',
        ).hasRecognizedRole,
        isTrue,
      );
      expect(
        UserModel(
          id: '4',
          name: 'D',
          email: 'd@d.com',
          role: 'admin',
        ).hasRecognizedRole,
        isFalse,
      );
      expect(
        UserModel(
          id: '5',
          name: 'E',
          email: 'e@e.com',
          role: '',
        ).hasRecognizedRole,
        isFalse,
      );
    });

    test('toFirestoreMap generates expected schema with both keys', () {
      final user = UserModel(
        id: 'u789',
        name: 'Sara Connor',
        email: 'sara@factory.com',
        role: 'manager',
        createdAt: now,
      );

      final firestoreMap = user.toFirestoreMap();
      expect(firestoreMap['uid'], 'u789');
      expect(firestoreMap['userId'], 'u789');
      expect(firestoreMap['name'], 'Sara Connor');
      expect(firestoreMap['displayName'], 'Sara Connor');
      expect(firestoreMap['email'], 'sara@factory.com');
      expect(firestoreMap['role'], 'manager');
      expect(firestoreMap['createdAt'], isNotNull);
    });

    test('fromMap parses uid and displayName fallback keys', () {
      final map = {
        'uid': 'uid_fallback',
        'displayName': 'Fallback Name',
        'email': 'fallback@factory.com',
        'role': 'technician',
      };

      final user = UserModel.fromMap(map);
      expect(user.id, 'uid_fallback');
      expect(user.name, 'Fallback Name');
      expect(user.email, 'fallback@factory.com');
      expect(user.role, 'technician');
    });
  });

  group('MachineModel Tests', () {
    final inspectionDate = DateTime(2026, 10, 1, 9, 0);
    final createdDate = DateTime(2026, 10, 2, 8, 0);
    final updatedDate = DateTime(2026, 10, 7, 12, 0);

    test('can be created successfully', () {
      final machine = MachineModel(
        id: 'm1',
        name: 'CNC Milling Machine',
        productionLine: 'Line 1',
        modelNumber: 'Haas VF-2SS',
        status: 'Operational',
        healthScore: 95.0,
        temperature: 65.5,
        vibration: 2.1,
        lastInspection: inspectionDate,
        createdAt: createdDate,
        updatedAt: updatedDate,
      );

      expect(machine.id, 'm1');
      expect(machine.name, 'CNC Milling Machine');
      expect(machine.productionLine, 'Line 1');
      expect(machine.modelNumber, 'Haas VF-2SS');
      expect(machine.status, 'Operational');
      expect(machine.healthScore, 95.0);
      expect(machine.temperature, 65.5);
      expect(machine.vibration, 2.1);
      expect(machine.lastInspection, inspectionDate);
    });

    test('canonical machineId getter matches id', () {
      final machine = MachineModel(
        id: 'MCH-LINE1-CNC01',
        name: 'CNC Machine',
        productionLine: 'Line 1',
        status: 'Operational',
        healthScore: 100,
      );

      expect(machine.machineId, 'MCH-LINE1-CNC01');
      expect(machine.machineId, machine.id);
    });

    test('toMap returns expected values with both id and machineId', () {
      final machine = MachineModel(
        id: 'm1',
        name: 'CNC Milling Machine',
        productionLine: 'Line 1',
        modelNumber: 'Haas VF-2SS',
        status: 'Operational',
        healthScore: 95.0,
        temperature: 65.5,
        vibration: 2.1,
        lastInspection: inspectionDate,
        createdAt: createdDate,
        updatedAt: updatedDate,
      );

      final map = machine.toMap();
      expect(map['id'], 'm1');
      expect(map['machineId'], 'm1');
      expect(map['name'], 'CNC Milling Machine');
      expect(map['productionLine'], 'Line 1');
      expect(map['modelNumber'], 'Haas VF-2SS');
      expect(map['status'], 'Operational');
      expect(map['healthScore'], 95.0);
      expect(map['temperature'], 65.5);
      expect(map['vibration'], 2.1);
      expect(map['lastInspection'], inspectionDate.toIso8601String());
      expect(map['createdAt'], createdDate.toIso8601String());
      expect(map['updatedAt'], updatedDate.toIso8601String());
    });

    test('toFirestoreMap generates expected map with Timestamps for creation', () {
      final machine = MachineModel(
        id: 'm1',
        name: 'CNC Milling Machine',
        productionLine: 'Line 1',
        modelNumber: 'Haas VF-2SS',
        status: 'Operational',
        healthScore: 95.0,
        temperature: 65.5,
        vibration: 2.1,
        lastInspection: inspectionDate,
        createdAt: createdDate,
        updatedAt: updatedDate,
      );

      final firestoreMap = machine.toFirestoreMap(isUpdate: false);
      expect(firestoreMap['id'], 'm1');
      expect(firestoreMap['machineId'], 'm1');
      expect(firestoreMap['name'], 'CNC Milling Machine');
      expect(firestoreMap['productionLine'], 'Line 1');
      expect(firestoreMap['modelNumber'], 'Haas VF-2SS');
      expect(firestoreMap['status'], 'Operational');
      expect(firestoreMap['healthScore'], 95.0);
      expect(firestoreMap['temperature'], 65.5);
      expect(firestoreMap['vibration'], 2.1);
      expect(firestoreMap['lastInspection'], Timestamp.fromDate(inspectionDate));
      expect(firestoreMap['createdAt'], Timestamp.fromDate(createdDate));
      expect(firestoreMap['updatedAt'], Timestamp.fromDate(updatedDate));
    });

    test('toFirestoreMap with isUpdate: true omits createdAt and uses FieldValue fallbacks', () {
      final machine = MachineModel(
        id: 'm2',
        name: 'Drill Press',
        productionLine: 'Line 2',
        status: 'Warning',
        healthScore: 75.0,
      );

      final updateMap = machine.toFirestoreMap(isUpdate: true);
      expect(updateMap['id'], 'm2');
      expect(updateMap['machineId'], 'm2');
      expect(updateMap.containsKey('createdAt'), isFalse);
      expect(updateMap['updatedAt'], isA<FieldValue>());
      expect(updateMap['lastInspection'], isNull);
    });

    test('fromFirestore reconstructs model correctly from DocumentSnapshot', () async {
      final fakeDb = FakeFirebaseFirestore();
      await fakeDb.collection('machines').doc('MCH-SNAP-01').set({
        'id': 'MCH-SNAP-01',
        'machineId': 'MCH-SNAP-01',
        'name': 'Stamping Press',
        'productionLine': 'Line 2',
        'modelNumber': 'Komatsu 200T',
        'status': 'Operational',
        'healthScore': 89,
        'temperature': 71.2,
        'vibration': 3.4,
        'lastInspection': Timestamp.fromDate(inspectionDate),
        'createdAt': Timestamp.fromDate(createdDate),
        'updatedAt': Timestamp.fromDate(updatedDate),
      });

      final snapshot = await fakeDb.collection('machines').doc('MCH-SNAP-01').get();
      final machine = MachineModel.fromFirestore(snapshot);

      expect(machine.id, 'MCH-SNAP-01');
      expect(machine.machineId, 'MCH-SNAP-01');
      expect(machine.name, 'Stamping Press');
      expect(machine.productionLine, 'Line 2');
      expect(machine.modelNumber, 'Komatsu 200T');
      expect(machine.status, 'Operational');
      expect(machine.healthScore, 89.0);
      expect(machine.temperature, 71.2);
      expect(machine.vibration, 3.4);
      expect(machine.lastInspection, inspectionDate);
      expect(machine.createdAt, createdDate);
      expect(machine.updatedAt, updatedDate);
    });

    test('fromMap recreates model correctly with type casting for numbers', () {
      final map = {
        'machineId': 'm1',
        'name': 'CNC Milling Machine',
        'productionLine': 'Line 1',
        'modelNumber': 'Haas VF-2SS',
        'status': 'Operational',
        'healthScore': 95, // integer in json/map
        'temperature': 65, // integer in json/map
        'vibration': 2.1,
        'lastInspection': inspectionDate.toIso8601String(),
        'createdAt': createdDate.toIso8601String(),
        'updatedAt': updatedDate.toIso8601String(),
      };

      final machine = MachineModel.fromMap(map);
      expect(machine.id, 'm1');
      expect(machine.name, 'CNC Milling Machine');
      expect(machine.healthScore, 95.0);
      expect(machine.temperature, 65.0);
      expect(machine.vibration, 2.1);
      expect(machine.lastInspection, inspectionDate);
    });

    test('fromMap parses numeric strings and handles invalid numbers safely', () {
      final map = {
        'id': 'm3',
        'name': 'Lathe Machine',
        'productionLine': 'Line 3',
        'status': 'Critical',
        'healthScore': '85.5',
        'temperature': '92.3',
        'vibration': ' 14.7 ',
      };

      final machine = MachineModel.fromMap(map);
      expect(machine.healthScore, 85.5);
      expect(machine.temperature, 92.3);
      expect(machine.vibration, 14.7);

      final invalidMap = {
        'id': 'm4',
        'name': 'Faulty Machine',
        'productionLine': 'Line 1',
        'status': 'Warning',
        'healthScore': 'not-a-number',
        'temperature': 'invalid_temp',
        'vibration': '',
      };

      final safeMachine = MachineModel.fromMap(invalidMap);
      expect(safeMachine.healthScore, 0.0);
      expect(safeMachine.temperature, isNull);
      expect(safeMachine.vibration, isNull);
    });

    test('fromMap parses Firestore Timestamp, epoch millis, and handles invalid dates safely', () {
      final map = {
        'id': 'm5',
        'name': 'Packaging Arm',
        'productionLine': 'Line 1',
        'status': 'Operational',
        'healthScore': 100,
        'lastInspection': Timestamp.fromDate(inspectionDate),
        'createdAt': createdDate.millisecondsSinceEpoch,
        'updatedAt': 'not-a-valid-date',
      };

      final machine = MachineModel.fromMap(map);
      expect(machine.lastInspection, inspectionDate);
      expect(machine.createdAt?.millisecondsSinceEpoch, createdDate.millisecondsSinceEpoch);
      expect(machine.updatedAt, isNull);
    });

    test('fromMap resolves id with correct precedence (docId > id > machineId)', () {
      // 1. docId takes precedence over map keys
      final m1 = MachineModel.fromMap({'id': 'map_id', 'machineId': 'map_machine_id'}, 'doc_override');
      expect(m1.id, 'doc_override');

      // 2. map['id'] takes precedence over map['machineId']
      final m2 = MachineModel.fromMap({'id': 'map_id', 'machineId': 'map_machine_id'});
      expect(m2.id, 'map_id');

      // 3. map['machineId'] is used when map['id'] is absent or empty
      final m3 = MachineModel.fromMap({'id': '  ', 'machineId': 'map_machine_id'});
      expect(m3.id, 'map_machine_id');

      // 4. Default to empty string when neither is present
      final m4 = MachineModel.fromMap({});
      expect(m4.id, '');
    });

    test('round-trip serialization toMap and fromMap preserves model data', () {
      final machine = MachineModel(
        id: 'MCH-RT-01',
        name: 'Injection Molder',
        productionLine: 'Line 2',
        modelNumber: 'Engel Victory',
        status: 'Operational',
        healthScore: 97.0,
        temperature: 55.4,
        vibration: 1.8,
        lastInspection: DateTime(2026, 10, 10, 14, 30),
        createdAt: DateTime(2026, 10, 1, 8, 0),
        updatedAt: DateTime(2026, 10, 12, 10, 0),
      );

      final map = machine.toMap();
      final recreated = MachineModel.fromMap(map);

      expect(recreated, equals(machine));
      expect(recreated.machineId, machine.machineId);
    });

    test('status helper getters and hasRecognizedStatus behave correctly', () {
      final operational = MachineModel(
        id: '1',
        name: 'M1',
        productionLine: 'L1',
        status: AppConstants.machineStatusOperational,
        healthScore: 100,
      );
      expect(operational.isOperational, isTrue);
      expect(operational.isWarning, isFalse);
      expect(operational.isCritical, isFalse);
      expect(operational.isUnderMaintenance, isFalse);
      expect(operational.hasRecognizedStatus, isTrue);

      final warning = MachineModel(
        id: '2',
        name: 'M2',
        productionLine: 'L1',
        status: 'warning',
        healthScore: 70,
      );
      expect(warning.isWarning, isTrue);
      expect(warning.hasRecognizedStatus, isTrue);

      final critical = MachineModel(
        id: '3',
        name: 'M3',
        productionLine: 'L1',
        status: 'Critical',
        healthScore: 40,
      );
      expect(critical.isCritical, isTrue);
      expect(critical.hasRecognizedStatus, isTrue);

      final maintenance = MachineModel(
        id: '4',
        name: 'M4',
        productionLine: 'L1',
        status: 'Under Maintenance',
        healthScore: 60,
      );
      expect(maintenance.isUnderMaintenance, isTrue);
      expect(maintenance.hasRecognizedStatus, isTrue);

      final unknown = MachineModel(
        id: '5',
        name: 'M5',
        productionLine: 'L1',
        status: 'Decommissioned',
        healthScore: 0,
      );
      expect(unknown.hasRecognizedStatus, isFalse);
    });

    test('copyWith works as expected', () {
      final machine = MachineModel(
        id: 'm1',
        name: 'CNC Machine',
        productionLine: 'Line 1',
        status: 'Operational',
        healthScore: 90.0,
      );

      final updated = machine.copyWith(status: 'Warning', healthScore: 72.0);
      expect(updated.status, 'Warning');
      expect(updated.healthScore, 72.0);
      expect(updated.name, 'CNC Machine');
    });
  });

  group('FaultModel Tests', () {
    final now = DateTime(2026, 10, 7, 11, 15);

    test('can be created successfully with default status and faultId alias', () {
      final fault = FaultModel(
        id: 'f100',
        machineId: 'm1',
        machineName: 'CNC 01',
        type: 'Thermal',
        severity: 'High',
        description: 'Spindle overheating',
        reportedBy: 'u1',
        reportedByName: 'John',
        createdAt: now,
      );

      expect(fault.id, 'f100');
      expect(fault.faultId, 'f100');
      expect(fault.machineId, 'm1');
      expect(fault.machineName, 'CNC 01');
      expect(fault.status, 'Open');
      expect(fault.severity, 'High');
    });

    test('toMap returns expected values', () {
      final fault = FaultModel(
        id: 'f100',
        machineId: 'm1',
        machineName: 'CNC 01',
        type: 'Thermal',
        severity: 'High',
        description: 'Spindle overheating',
        reportedBy: 'u1',
        reportedByName: 'John',
        status: 'In Progress',
        imageUrl: 'https://example.com/img.jpg',
        createdAt: now,
      );

      final map = fault.toMap();
      expect(map['id'], 'f100');
      expect(map['faultId'], 'f100');
      expect(map['machineId'], 'm1');
      expect(map['machineName'], 'CNC 01');
      expect(map['type'], 'Thermal');
      expect(map['severity'], 'High');
      expect(map['description'], 'Spindle overheating');
      expect(map['reportedBy'], 'u1');
      expect(map['reportedByName'], 'John');
      expect(map['status'], 'In Progress');
      expect(map['imageUrl'], 'https://example.com/img.jpg');
      expect(map['createdAt'], now.toIso8601String());
    });

    test('fromMap recreates model correctly', () {
      final map = {
        'faultId': 'f100',
        'machineId': 'm1',
        'machineName': 'CNC 01',
        'type': 'Thermal',
        'severity': 'High',
        'description': 'Spindle overheating',
        'reportedBy': 'u1',
        'reportedByName': 'John',
        'status': 'Resolved',
        'imageUrl': 'https://example.com/img.jpg',
        'createdAt': now.toIso8601String(),
      };

      final fault = FaultModel.fromMap(map);
      expect(fault.id, 'f100');
      expect(fault.faultId, 'f100');
      expect(fault.machineId, 'm1');
      expect(fault.machineName, 'CNC 01');
      expect(fault.type, 'Thermal');
      expect(fault.status, 'Resolved');
      expect(fault.createdAt, now);
    });

    test('copyWith works as expected', () {
      final fault = FaultModel(
        id: 'f100',
        machineId: 'm1',
        type: 'Thermal',
        severity: 'High',
        description: 'Overheating',
        reportedBy: 'u1',
      );

      final updated = fault.copyWith(status: 'Resolved');
      expect(updated.status, 'Resolved');
      expect(updated.id, 'f100');
    });

    group('Document ID fallback precedence', () {
      test('supplied docId takes priority over map faultId and id', () {
        final fault = FaultModel.fromMap(
          {'faultId': 'map_fault_id', 'id': 'map_id'},
          'param_doc_id',
        );
        expect(fault.id, 'param_doc_id');
        expect(fault.faultId, 'param_doc_id');
      });

      test('map faultId takes precedence over id when docId is omitted', () {
        final fault = FaultModel.fromMap(
          {'faultId': 'map_fault_id', 'id': 'map_id'},
        );
        expect(fault.id, 'map_fault_id');
      });

      test('map id is used when faultId is missing or empty', () {
        final fault = FaultModel.fromMap(
          {'id': 'map_id'},
        );
        expect(fault.id, 'map_id');

        final faultWithEmptyFaultId = FaultModel.fromMap(
          {'faultId': '', 'id': 'map_id_2'},
        );
        expect(faultWithEmptyFaultId.id, 'map_id_2');
      });

      test('empty string fallback when no id is present', () {
        final fault = FaultModel.fromMap({});
        expect(fault.id, '');
      });
    });

    group('Convenience getters and recognized values', () {
      test('recognized value getters identify all valid AppConstants.faultTypes', () {
        for (final validCategory in AppConstants.faultTypes) {
          final fault = FaultModel(
            id: 'f1',
            machineId: 'm1',
            type: validCategory,
            severity: AppConstants.severityCritical,
            description: 'Issue detected',
            reportedBy: 'u1',
            status: AppConstants.faultStatusOpen,
          );

          expect(
            fault.hasRecognizedType,
            isTrue,
            reason: 'Category "$validCategory" must be recognized as in AppConstants.faultTypes',
          );
        }
      });

      test('unsupported types like Sensor and Software return false for hasRecognizedType', () {
        final unsupportedTypes = [
          'Sensor',
          'Software',
          'SoftwareBug',
          'AlienInvasion',
          'Hardware',
          'Network',
        ];
        for (final unsupp in unsupportedTypes) {
          final fault = FaultModel(
            id: 'f2',
            machineId: 'm1',
            type: unsupp,
            severity: 'Low',
            description: 'Issue description',
            reportedBy: 'u1',
            status: 'Open',
          );

          expect(
            fault.hasRecognizedType,
            isFalse,
            reason: 'Type "$unsupp" must not be recognized since it is not in AppConstants.faultTypes',
          );
        }
      });

      test('recognized value getters identify valid constants', () {
        final validFault = FaultModel(
          id: 'f1',
          machineId: 'm1',
          type: AppConstants.faultTypeElectrical,
          severity: AppConstants.severityCritical,
          description: 'Arc flash detected',
          reportedBy: 'u1',
          status: AppConstants.faultStatusOpen,
        );

        expect(validFault.hasRecognizedType, isTrue);
        expect(validFault.hasRecognizedSeverity, isTrue);
        expect(validFault.hasRecognizedStatus, isTrue);
        expect(validFault.isCriticalSeverity, isTrue);
        expect(validFault.isOpen, isTrue);
        expect(validFault.isInProgress, isFalse);
        expect(validFault.isResolved, isFalse);
      });

      test('unrecognized values return false for recognition getters', () {
        final weirdFault = FaultModel(
          id: 'f2',
          machineId: 'm1',
          type: 'AlienInvasion',
          severity: 'SuperExtreme',
          description: 'Strange behavior',
          reportedBy: 'u1',
          status: 'UnknownStatus',
        );

        expect(weirdFault.hasRecognizedType, isFalse);
        expect(weirdFault.hasRecognizedSeverity, isFalse);
        expect(weirdFault.hasRecognizedStatus, isFalse);
        expect(weirdFault.isCriticalSeverity, isFalse);
        expect(weirdFault.isOpen, isFalse);
        expect(weirdFault.isInProgress, isFalse);
        expect(weirdFault.isResolved, isFalse);
      });

      test('status and severity helpers identify In Progress, Resolved, and High', () {
        final inProgressFault = FaultModel(
          id: 'f3',
          machineId: 'm1',
          type: 'Mechanical',
          severity: 'High',
          description: 'Bearing play',
          reportedBy: 'u1',
          status: 'In Progress',
        );

        expect(inProgressFault.isInProgress, isTrue);
        expect(inProgressFault.isOpen, isFalse);
        expect(inProgressFault.isResolved, isFalse);
        expect(inProgressFault.isHighSeverity, isTrue);
        expect(inProgressFault.isCriticalSeverity, isFalse);

        final resolvedFault = inProgressFault.copyWith(status: 'Resolved');
        expect(resolvedFault.isResolved, isTrue);
        expect(resolvedFault.isInProgress, isFalse);
      });
    });

    group('validate() and isValid functionality', () {
      test('valid model passes validation with zero errors', () {
        final validFault = FaultModel(
          id: 'f1',
          machineId: 'MCH-01',
          type: 'Mechanical',
          severity: 'Low',
          description: 'Minor vibration on motor mount',
          reportedBy: 'u100',
          status: 'Open',
        );

        expect(validFault.validate(), isEmpty);
        expect(validFault.isValid, isTrue);
      });

      test('collects validation errors for empty required fields', () {
        final emptyFault = FaultModel(
          id: 'f2',
          machineId: '   ',
          type: '',
          severity: ' ',
          description: '',
          reportedBy: '',
          status: ' ',
        );

        final errors = emptyFault.validate();
        expect(errors, contains('Machine ID is required.'));
        expect(errors, contains('Fault type is required.'));
        expect(errors, contains('Severity is required.'));
        expect(errors, contains('Description is required.'));
        expect(errors, contains('Reporter UID is required.'));
        expect(errors, contains('Status is required.'));
        expect(emptyFault.isValid, isFalse);
      });

      test('collects validation errors for invalid enum values', () {
        final invalidEnumFault = FaultModel(
          id: 'f3',
          machineId: 'MCH-01',
          type: 'Nuclear',
          severity: 'Catastrophic',
          description: 'Reactor leaking',
          reportedBy: 'u100',
          status: 'Archived',
        );

        final errors = invalidEnumFault.validate();
        expect(errors.any((e) => e.contains('Fault type "Nuclear" is invalid')), isTrue);
        expect(errors.any((e) => e.contains('Severity "Catastrophic" is invalid')), isTrue);
        expect(errors.any((e) => e.contains('Status "Archived" is invalid')), isTrue);
        expect(invalidEnumFault.isValid, isFalse);
      });

      test('rejects unsupported types like Sensor and Software in validate()', () {
        final sensorFault = FaultModel(
          id: 'f_sensor',
          machineId: 'MCH-01',
          type: 'Sensor',
          severity: 'Low',
          description: 'Sensor failure on temperature probe',
          reportedBy: 'u100',
          status: 'Open',
        );
        expect(sensorFault.isValid, isFalse);
        expect(
          sensorFault.validate(),
          contains(
            'Fault type "Sensor" is invalid. Allowed types: Mechanical, Electrical, Hydraulic, Thermal, Pneumatic, Other.',
          ),
        );

        final softwareFault = FaultModel(
          id: 'f_software',
          machineId: 'MCH-01',
          type: 'Software',
          severity: 'Medium',
          description: 'PLC firmware threw error code 404',
          reportedBy: 'u100',
          status: 'Open',
        );
        expect(softwareFault.isValid, isFalse);
        expect(
          softwareFault.validate(),
          contains(
            'Fault type "Software" is invalid. Allowed types: Mechanical, Electrical, Hydraulic, Thermal, Pneumatic, Other.',
          ),
        );
      });
    });

    group('Date and Timestamp parsing from various sources', () {
      test('parses Cloud Firestore Timestamp instance', () {
        final timestamp = Timestamp.fromDate(now);
        final fault = FaultModel.fromMap({
          'machineId': 'm1',
          'type': 'Thermal',
          'severity': 'High',
          'description': 'Overheating',
          'reportedBy': 'u1',
          'createdAt': timestamp,
        });

        expect(fault.createdAt, now);
      });

      test('parses epoch millisecond integer', () {
        final epochMs = now.millisecondsSinceEpoch;
        final fault = FaultModel.fromMap({
          'machineId': 'm1',
          'type': 'Thermal',
          'severity': 'High',
          'description': 'Overheating',
          'reportedBy': 'u1',
          'createdAt': epochMs,
        });

        expect(fault.createdAt, now);
      });

      test('handles null and invalid date values gracefully', () {
        final faultNull = FaultModel.fromMap({
          'machineId': 'm1',
          'createdAt': null,
        });
        expect(faultNull.createdAt, isNull);

        final faultInvalid = FaultModel.fromMap({
          'machineId': 'm1',
          'createdAt': 'not-a-valid-date-string',
        });
        expect(faultInvalid.createdAt, isNull);
      });
    });

    group('toFirestoreMap behavior', () {
      test('creates map with Timestamp when createdAt is present on create', () {
        final fault = FaultModel(
          id: 'f10',
          machineId: 'm1',
          machineName: 'CNC',
          type: 'Thermal',
          severity: 'High',
          description: 'Spindle heat',
          reportedBy: 'u1',
          createdAt: now,
        );

        final firestoreMap = fault.toFirestoreMap(isUpdate: false);
        expect(firestoreMap['id'], 'f10');
        expect(firestoreMap['faultId'], 'f10');
        expect(firestoreMap['machineId'], 'm1');
        expect(firestoreMap['createdAt'], isA<Timestamp>());
        expect((firestoreMap['createdAt'] as Timestamp).toDate(), now);
      });

      test('creates map with FieldValue.serverTimestamp when createdAt is null on create', () {
        final fault = FaultModel(
          id: 'f11',
          machineId: 'm1',
          type: 'Thermal',
          severity: 'High',
          description: 'Spindle heat',
          reportedBy: 'u1',
          createdAt: null,
        );

        final firestoreMap = fault.toFirestoreMap(isUpdate: false);
        expect(firestoreMap['createdAt'], isA<FieldValue>());
      });

      test('omits createdAt on update to prevent overwriting original creation time', () {
        final fault = FaultModel(
          id: 'f12',
          machineId: 'm1',
          machineName: 'Milling Station',
          type: 'Hydraulic',
          severity: 'High',
          description: 'Updated description',
          reportedBy: 'u1',
          reportedByName: 'Jane Doe',
          status: 'In Progress',
          imageUrl: 'https://example.com/leak.jpg',
          createdAt: now,
        );

        final updateMap = fault.toFirestoreMap(isUpdate: true);
        expect(updateMap.containsKey('createdAt'), isFalse);
        expect(updateMap['id'], 'f12');
        expect(updateMap['faultId'], 'f12');
        expect(updateMap['machineId'], 'm1');
        expect(updateMap['machineName'], 'Milling Station');
        expect(updateMap['type'], 'Hydraulic');
        expect(updateMap['severity'], 'High');
        expect(updateMap['description'], 'Updated description');
        expect(updateMap['reportedBy'], 'u1');
        expect(updateMap['reportedByName'], 'Jane Doe');
        expect(updateMap['status'], 'In Progress');
        expect(updateMap['imageUrl'], 'https://example.com/leak.jpg');
      });
    });

    group('Equality, hashCode, and toString', () {
      test('equal instances have identical hashCode and evaluate as equal', () {
        final fault1 = FaultModel(
          id: 'f1',
          machineId: 'm1',
          type: 'Thermal',
          severity: 'High',
          description: 'Heat',
          reportedBy: 'u1',
          createdAt: now,
        );
        final fault2 = FaultModel(
          id: 'f1',
          machineId: 'm1',
          type: 'Thermal',
          severity: 'High',
          description: 'Heat',
          reportedBy: 'u1',
          createdAt: now,
        );

        expect(fault1, equals(fault2));
        expect(fault1.hashCode, equals(fault2.hashCode));
        expect(fault1.toString(), contains('FaultModel('));
        expect(fault1.toString(), contains('machineId: m1'));
      });

      test('instances with same moment in different timezones evaluate as equal', () {
        final localDate = DateTime(2026, 10, 7, 11, 15);
        final utcDate = localDate.toUtc();

        final fault1 = FaultModel(
          id: 'f1',
          machineId: 'm1',
          type: 'Thermal',
          severity: 'High',
          description: 'Heat',
          reportedBy: 'u1',
          createdAt: localDate,
        );
        final fault2 = fault1.copyWith(createdAt: utcDate);

        expect(fault1, equals(fault2));
        expect(fault1.hashCode, equals(fault2.hashCode));
      });

      test('different instances evaluate as not equal', () {
        final base = FaultModel(
          id: 'f1',
          machineId: 'm1',
          type: 'Thermal',
          severity: 'High',
          description: 'Heat',
          reportedBy: 'u1',
        );

        expect(base == base.copyWith(id: 'f2'), isFalse);
        expect(base == base.copyWith(machineId: 'm2'), isFalse);
        expect(base == base.copyWith(type: 'Electrical'), isFalse);
        expect(base == base.copyWith(severity: 'Low'), isFalse);
        expect(base == base.copyWith(description: 'Other'), isFalse);
        expect(base == base.copyWith(reportedBy: 'u2'), isFalse);
        expect(base == base.copyWith(status: 'Resolved'), isFalse);
      });
    });
  });

  group('MaintenanceModel Tests', () {
    final now = DateTime(2026, 10, 7, 12, 0);
    final resolvedAt = DateTime(2026, 10, 7, 14, 0);

    test('can be created successfully', () {
      final maintenance = MaintenanceModel(
        id: 'mnt1',
        machineId: 'm1',
        machineName: 'CNC 01',
        faultId: 'f100',
        technicianId: 'tech1',
        technicianName: 'Alex',
        priority: 'High',
        status: 'Pending',
        notes: 'Check spindle coolant',
        createdAt: now,
        updatedAt: resolvedAt,
      );

      expect(maintenance.id, 'mnt1');
      expect(maintenance.machineId, 'm1');
      expect(maintenance.technicianId, 'tech1');
      expect(maintenance.priority, 'High');
      expect(maintenance.status, 'Pending');
    });

    test('toMap returns expected values', () {
      final maintenance = MaintenanceModel(
        id: 'mnt1',
        machineId: 'm1',
        machineName: 'CNC 01',
        faultId: 'f100',
        technicianId: 'tech1',
        technicianName: 'Alex',
        priority: 'High',
        status: 'In Progress',
        notes: 'Checking coolant lines',
        createdAt: now,
        updatedAt: resolvedAt,
      );

      final map = maintenance.toMap();
      expect(map['id'], 'mnt1');
      expect(map['machineId'], 'm1');
      expect(map['machineName'], 'CNC 01');
      expect(map['faultId'], 'f100');
      expect(map['technicianId'], 'tech1');
      expect(map['technicianName'], 'Alex');
      expect(map['priority'], 'High');
      expect(map['status'], 'In Progress');
      expect(map['notes'], 'Checking coolant lines');
      expect(map['createdAt'], now.toIso8601String());
      expect(map['updatedAt'], resolvedAt.toIso8601String());
    });

    test(
      'fromMap recreates model correctly with assignedAt/resolvedAt fallback',
      () {
        final map = {
          'maintenanceId': 'mnt1',
          'machineId': 'm1',
          'technicianId': 'tech1',
          'priority': 'Critical',
          'status': 'Resolved',
          'assignedAt': now.toIso8601String(),
          'resolvedAt': resolvedAt.toIso8601String(),
        };

        final maintenance = MaintenanceModel.fromMap(map);
        expect(maintenance.id, 'mnt1');
        expect(maintenance.priority, 'Critical');
        expect(maintenance.status, 'Resolved');
        expect(maintenance.createdAt, now);
        expect(maintenance.updatedAt, resolvedAt);
      },
    );

    test('copyWith works as expected', () {
      final maintenance = MaintenanceModel(
        id: 'mnt1',
        machineId: 'm1',
        technicianId: 'tech1',
        priority: 'Low',
        status: 'Pending',
      );

      final updated = maintenance.copyWith(
        status: 'Resolved',
        notes: 'Completed',
      );
      expect(updated.status, 'Resolved');
      expect(updated.notes, 'Completed');
      expect(updated.id, 'mnt1');
    });
  });
}
