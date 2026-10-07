class MaintenanceModel {
  final String id;
  final String machineId;
  final String? machineName;
  final String? faultId;
  final String technicianId;
  final String? technicianName;
  final String priority;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MaintenanceModel({
    required this.id,
    required this.machineId,
    this.machineName,
    this.faultId,
    required this.technicianId,
    this.technicianName,
    required this.priority,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  MaintenanceModel copyWith({
    String? id,
    String? machineId,
    String? machineName,
    String? faultId,
    String? technicianId,
    String? technicianName,
    String? priority,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaintenanceModel(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      faultId: faultId ?? this.faultId,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machineId': machineId,
      'machineName': machineName,
      'faultId': faultId,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'priority': priority,
      'status': status,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MaintenanceModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return MaintenanceModel(
      id: docId ?? map['id'] as String? ?? map['maintenanceId'] as String? ?? '',
      machineId: map['machineId'] as String? ?? '',
      machineName: map['machineName'] as String?,
      faultId: map['faultId'] as String?,
      technicianId: map['technicianId'] as String? ?? '',
      technicianName: map['technicianName'] as String?,
      priority: map['priority'] as String? ?? '',
      status: map['status'] as String? ?? 'Pending',
      notes: map['notes'] as String?,
      createdAt: _parseDateTime(map['createdAt'] ?? map['assignedAt']),
      updatedAt: _parseDateTime(map['updatedAt'] ?? map['resolvedAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.tryParse(value.toString());
    }
  }

  @override
  String toString() {
    return 'MaintenanceModel(id: $id, machineId: $machineId, machineName: $machineName, faultId: $faultId, technicianId: $technicianId, technicianName: $technicianName, priority: $priority, status: $status, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MaintenanceModel &&
        other.id == id &&
        other.machineId == machineId &&
        other.machineName == machineName &&
        other.faultId == faultId &&
        other.technicianId == technicianId &&
        other.technicianName == technicianName &&
        other.priority == priority &&
        other.status == status &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      machineId,
      machineName,
      faultId,
      technicianId,
      technicianName,
      priority,
      status,
      notes,
      createdAt,
      updatedAt,
    );
  }
}
