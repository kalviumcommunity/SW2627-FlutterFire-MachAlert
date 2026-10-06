class MachineModel {
  final String id;
  final String name;
  final String productionLine;
  final String status;
  final double healthScore;
  final double? temperature;
  final double? vibration;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MachineModel({
    required this.id,
    required this.name,
    required this.productionLine,
    required this.status,
    required this.healthScore,
    this.temperature,
    this.vibration,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'productionLine': productionLine,
      'status': status,
      'healthScore': healthScore,
      'temperature': temperature,
      'vibration': vibration,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MachineModel.fromMap(Map<String, dynamic> map) {
    return MachineModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      productionLine: map['productionLine'] as String? ?? '',
      status: map['status'] as String? ?? '',
      healthScore: (map['healthScore'] as num?)?.toDouble() ?? 0.0,
      temperature: (map['temperature'] as num?)?.toDouble(),
      vibration: (map['vibration'] as num?)?.toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
