import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an individual maintenance task status update or repair log entry.
///
/// Records state transitions, technician repair notes, photo proof URLs,
/// the actor UID, and the timestamp when the update was recorded.
class MaintenanceUpdateModel {
  /// Unique identifier for this update entry.
  final String id;

  /// Identifier of the parent maintenance task (`maintenance/{taskId}`).
  final String taskId;

  /// The maintenance status prior to this update.
  final String previousStatus;

  /// The maintenance status resulting from this update.
  final String newStatus;

  /// Optional technician notes detailing work performed or reasons for update.
  final String? notes;

  /// Optional Firebase Storage download URL providing photo proof of repair.
  final String? proofImageUrl;

  /// Firebase Auth UID of the user who recorded this update.
  final String updatedBy;

  /// Timestamp when this update was applied.
  final DateTime? updatedAt;

  const MaintenanceUpdateModel({
    required this.id,
    required this.taskId,
    required this.previousStatus,
    required this.newStatus,
    this.notes,
    this.proofImageUrl,
    required this.updatedBy,
    this.updatedAt,
  });

  /// Whether this update included a status transition.
  bool get isStatusChange => previousStatus != newStatus;

  /// Whether this update includes technician notes.
  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;

  /// Whether this update includes photo proof.
  bool get hasProofImage =>
      proofImageUrl != null && proofImageUrl!.trim().isNotEmpty;

  /// Creates a copy of this update model with the given fields replaced.
  MaintenanceUpdateModel copyWith({
    String? id,
    String? taskId,
    String? previousStatus,
    String? newStatus,
    String? notes,
    String? proofImageUrl,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return MaintenanceUpdateModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      previousStatus: previousStatus ?? this.previousStatus,
      newStatus: newStatus ?? this.newStatus,
      notes: notes ?? this.notes,
      proofImageUrl: proofImageUrl ?? this.proofImageUrl,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Converts this model to a Map representation for Firestore persistence or serialization.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'previousStatus': previousStatus,
      'newStatus': newStatus,
      'notes': notes,
      'proofImageUrl': proofImageUrl,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Recreates a [MaintenanceUpdateModel] from a Map representation.
  ///
  /// Supports [Timestamp], [DateTime], [int] milliseconds since epoch, and ISO-8601 [String] timestamps.
  factory MaintenanceUpdateModel.fromMap(
    Map<String, dynamic> map, [
    String? docId,
  ]) {
    return MaintenanceUpdateModel(
      id: docId ?? map['id'] as String? ?? map['updateId'] as String? ?? '',
      taskId: map['taskId'] as String? ?? '',
      previousStatus: map['previousStatus'] as String? ?? '',
      newStatus: map['newStatus'] as String? ?? '',
      notes: map['notes'] as String?,
      proofImageUrl: map['proofImageUrl'] as String?,
      updatedBy: map['updatedBy'] as String? ?? '',
      updatedAt: _parseDateTime(
        map['updatedAt'] ?? map['timestamp'] ?? map['createdAt'],
      ),
    );
  }

  /// Safely converts dynamic date inputs into a [DateTime] instance.
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
      other is MaintenanceUpdateModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          taskId == other.taskId &&
          previousStatus == other.previousStatus &&
          newStatus == other.newStatus &&
          notes == other.notes &&
          proofImageUrl == other.proofImageUrl &&
          updatedBy == other.updatedBy &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    previousStatus,
    newStatus,
    notes,
    proofImageUrl,
    updatedBy,
    updatedAt,
  );

  @override
  String toString() =>
      'MaintenanceUpdateModel(id: $id, taskId: $taskId, previousStatus: $previousStatus, newStatus: $newStatus, notes: $notes, proofImageUrl: $proofImageUrl, updatedBy: $updatedBy, updatedAt: $updatedAt)';
}
