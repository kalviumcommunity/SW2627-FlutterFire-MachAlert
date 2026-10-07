import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/user_model.dart';

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
      expect(user.createdAt?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
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

    test('toMap returns expected values', () {
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

    test('fromMap recreates model correctly with assignedAt/resolvedAt fallback', () {
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
    });

    test('copyWith works as expected', () {
      final maintenance = MaintenanceModel(
        id: 'mnt1',
        machineId: 'm1',
        technicianId: 'tech1',
        priority: 'Low',
        status: 'Pending',
      );

      final updated = maintenance.copyWith(status: 'Resolved', notes: 'Completed');
      expect(updated.status, 'Resolved');
      expect(updated.notes, 'Completed');
      expect(updated.id, 'mnt1');
    });
  });
}
