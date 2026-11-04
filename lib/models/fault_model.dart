import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/app_constants.dart';

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
  final String? storagePath;
  final String? storageProvider;
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
    this.status = AppConstants.faultStatusOpen,
    this.imageUrl,
    this.storagePath,
    this.storageProvider,
    this.createdAt,
  });

  /// Canonical fault identifier alias for [id], matching PRD Section 15.3 schema.
  String get faultId => id;

  /// Alias for [type] to support faultType terminology.
  String get faultType => type;

  /// Returns whether an image is attached to this fault report
  /// via either [imageUrl] or permanent [storagePath].
  bool get hasImage =>
      (imageUrl != null && imageUrl!.trim().isNotEmpty) ||
      (storagePath != null && storagePath!.trim().isNotEmpty);

  /// Returns whether this fault has a recognized type according to [AppConstants.faultTypes].
  bool get hasRecognizedType => AppConstants.faultTypes.any(
    (t) => t.toLowerCase() == type.trim().toLowerCase(),
  );

  /// Returns whether this fault has a recognized severity according to [AppConstants.severities].
  bool get hasRecognizedSeverity => AppConstants.severities.any(
    (s) => s.toLowerCase() == severity.trim().toLowerCase(),
  );

  /// Returns whether this fault has a recognized status according to [AppConstants.faultStatuses].
  bool get hasRecognizedStatus => AppConstants.faultStatuses.any(
    (s) => s.toLowerCase() == status.trim().toLowerCase(),
  );

  /// Helper getters for operational statuses.
  bool get isOpen =>
      status.trim().toLowerCase() == AppConstants.faultStatusOpen.toLowerCase();

  bool get isInProgress =>
      status.trim().toLowerCase() ==
      AppConstants.faultStatusInProgress.toLowerCase();

  bool get isResolved =>
      status.trim().toLowerCase() ==
      AppConstants.faultStatusResolved.toLowerCase();

  /// Helper getters for severities.
  bool get isCriticalSeverity =>
      severity.trim().toLowerCase() ==
      AppConstants.severityCritical.toLowerCase();

  bool get isHighSeverity =>
      severity.trim().toLowerCase() == AppConstants.severityHigh.toLowerCase();

  /// Validates the current fault model instance.
  ///
  /// Returns a list of human-readable error messages for any invalid fields.
  /// An empty list indicates a valid model.
  List<String> validate() {
    final errors = <String>[];

    if (machineId.trim().isEmpty) {
      errors.add('Machine ID is required.');
    }

    if (type.trim().isEmpty) {
      errors.add('Fault type is required.');
    } else if (!hasRecognizedType) {
      errors.add(
        'Fault type "$type" is invalid. Allowed types: ${AppConstants.faultTypes.join(", ")}.',
      );
    }

    if (severity.trim().isEmpty) {
      errors.add('Severity is required.');
    } else if (!hasRecognizedSeverity) {
      errors.add(
        'Severity "$severity" is invalid. Allowed severities: ${AppConstants.severities.join(", ")}.',
      );
    }

    if (description.trim().isEmpty) {
      errors.add('Description is required.');
    }

    if (reportedBy.trim().isEmpty) {
      errors.add('Reporter UID is required.');
    }

    if (status.trim().isEmpty) {
      errors.add('Status is required.');
    } else if (!hasRecognizedStatus) {
      errors.add(
        'Status "$status" is invalid. Allowed statuses: ${AppConstants.faultStatuses.join(", ")}.',
      );
    }

    return errors;
  }

  /// Whether all required fields and enum values are valid.
  bool get isValid => validate().isEmpty;

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
    String? storagePath,
    String? storageProvider,
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
      storagePath: storagePath ?? this.storagePath,
      storageProvider: storageProvider ?? this.storageProvider,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'faultId': id,
      'machineId': machineId,
      'machineName': machineName,
      'type': type,
      'severity': severity,
      'description': description,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'status': status,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'storageProvider': storageProvider,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Converts this [FaultModel] to a Firestore-compatible document map.
  ///
  /// Serializes date fields as Firestore [Timestamp] instances and handles
  /// server timestamps for new document creation.
  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'id': id,
      'faultId': id,
      'machineId': machineId,
      'machineName': machineName,
      'type': type,
      'severity': severity,
      'description': description,
      'reportedBy': reportedBy,
      'reportedByName': reportedByName,
      'status': status,
      'imageUrl': imageUrl,
      if (storagePath != null) 'storagePath': storagePath,
      if (storageProvider != null) 'storageProvider': storageProvider,
    };

    if (!isUpdate) {
      map['createdAt'] = createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp();
    }

    return map;
  }

  factory FaultModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final resolvedId = _resolveId(map, docId);

    final rawImageUrl = map['imageUrl']?.toString();
    var storagePath = map['storagePath']?.toString();
    var storageProvider = map['storageProvider']?.toString();

    // Backward-compatibility: if legacy imageUrl contains a Supabase signed URL, recover permanent storagePath
    if ((storagePath == null || storagePath.isEmpty) &&
        rawImageUrl != null &&
        rawImageUrl.contains('supabase.co') &&
        (rawImageUrl.contains('/object/sign/') || rawImageUrl.contains('token='))) {
      final bucketIdx = rawImageUrl.indexOf('/fault-images/');
      if (bucketIdx != -1) {
        final pathWithQuery = rawImageUrl.substring(bucketIdx + '/fault-images/'.length);
        storagePath = pathWithQuery.split('?').first;
        storageProvider ??= AppConstants.storageProviderSupabase;
      }
    }

    return FaultModel(
      id: resolvedId,
      machineId: map['machineId']?.toString() ?? '',
      machineName: map['machineName']?.toString(),
      type: map['type']?.toString() ?? '',
      severity: map['severity']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      reportedBy: map['reportedBy']?.toString() ?? '',
      reportedByName: map['reportedByName']?.toString(),
      status: map['status']?.toString() ?? AppConstants.faultStatusOpen,
      imageUrl: rawImageUrl,
      storagePath: storagePath,
      storageProvider: storageProvider,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Resolves the document identifier with explicit fallback precedence:
  /// 1. Supplied [docId] parameter
  /// 2. Map `faultId` key
  /// 3. Map `id` key
  /// 4. Empty string fallback
  static String _resolveId(Map<String, dynamic> map, [String? docId]) {
    if (docId != null && docId.trim().isNotEmpty) {
      return docId.trim();
    }
    final faultId = map['faultId']?.toString().trim();
    if (faultId != null && faultId.isNotEmpty) {
      return faultId;
    }
    final id = map['id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    return '';
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
    return 'FaultModel(id: $id, machineId: $machineId, machineName: $machineName, type: $type, severity: $severity, description: $description, reportedBy: $reportedBy, reportedByName: $reportedByName, status: $status, imageUrl: $imageUrl, storagePath: $storagePath, storageProvider: $storageProvider, createdAt: $createdAt)';
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
        other.storagePath == storagePath &&
        other.storageProvider == storageProvider &&
        (other.createdAt == createdAt ||
            (other.createdAt != null &&
                createdAt != null &&
                other.createdAt!.isAtSameMomentAs(createdAt!)));
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
      storagePath,
      storageProvider,
      createdAt?.millisecondsSinceEpoch,
    );
  }
}
