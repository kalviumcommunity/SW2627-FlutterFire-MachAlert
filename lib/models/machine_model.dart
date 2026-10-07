class MachineModel {
  final String id;
  final String name;
  final String productionLine;
  final String? modelNumber;
  final String status;
  final double healthScore;
  final double? temperature;
  final double? vibration;
  final DateTime? lastInspection;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MachineModel({
    required this.id,
    required this.name,
    required this.productionLine,
    this.modelNumber,
    required this.status,
    required this.healthScore,
    this.temperature,
    this.vibration,
    this.lastInspection,
    this.createdAt,
    this.updatedAt,
  });

  MachineModel copyWith({
    String? id,
    String? name,
    String? productionLine,
    String? modelNumber,
    String? status,
    double? healthScore,
    double? temperature,
    double? vibration,
    DateTime? lastInspection,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MachineModel(
      id: id ?? this.id,
      name: name ?? this.name,
      productionLine: productionLine ?? this.productionLine,
      modelNumber: modelNumber ?? this.modelNumber,
      status: status ?? this.status,
      healthScore: healthScore ?? this.healthScore,
      temperature: temperature ?? this.temperature,
      vibration: vibration ?? this.vibration,
      lastInspection: lastInspection ?? this.lastInspection,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'productionLine': productionLine,
      'modelNumber': modelNumber,
      'status': status,
      'healthScore': healthScore,
      'temperature': temperature,
      'vibration': vibration,
      'lastInspection': lastInspection?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MachineModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return MachineModel(
      id: docId ?? map['id'] as String? ?? map['machineId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      productionLine: map['productionLine'] as String? ?? '',
      modelNumber: map['modelNumber'] as String?,
      status: map['status'] as String? ?? '',
      healthScore: (map['healthScore'] as num?)?.toDouble() ?? 0.0,
      temperature: (map['temperature'] as num?)?.toDouble(),
      vibration: (map['vibration'] as num?)?.toDouble(),
      lastInspection: _parseDateTime(map['lastInspection']),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
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
    return 'MachineModel(id: $id, name: $name, productionLine: $productionLine, modelNumber: $modelNumber, status: $status, healthScore: $healthScore, temperature: $temperature, vibration: $vibration, lastInspection: $lastInspection, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MachineModel &&
        other.id == id &&
        other.name == name &&
        other.productionLine == productionLine &&
        other.modelNumber == modelNumber &&
        other.status == status &&
        other.healthScore == healthScore &&
        other.temperature == temperature &&
        other.vibration == vibration &&
        other.lastInspection == lastInspection &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      productionLine,
      modelNumber,
      status,
      healthScore,
      temperature,
      vibration,
      lastInspection,
      createdAt,
      updatedAt,
    );
  }
}
