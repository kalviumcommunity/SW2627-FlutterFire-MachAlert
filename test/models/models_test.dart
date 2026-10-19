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

    test('can be created successfully with default status', () {
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
