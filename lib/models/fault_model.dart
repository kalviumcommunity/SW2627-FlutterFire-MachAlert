class FaultModel {
  final String id;
  final String machineId;
  final String? machineName;
  final String type;
  final String severity;
  final String description;
  final String reportedBy;
  final String? reportedByName;
  final String status;
  final String? imageUrl;
  final DateTime? createdAt;

  FaultModel({
    required this.id,
    required this.machineId,
    this.machineName,
    required this.type,
    required this.severity,
    required this.description,
    required this.reportedBy,
    this.reportedByName,
    this.status = 'Open',
    this.imageUrl,
    this.createdAt,
  });

  FaultModel copyWith({
    String? id,
    String? machineId,
    String? machineName,
    String? type,
    String? severity,
    String? description,
    String? reportedBy,
    String? reportedByName,
    String? status,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return FaultModel(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      reportedBy: reportedBy ?? this.reportedBy,
      reportedByName: reportedByName ?? this.reportedByName,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'machineId': machineId,
      'machineName': machineName,
      'type': type,
      'severity': severity,
      'description': description,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'status': status,
      'imageUrl': imageUrl,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory FaultModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return FaultModel(
      id: docId ?? map['id'] as String? ?? map['faultId'] as String? ?? '',
      machineId: map['machineId'] as String? ?? '',
      machineName: map['machineName'] as String?,
      type: map['type'] as String? ?? '',
      severity: map['severity'] as String? ?? '',
      description: map['description'] as String? ?? '',
      reportedBy: map['reportedBy'] as String? ?? '',
      reportedByName: map['reportedByName'] as String?,
      status: map['status'] as String? ?? 'Open',
      imageUrl: map['imageUrl'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
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
    return 'FaultModel(id: $id, machineId: $machineId, machineName: $machineName, type: $type, severity: $severity, description: $description, reportedBy: $reportedBy, reportedByName: $reportedByName, status: $status, imageUrl: $imageUrl, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FaultModel &&
        other.id == id &&
        other.machineId == machineId &&
        other.machineName == machineName &&
        other.type == type &&
        other.severity == severity &&
        other.description == description &&
        other.reportedBy == reportedBy &&
        other.reportedByName == reportedByName &&
        other.status == status &&
        other.imageUrl == imageUrl &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      machineId,
      machineName,
      type,
      severity,
      description,
      reportedBy,
      reportedByName,
      status,
      imageUrl,
      createdAt,
    );
  }
}
