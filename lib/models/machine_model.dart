import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_constants.dart';

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

  /// Canonical machine identifier alias for [id], matching PRD schema.
  String get machineId => id;

  /// Returns whether this machine has a recognized operational status.
  bool get hasRecognizedStatus => AppConstants.machineStatuses.any(
    (s) => s.toLowerCase() == status.trim().toLowerCase(),
  );

  /// Helper getters for operational statuses.
  bool get isOperational =>
      status.trim().toLowerCase() ==
      AppConstants.machineStatusOperational.toLowerCase();

  bool get isWarning =>
      status.trim().toLowerCase() ==
      AppConstants.machineStatusWarning.toLowerCase();

  bool get isCritical =>
      status.trim().toLowerCase() ==
      AppConstants.machineStatusCritical.toLowerCase();

  bool get isUnderMaintenance =>
      status.trim().toLowerCase() ==
      AppConstants.machineStatusUnderMaintenance.toLowerCase();

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
      'machineId': id,
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

  /// Converts this [MachineModel] to a Firestore-compatible document map.
  ///
  /// Serializes date fields as Firestore [Timestamp] instances and handles
  /// server timestamps for creation and update timestamps.
  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'id': id,
      'machineId': id,
      'name': name,
      'productionLine': productionLine,
      'modelNumber': modelNumber?.trim(),
      'status': status,
      'healthScore': healthScore,
      'temperature': temperature,
      'vibration': vibration,
      'lastInspection': lastInspection != null
          ? Timestamp.fromDate(lastInspection!)
          : null,
    };

    if (!isUpdate) {
      map['createdAt'] = createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp();
    }

    map['updatedAt'] = updatedAt != null
        ? Timestamp.fromDate(updatedAt!)
        : FieldValue.serverTimestamp();

    return map;
  }

  factory MachineModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final resolvedId = _resolveId(map, docId);

    return MachineModel(
      id: resolvedId,
      name: map['name']?.toString() ?? '',
      productionLine: map['productionLine']?.toString() ?? '',
      modelNumber: map['modelNumber']?.toString(),
      status: map['status']?.toString() ?? '',
      healthScore: _parseDouble(map['healthScore']) ?? 0.0,
      temperature: _parseDouble(map['temperature']),
      vibration: _parseDouble(map['vibration']),
      lastInspection: _parseDateTime(map['lastInspection']),
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  /// Constructs a [MachineModel] from a Firestore [DocumentSnapshot].
  factory MachineModel.fromFirestore(DocumentSnapshot snapshot) {
    final data =
        snapshot.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return MachineModel.fromMap(data, snapshot.id);
  }

  static String _resolveId(Map<String, dynamic> map, [String? docId]) {
    if (docId != null && docId.trim().isNotEmpty) {
      return docId.trim();
    }
    final rawId = map['id'] ?? map['machineId'];
    if (rawId != null) {
      final str = rawId.toString().trim();
      if (str.isNotEmpty) return str;
    }
    final fallback = map['machineId'] ?? map['id'];
    if (fallback != null) {
      final str = fallback.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return '';
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
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
