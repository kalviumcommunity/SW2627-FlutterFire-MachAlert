import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_activity_log_model.dart';
import 'package:mach_alert/models/maintenance_model.dart';
import 'package:mach_alert/models/maintenance_update_model.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/machine_activity_service.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

class _MockFaultService extends Fake implements FaultService {
  final List<FaultModel> faultsToReturn;
  final StreamController<List<FaultModel>> _controller =
      StreamController<List<FaultModel>>.broadcast();

  _MockFaultService({this.faultsToReturn = const []});

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) async {
    return faultsToReturn;
  }

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) {
    // If controller already has listeners, emit immediately
    Future.microtask(() {
      if (!_controller.isClosed) {
        _controller.add(faultsToReturn);
      }
    });
    return _controller.stream;
  }

  void emit(List<FaultModel> faults) {
    if (!_controller.isClosed) _controller.add(faults);
  }

  void emitError(Object error) {
    if (!_controller.isClosed) _controller.addError(error);
  }

  void dispose() => _controller.close();
}

class _MockMaintenanceService extends Fake implements MaintenanceService {
  final List<MaintenanceModel> tasksToReturn;
  final StreamController<List<MaintenanceModel>> _controller =
      StreamController<List<MaintenanceModel>>.broadcast();

  _MockMaintenanceService({this.tasksToReturn = const []});

  @override
  Future<List<MaintenanceModel>> getMaintenanceTasks({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) async {
    return tasksToReturn;
  }

  @override
  Stream<List<MaintenanceModel>> streamMaintenanceTasks({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) {
    Future.microtask(() {
      if (!_controller.isClosed) {
        _controller.add(tasksToReturn);
      }
    });
    return _controller.stream;
  }

  void emit(List<MaintenanceModel> tasks) {
    if (!_controller.isClosed) _controller.add(tasks);
  }

  void emitError(Object error) {
    if (!_controller.isClosed) _controller.addError(error);
  }

  void dispose() => _controller.close();
}

void main() {
  group('MachineActivityService Tests', () {
    final now = DateTime(2026, 11, 3, 10, 0, 0);

    test('1. Fault logs filtered by machine ID', () {
      final service = MachineActivityService(
        faultService: _MockFaultService(),
        maintenanceService: _MockMaintenanceService(),
      );

      final f1 = FaultModel(
        id: 'FLT-001',
        machineId: 'MCH-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityCritical,
        description: 'Vibration detected',
        reportedBy: 'op-1',
        reportedByName: 'Jatin Kashyap',
        createdAt: now,
      );
      final f2 = FaultModel(
        id: 'FLT-002',
        machineId: 'MCH-02', // Different machine!
        type: AppConstants.faultTypeElectrical,
        severity: AppConstants.severityHigh,
        description: 'Short circuit',
        reportedBy: 'op-2',
        reportedByName: 'Alex Vance',
        createdAt: now.add(const Duration(minutes: 5)),
      );

      final timeline = service.buildActivityTimeline(
        machineId: 'MCH-01',
        faults: [f1, f2],
        tasks: [],
      );

      expect(timeline.length, equals(1));
      expect(timeline.first.id, equals('fault_reported_FLT-001'));
      expect(timeline.first.machineId, equals('MCH-01'));
      expect(timeline.first.title, contains('Mechanical'));
    });

    test('2. Maintenance logs filtered by machine ID', () {
      final service = MachineActivityService(
        faultService: _MockFaultService(),
        maintenanceService: _MockMaintenanceService(),
      );

      final t1 = MaintenanceModel(
        id: 'MNT-001',
        machineId: 'MCH-01',
        technicianId: 'tech-1',
        technicianName: 'Marcus Vance',
        priority: AppConstants.severityHigh,
        status: AppConstants.maintenanceStatusPending,
        createdAt: now,
      );
      final t2 = MaintenanceModel(
        id: 'MNT-002',
        machineId: 'MCH-03', // Different machine!
        technicianId: 'tech-2',
        technicianName: 'Sarah Connor',
        priority: AppConstants.severityLow,
        status: AppConstants.maintenanceStatusPending,
        createdAt: now,
      );

      final timeline = service.buildActivityTimeline(
        machineId: 'MCH-01',
        faults: [],
        tasks: [t1, t2],
      );

      expect(timeline.length, equals(1));
      expect(timeline.first.id, equals('maintenance_assigned_MNT-001'));
      expect(timeline.first.machineId, equals('MCH-01'));
      expect(timeline.first.actorName, equals('Marcus Vance'));
    });

    test('3. Multiple event types in chronological order (descending)', () {
      final service = MachineActivityService(
        faultService: _MockFaultService(),
        maintenanceService: _MockMaintenanceService(),
      );

      final f1 = FaultModel(
        id: 'FLT-001',
        machineId: 'MCH-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityHigh,
        description: 'Oil leak',
        reportedBy: 'op-1',
        reportedByName: 'Sam Operator',
        createdAt: DateTime(2026, 11, 3, 8, 0), // Oldest
      );

      final t1 = MaintenanceModel(
        id: 'MNT-001',
        machineId: 'MCH-01',
        faultId: 'FLT-001',
        technicianId: 'tech-1',
        technicianName: 'Marcus Vance',
        priority: AppConstants.severityHigh,
        status: AppConstants.maintenanceStatusResolved,
        createdAt: DateTime(2026, 11, 3, 9, 0),
        updateHistory: [
          MaintenanceUpdateModel(
            id: 'upd-1',
            taskId: 'MNT-001',
            previousStatus: AppConstants.maintenanceStatusPending,
            newStatus: AppConstants.maintenanceStatusInProgress,
            notes: 'Investigating hydraulic pressure seal',
            updatedBy: 'tech-1',
            updatedAt: DateTime(2026, 11, 3, 9, 30),
          ),
          MaintenanceUpdateModel(
            id: 'upd-2',
            taskId: 'MNT-001',
            previousStatus: AppConstants.maintenanceStatusInProgress,
            newStatus: AppConstants.maintenanceStatusResolved,
            notes: 'Replaced seal and repressurized system',
            proofImageUrl: 'https://storage/proof.jpg',
            updatedBy: 'tech-1',
            updatedAt: DateTime(2026, 11, 3, 11, 0), // Newest
          ),
        ],
      );

      final timeline = service.buildActivityTimeline(
        machineId: 'MCH-01',
        faults: [f1],
        tasks: [t1],
      );

      expect(timeline.length, equals(4));
      // 1st: Maintenance Resolved at 11:00
      expect(timeline[0].type, equals(MachineActivityType.maintenanceResolved));
      expect(timeline[0].title, equals('Maintenance Resolved'));
      expect(timeline[0].timestamp, equals(DateTime(2026, 11, 3, 11, 0)));
      expect(timeline[0].hasProofImage, isTrue);

      // 2nd: Maintenance In Progress at 09:30
      expect(timeline[1].type, equals(MachineActivityType.maintenanceInProgress));
      expect(timeline[1].title, equals('Maintenance In Progress'));
      expect(timeline[1].timestamp, equals(DateTime(2026, 11, 3, 9, 30)));

      // 3rd: Maintenance Assigned at 09:00
      expect(timeline[2].type, equals(MachineActivityType.maintenanceAssigned));
      expect(timeline[2].title, equals('Maintenance Assigned'));
      expect(timeline[2].timestamp, equals(DateTime(2026, 11, 3, 9, 0)));

      // 4th: Fault Reported at 08:00
      expect(timeline[3].type, equals(MachineActivityType.faultReported));
      expect(timeline[3].title, contains('Fault Reported'));
      expect(timeline[3].timestamp, equals(DateTime(2026, 11, 3, 8, 0)));
    });

    test('4. Correct reporter and technician names without exposing UIDs', () {
      final service = MachineActivityService(
        faultService: _MockFaultService(),
        maintenanceService: _MockMaintenanceService(),
      );

      // Raw Firebase UID format: 28 characters
      const rawUid = 'JO5v92NOnFQC1gvKPigwBfAnSut2';

      final faultWithUid = FaultModel(
        id: 'FLT-001',
        machineId: 'MCH-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityHigh,
        description: 'Noise',
        reportedBy: rawUid,
        reportedByName: rawUid, // Raw UID erroneously passed as name
        createdAt: now,
      );

      final taskWithUid = MaintenanceModel(
        id: 'MNT-001',
        machineId: 'MCH-01',
        technicianId: rawUid,
        technicianName: rawUid, // Raw UID
        priority: AppConstants.severityMedium,
        status: AppConstants.maintenanceStatusPending,
        createdAt: now,
      );

      final timeline = service.buildActivityTimeline(
        machineId: 'MCH-01',
        faults: [faultWithUid],
        tasks: [taskWithUid],
      );

      // Neither should expose the raw UID string
      for (final event in timeline) {
        expect(event.actorName, isNot(equals(rawUid)));
        expect(event.actorName.contains(rawUid), isFalse);
      }

      final faultEvent = timeline.firstWhere(
        (e) => e.type == MachineActivityType.faultReported,
      );
      expect(faultEvent.actorName, equals('Unknown Reporter'));

      final taskEvent = timeline.firstWhere(
        (e) => e.type == MachineActivityType.maintenanceAssigned,
      );
      expect(taskEvent.actorName, equals('Technician'));
    });

    test('5. Empty history returns an empty list', () {
      final service = MachineActivityService(
        faultService: _MockFaultService(),
        maintenanceService: _MockMaintenanceService(),
      );

      final timeline = service.buildActivityTimeline(
        machineId: 'MCH-EMPTY',
        faults: [],
        tasks: [],
      );

      expect(timeline, isEmpty);
    });

    test('6. Duplicate-event prevention for linked fault and maintenance', () {
      final service = MachineActivityService(
        faultService: _MockFaultService(),
        maintenanceService: _MockMaintenanceService(),
      );

      // Fault is marked Resolved in Firestore
      final fault = FaultModel(
        id: 'FLT-100',
        machineId: 'MCH-01',
        type: AppConstants.faultTypeElectrical,
        severity: AppConstants.severityCritical,
        description: 'Power outage on panel',
        reportedBy: 'op-1',
        reportedByName: 'Jatin Kashyap',
        status: AppConstants.faultStatusResolved,
        createdAt: now,
      );

      // Maintenance task linked to this fault with its own resolution update
      final task = MaintenanceModel(
        id: 'MNT-100',
        machineId: 'MCH-01',
        faultId: 'FLT-100',
        technicianId: 'tech-1',
        technicianName: 'Marcus Vance',
        priority: AppConstants.severityCritical,
        status: AppConstants.maintenanceStatusResolved,
        createdAt: now.add(const Duration(minutes: 10)),
        updateHistory: [
          MaintenanceUpdateModel(
            id: 'upd-1',
            taskId: 'MNT-100',
            previousStatus: AppConstants.maintenanceStatusPending,
            newStatus: AppConstants.maintenanceStatusResolved,
            notes: 'Circuit breaker reset',
            updatedBy: 'tech-1',
            updatedAt: now.add(const Duration(minutes: 30)),
          ),
        ],
      );

      final timeline = service.buildActivityTimeline(
        machineId: 'MCH-01',
        faults: [fault],
        tasks: [task],
      );

      // Expect:
      // 1. Maintenance Resolved (from task update)
      // 2. Maintenance Assigned (from task creation)
      // 3. Fault Reported (from fault creation)
      // There should NOT be a duplicate "Fault Status: Resolved" event from the fault document!
      expect(timeline.length, equals(3));
      final resolvedEvents = timeline
          .where((e) => e.type == MachineActivityType.faultStatusChanged)
          .toList();
      expect(resolvedEvents, isEmpty);
    });

    test('7. Missing timestamps handled safely without crashing', () {
      final service = MachineActivityService(
        faultService: _MockFaultService(),
        maintenanceService: _MockMaintenanceService(),
      );

      final fNoTime = FaultModel(
        id: 'FLT-NOTIME',
        machineId: 'MCH-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityLow,
        description: 'Loose bolt',
        reportedBy: 'op-1',
        reportedByName: 'Bob',
        createdAt: null, // Null timestamp!
      );

      final fWithTime = FaultModel(
        id: 'FLT-TIME',
        machineId: 'MCH-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityMedium,
        description: 'Filter clean',
        reportedBy: 'op-1',
        reportedByName: 'Bob',
        createdAt: now,
      );

      final timeline = service.buildActivityTimeline(
        machineId: 'MCH-01',
        faults: [fNoTime, fWithTime],
        tasks: [],
      );

      expect(timeline.length, equals(2));
      // Event with timestamp is first
      expect(timeline[0].timestamp, equals(now));
      // Event with null timestamp is placed at the end safely
      expect(timeline[1].timestamp, isNull);
      expect(timeline[1].formattedDateTime, equals('Date unavailable'));
    });

    test('8. Stream emits combined timeline and updates in real-time', () async {
      final faultService = _MockFaultService(
        faultsToReturn: [
          FaultModel(
            id: 'FLT-01',
            machineId: 'MCH-01',
            type: AppConstants.faultTypeMechanical,
            severity: AppConstants.severityHigh,
            description: 'Belt slip',
            reportedBy: 'op-1',
            reportedByName: 'Alex',
            createdAt: now,
          ),
        ],
      );

      final maintenanceService = _MockMaintenanceService(
        tasksToReturn: [
          MaintenanceModel(
            id: 'MNT-01',
            machineId: 'MCH-01',
            technicianId: 'tech-1',
            technicianName: 'Marcus',
            priority: AppConstants.severityHigh,
            status: AppConstants.maintenanceStatusPending,
            createdAt: now.add(const Duration(minutes: 10)),
          ),
        ],
      );

      final service = MachineActivityService(
        faultService: faultService,
        maintenanceService: maintenanceService,
      );

      final stream = service.streamMachineActivity('MCH-01');

      final emitted = await stream.firstWhere((list) => list.length == 2);
      expect(emitted.length, equals(2));
      expect(emitted.first.type, equals(MachineActivityType.maintenanceAssigned));
      expect(emitted.last.type, equals(MachineActivityType.faultReported));

      faultService.dispose();
      maintenanceService.dispose();
    });
  });
}
