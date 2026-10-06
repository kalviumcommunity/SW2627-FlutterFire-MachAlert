class FaultModel {
  final String id;
  final String machineId;
  final String type;
  final String severity;
  final String description;
  final String reportedBy;
  final String? imageUrl;
  final DateTime? createdAt;

  FaultModel({
    required this.id,
    required this.machineId,
    required this.type,
    required this.severity,
    required this.description,
    required this.reportedBy,
    this.imageUrl,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machineId': machineId,
      'type': type,
      'severity': severity,
      'description': description,
      'reportedBy': reportedBy,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory FaultModel.fromMap(Map<String, dynamic> map) {
    return FaultModel(
      id: map['id'] as String? ?? '',
      machineId: map['machineId'] as String? ?? '',
      type: map['type'] as String? ?? '',
      severity: map['severity'] as String? ?? '',
      description: map['description'] as String? ?? '',
      reportedBy: map['reportedBy'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}
