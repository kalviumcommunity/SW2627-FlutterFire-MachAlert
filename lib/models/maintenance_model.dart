class MaintenanceModel {
  final String id;
  final String machineId;
  final String? faultId;
  final String technicianId;
  final String priority;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MaintenanceModel({
    required this.id,
    required this.machineId,
    this.faultId,
    required this.technicianId,
    required this.priority,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machineId': machineId,
      'faultId': faultId,
      'technicianId': technicianId,
      'priority': priority,
      'status': status,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MaintenanceModel.fromMap(Map<String, dynamic> map) {
    return MaintenanceModel(
      id: map['id'] as String? ?? '',
      machineId: map['machineId'] as String? ?? '',
      faultId: map['faultId'] as String?,
      technicianId: map['technicianId'] as String? ?? '',
      priority: map['priority'] as String? ?? '',
      status: map['status'] as String? ?? '',
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
