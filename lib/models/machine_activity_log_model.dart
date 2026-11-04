import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories of machine activity log events supported by MachAlert.
enum MachineActivityType {
  /// A fault report was submitted for this machine.
  faultReported,

  /// A fault status changed independently of maintenance.
  faultStatusChanged,

  /// A maintenance task was created/assigned for this machine.
  maintenanceAssigned,

  /// A maintenance technician started working on the machine (Pending -> In Progress).
  maintenanceInProgress,

  /// A maintenance task on the machine was completed and resolved.
  maintenanceResolved,

  /// A technician logged repair notes or an update without a terminal status change.
  maintenanceNote,
}

/// Unified activity log event model representing an incident or lifecycle action
/// for a specific factory machine.
///
/// Integrates records from `faults` and `maintenance` (including `updateHistory`),
/// presenting a chronological audit trail with verified actor names, status badges,
/// timestamps, and optional proof image references.
class MachineActivityLogModel {
  /// Unique identifier for this timeline event (e.g. `fault_reported_FLT101`).
  final String id;

  /// Identifier of the machine associated with this event.
  final String machineId;

  /// Machine activity category.
  final MachineActivityType type;

  /// Human-readable title for display in the timeline.
  final String title;

  /// Detailed description, fault details, or technician repair notes.
  final String? description;

  /// Event occurrence timestamp. Safe to be null for legacy/unrecorded events.
  final DateTime? timestamp;

  /// Human-readable display name of the actor (reporter or technician).
  /// Never contains a raw Firebase UID string.
  final String actorName;

  /// Role of the actor performing the action (e.g. "Reporter", "Technician").
  final String actorRole;

  /// Current status resulting from or associated with this event
  /// (e.g. "Open", "Pending", "In Progress", "Resolved").
  final String status;

  /// Optional severity or priority associated with this event
  /// (e.g. "Critical", "High", "Medium", "Low").
  final String? severity;

  /// Optional fault type (e.g. "Mechanical", "Electrical", "Hydraulic").
  final String? faultType;

  /// Optional photo proof or attachment download URL.
  final String? proofImageUrl;

  /// Linked fault document identifier, if applicable.
  final String? relatedFaultId;

  /// Linked maintenance task document identifier, if applicable.
  final String? relatedTaskId;

  const MachineActivityLogModel({
    required this.id,
    required this.machineId,
    required this.type,
    required this.title,
    this.description,
    this.timestamp,
    required this.actorName,
    required this.actorRole,
    required this.status,
    this.severity,
    this.faultType,
    this.proofImageUrl,
    this.relatedFaultId,
    this.relatedTaskId,
  });

  /// Whether this event originated from a fault report.
  bool get isFaultEvent =>
      type == MachineActivityType.faultReported ||
      type == MachineActivityType.faultStatusChanged;

  /// Whether this event originated from maintenance activity.
  bool get isMaintenanceEvent => !isFaultEvent;

  /// Whether a proof photo or fault image is attached.
  bool get hasProofImage =>
      proofImageUrl != null && proofImageUrl!.trim().isNotEmpty;

  /// Formatted date/time string with safe fallback for missing timestamps.
  String get formattedDateTime {
    if (timestamp == null) return 'Date unavailable';
    final d = timestamp!.day.toString().padLeft(2, '0');
    final m = timestamp!.month.toString().padLeft(2, '0');
    final y = timestamp!.year.toString();
    final h = timestamp!.hour.toString().padLeft(2, '0');
    final min = timestamp!.minute.toString().padLeft(2, '0');
    return '$d/$m/$y • $h:$min';
  }

  /// Creates a copy of this activity log with given fields replaced.
  MachineActivityLogModel copyWith({
    String? id,
    String? machineId,
    MachineActivityType? type,
    String? title,
    String? description,
    DateTime? timestamp,
    String? actorName,
    String? actorRole,
    String? status,
    String? severity,
    String? faultType,
    String? proofImageUrl,
    String? relatedFaultId,
    String? relatedTaskId,
  }) {
    return MachineActivityLogModel(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      actorName: actorName ?? this.actorName,
      actorRole: actorRole ?? this.actorRole,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      faultType: faultType ?? this.faultType,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      relatedFaultId: relatedFaultId ?? this.relatedFaultId,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
    );
  }

  /// Converts this event to a Map representation.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machineId': machineId,
      'type': type.name,
      'title': title,
      'description': description,
      'timestamp': timestamp?.toIso8601String(),
      'actorName': actorName,
      'actorRole': actorRole,
      'status': status,
      'severity': severity,
      'faultType': faultType,
      'proofImageUrl': proofImageUrl,
      'relatedFaultId': relatedFaultId,
      'relatedTaskId': relatedTaskId,
    };
  }

  /// Recreates a [MachineActivityLogModel] from a Map representation.
  factory MachineActivityLogModel.fromMap(
    Map<String, dynamic> map, [
    String? docId,
  ]) {
    final typeName = map['type'] as String? ?? 'faultReported';
    final parsedType = MachineActivityType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MachineActivityType.faultReported,
    );

    return MachineActivityLogModel(
      id: docId ?? map['id'] as String? ?? '',
      machineId: map['machineId'] as String? ?? '',
      type: parsedType,
      title: map['title'] as String? ?? 'Activity Event',
      description: map['description'] as String?,
      timestamp: _parseDateTime(map['timestamp']),
      actorName: map['actorName'] as String? ?? 'Unknown',
      actorRole: map['actorRole'] as String? ?? 'User',
      status: map['status'] as String? ?? 'Open',
      severity: map['severity'] as String?,
      faultType: map['faultType'] as String?,
      proofImageUrl: map['proofImageUrl'] as String?,
      relatedFaultId: map['relatedFaultId'] as String?,
      relatedTaskId: map['relatedTaskId'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineActivityLogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          machineId == other.machineId &&
          type == other.type &&
          title == other.title &&
          description == other.description &&
          timestamp == other.timestamp &&
          actorName == other.actorName &&
          actorRole == other.actorRole &&
          status == other.status &&
          severity == other.severity &&
          faultType == other.faultType &&
          proofImageUrl == other.proofImageUrl &&
          relatedFaultId == other.relatedFaultId &&
          relatedTaskId == other.relatedTaskId;

  @override
  int get hashCode => Object.hash(
    id,
    machineId,
    type,
    title,
    description,
    timestamp,
    actorName,
    actorRole,
    status,
    severity,
    faultType,
    proofImageUrl,
    relatedFaultId,
    relatedTaskId,
  );

  @override
  String toString() =>
      'MachineActivityLogModel(id: $id, machineId: $machineId, type: $type, title: $title, timestamp: $timestamp, actorName: $actorName, status: $status)';
}
