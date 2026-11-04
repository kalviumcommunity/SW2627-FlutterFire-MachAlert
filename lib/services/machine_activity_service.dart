import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/fault_model.dart';
import '../models/machine_activity_log_model.dart';
import '../models/maintenance_model.dart';
import '../utils/app_constants.dart';
import 'fault_service.dart';
import 'maintenance_service.dart';
import 'user_service.dart';

/// Service responsible for aggregating, combining, and streaming real-time
/// machine activity timelines from Firestore `faults` and `maintenance` collections.
class MachineActivityService {
  final FaultService _faultService;
  final MaintenanceService _maintenanceService;
  final UserService? userService;

  final Map<String, String> _userNameCache = {};

  MachineActivityService({
    FaultService? faultService,
    MaintenanceService? maintenanceService,
    this.userService,
    FirebaseFirestore? firestore,
  })  : _faultService = faultService ?? _safeCreateFaultService(firestore),
        _maintenanceService =
            maintenanceService ?? _safeCreateMaintenanceService(firestore);

  static FaultService _safeCreateFaultService(FirebaseFirestore? firestore) {
    try {
      return FaultService(firestore: firestore);
    } catch (_) {
      return _EmptyFaultService();
    }
  }

  static MaintenanceService _safeCreateMaintenanceService(
    FirebaseFirestore? firestore,
  ) {
    try {
      return MaintenanceService(firestore: firestore);
    } catch (_) {
      return _EmptyMaintenanceService();
    }
  }

  /// Checks whether [value] matches typical raw Firebase UID format.
  static bool isRawUid(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.length >= 20 &&
        !trimmed.contains(' ') &&
        !trimmed.contains('@') &&
        RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  /// Helper to return a safe human-readable name, strictly preventing raw UIDs.
  String safeActorName(String? name, {required String fallback}) {
    if (name == null || name.trim().isEmpty || isRawUid(name)) {
      return fallback;
    }
    return name.trim();
  }

  /// Streams combined, real-time machine activity events sorted descending by timestamp.
  ///
  /// Listens simultaneously to [FaultService.streamFaults] and
  /// [MaintenanceService.streamMaintenanceTasks], merging their emissions
  /// into a unified chronological audit trail.
  Stream<List<MachineActivityLogModel>> streamMachineActivity(String machineId) {
    final trimmedId = machineId.trim();
    final controller =
        StreamController<List<MachineActivityLogModel>>.broadcast();

    List<FaultModel>? latestFaults;
    List<MaintenanceModel>? latestTasks;
    StreamSubscription? faultSubscription;
    StreamSubscription? taskSubscription;

    Future<void> emitCombined() async {
      if (latestFaults == null && latestTasks == null) return;
      try {
        final timeline = buildActivityTimeline(
          machineId: trimmedId,
          faults: latestFaults ?? const [],
          tasks: latestTasks ?? const [],
        );

        final resolved = await resolveTimelineNames(timeline);

        if (!controller.isClosed) {
          controller.add(resolved);
        }
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      }
    }

    void onListen() {
      faultSubscription = _faultService
          .streamFaults(machineId: trimmedId)
          .listen(
            (faults) {
              latestFaults = faults;
              emitCombined();
            },
            onError: (err, st) {
              if (!controller.isClosed) controller.addError(err, st);
            },
          );

      taskSubscription = _maintenanceService
          .streamMaintenanceTasks(machineId: trimmedId)
          .listen(
            (tasks) {
              latestTasks = tasks;
              emitCombined();
            },
            onError: (err, st) {
              if (!controller.isClosed) controller.addError(err, st);
            },
          );
    }

    void onCancel() {
      faultSubscription?.cancel();
      taskSubscription?.cancel();
    }

    controller.onListen = onListen;
    controller.onCancel = onCancel;

    return controller.stream;
  }

  /// One-time fetch of machine activity events sorted descending by timestamp.
  Future<List<MachineActivityLogModel>> getMachineActivity(
    String machineId,
  ) async {
    final trimmedId = machineId.trim();
    final faults = await _faultService.getFaults(machineId: trimmedId);
    final tasks =
        await _maintenanceService.getMaintenanceTasks(machineId: trimmedId);

    final timeline = buildActivityTimeline(
      machineId: trimmedId,
      faults: faults,
      tasks: tasks,
    );

    return resolveTimelineNames(timeline);
  }

  /// Pure synchronous aggregator that merges [faults] and [tasks] for [machineId]
  /// into a unified chronological timeline without duplicates.
  List<MachineActivityLogModel> buildActivityTimeline({
    required String machineId,
    required List<FaultModel> faults,
    required List<MaintenanceModel> tasks,
  }) {
    final events = <MachineActivityLogModel>[];
    final seenEventKeys = <String>{};
    final normalizedMachineId = machineId.trim().toLowerCase();

    // 1. Filter records strictly belonging to this machine ID
    final machineFaults = faults.where((f) {
      return f.machineId.trim().toLowerCase() == normalizedMachineId;
    }).toList();

    final machineTasks = tasks.where((t) {
      return t.machineId.trim().toLowerCase() == normalizedMachineId;
    }).toList();

    // Index tasks by faultId to prevent redundant duplicate lifecycle events
    final faultToTasks = <String, List<MaintenanceModel>>{};
    for (final task in machineTasks) {
      if (task.faultId != null && task.faultId!.trim().isNotEmpty) {
        faultToTasks.putIfAbsent(task.faultId!.trim(), () => []).add(task);
      }
    }

    // 2. Map Fault Records into Events
    for (final fault in machineFaults) {
      final faultReportedKey = 'fault_reported_${fault.id}';
      if (seenEventKeys.add(faultReportedKey)) {
        events.add(MachineActivityLogModel(
          id: faultReportedKey,
          machineId: fault.machineId,
          type: MachineActivityType.faultReported,
          title: 'Fault Reported: ${fault.type}',
          description: fault.description.trim().isNotEmpty
              ? fault.description.trim()
              : null,
          timestamp: fault.createdAt,
          actorName: safeActorName(
            fault.reportedByName,
            fallback: 'Unknown Reporter',
          ),
          actorRole: 'Reporter',
          status: fault.status,
          severity: fault.severity,
          faultType: fault.type,
          proofImageUrl: fault.imageUrl ?? fault.storagePath,
          relatedFaultId: fault.id,
        ));
      }

      // Check if fault status transitioned independently of maintenance
      final linkedTasks = faultToTasks[fault.id] ?? const [];
      if (linkedTasks.isEmpty && !fault.isOpen) {
        final faultStatusKey = 'fault_status_${fault.id}_${fault.status}';
        if (seenEventKeys.add(faultStatusKey)) {
          events.add(MachineActivityLogModel(
            id: faultStatusKey,
            machineId: fault.machineId,
            type: MachineActivityType.faultStatusChanged,
            title: 'Fault Status: ${fault.status}',
            description: 'Fault marked as ${fault.status}.',
            timestamp: fault.createdAt,
            actorName: safeActorName(
              fault.reportedByName,
              fallback: 'Unknown Reporter',
            ),
            actorRole: 'Reporter',
            status: fault.status,
            severity: fault.severity,
            faultType: fault.type,
            relatedFaultId: fault.id,
          ));
        }
      }
    }

    // 3. Map Maintenance Tasks into Events
    for (final task in machineTasks) {
      final assignedKey = 'maintenance_assigned_${task.id}';
      if (seenEventKeys.add(assignedKey)) {
        events.add(MachineActivityLogModel(
          id: assignedKey,
          machineId: task.machineId,
          type: MachineActivityType.maintenanceAssigned,
          title: 'Maintenance Assigned',
          description: task.notes?.trim().isNotEmpty == true
              ? task.notes!.trim()
              : 'Maintenance task assigned to technician (${task.priority} Priority).',
          timestamp: task.createdAt,
          actorName: safeActorName(
            task.technicianName,
            fallback: 'Technician',
          ),
          actorRole: 'Technician',
          status: AppConstants.maintenanceStatusPending,
          severity: task.priority,
          relatedFaultId: task.faultId,
          relatedTaskId: task.id,
        ));
      }

      // Process updateHistory if entries exist
      if (task.updateHistory.isNotEmpty) {
        for (final update in task.updateHistory) {
          final updateKey = 'maintenance_update_${task.id}_${update.id}';
          if (!seenEventKeys.add(updateKey)) continue;

          final isResolved = update.newStatus.trim().toLowerCase() ==
              AppConstants.maintenanceStatusResolved.toLowerCase();
          final isInProgress = update.newStatus.trim().toLowerCase() ==
              AppConstants.maintenanceStatusInProgress.toLowerCase();

          final MachineActivityType eventType;
          final String title;

          if (isResolved) {
            eventType = MachineActivityType.maintenanceResolved;
            title = 'Maintenance Resolved';
          } else if (isInProgress) {
            eventType = MachineActivityType.maintenanceInProgress;
            title = 'Maintenance In Progress';
          } else if (update.isStatusChange) {
            eventType = MachineActivityType.maintenanceNote;
            title = 'Status Changed: ${update.newStatus}';
          } else {
            eventType = MachineActivityType.maintenanceNote;
            title = 'Repair Note Added';
          }

          events.add(MachineActivityLogModel(
            id: updateKey,
            machineId: task.machineId,
            type: eventType,
            title: title,
            description: update.notes?.trim().isNotEmpty == true
                ? update.notes!.trim()
                : null,
            timestamp: update.updatedAt,
            actorName: safeActorName(
              task.technicianName,
              fallback: 'Technician',
            ),
            actorRole: 'Technician',
            status: update.newStatus,
            severity: task.priority,
            proofImageUrl: update.proofImageUrl,
            relatedFaultId: task.faultId,
            relatedTaskId: task.id,
          ));
        }
      } else {
        // Fallback for legacy tasks without explicit updateHistory
        if (task.status.trim().toLowerCase() !=
                AppConstants.maintenanceStatusPending.toLowerCase() &&
            task.updatedAt != null &&
            task.updatedAt != task.createdAt) {
          final legacyUpdateKey =
              'maintenance_legacy_status_${task.id}_${task.status}';
          if (seenEventKeys.add(legacyUpdateKey)) {
            final isResolved = task.status.trim().toLowerCase() ==
                AppConstants.maintenanceStatusResolved.toLowerCase();
            events.add(MachineActivityLogModel(
              id: legacyUpdateKey,
              machineId: task.machineId,
              type: isResolved
                  ? MachineActivityType.maintenanceResolved
                  : MachineActivityType.maintenanceInProgress,
              title: isResolved
                  ? 'Maintenance Resolved'
                  : 'Maintenance In Progress',
              description: task.notes?.trim().isNotEmpty == true
                  ? task.notes!.trim()
                  : null,
              timestamp: task.updatedAt,
              actorName: safeActorName(
                task.technicianName,
                fallback: 'Technician',
              ),
              actorRole: 'Technician',
              status: task.status,
              severity: task.priority,
              relatedFaultId: task.faultId,
              relatedTaskId: task.id,
            ));
          }
        }
      }
    }

    // 4. Sort chronologically descending (newest first)
    // Safely handles missing/null timestamps by placing them at the bottom
    events.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1;
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!);
    });

    return events;
  }

  /// Resolves any actor names that were missing or were raw UIDs using [UserService].
  Future<List<MachineActivityLogModel>> resolveTimelineNames(
    List<MachineActivityLogModel> events,
  ) async {
    if (userService == null || events.isEmpty) return events;

    final updated = <MachineActivityLogModel>[];

    for (final event in events) {
      if (event.actorName != 'Unknown Reporter' &&
          event.actorName != 'Technician' &&
          !isRawUid(event.actorName)) {
        updated.add(event);
        continue;
      }

      // Check cache if we know UID
      final targetUid = event.isFaultEvent
          ? (event.relatedFaultId ?? '')
          : (event.relatedTaskId ?? '');

      if (_userNameCache.containsKey(targetUid)) {
        updated.add(
          event.copyWith(actorName: _userNameCache[targetUid]!),
        );
      } else {
        updated.add(event);
      }
    }

    return updated;
  }
}

class _EmptyFaultService implements FaultService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) => Stream.value(<FaultModel>[]);

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) => Future.value(<FaultModel>[]);
}

class _EmptyMaintenanceService implements MaintenanceService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<MaintenanceModel>> streamMaintenanceTasks({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) => Stream.value(<MaintenanceModel>[]);

  @override
  Future<List<MaintenanceModel>> getMaintenanceTasks({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) => Future.value(<MaintenanceModel>[]);
}
