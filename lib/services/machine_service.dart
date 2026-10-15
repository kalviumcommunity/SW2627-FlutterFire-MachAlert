import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/machine_model.dart';
import '../utils/app_constants.dart';

/// Exception thrown by [MachineService] operations when Firestore operations fail
/// or business validation rules are violated.
class MachineServiceException implements Exception {
  static const String defaultErrorMessage =
      'A machine database error occurred. Please try again.';

  /// The error code preserved from Firebase Firestore or generated for validation errors.
  final String code;

  /// A safe, user-readable error message.
  final String message;

  MachineServiceException({required this.code, String? message})
    : message = message ?? messageForErrorCode(code);

  /// Creates a [MachineServiceException] from a [FirebaseException].
  factory MachineServiceException.fromFirebaseException(
    FirebaseException exception,
  ) {
    return MachineServiceException(
      code: exception.code,
      message: messageForErrorCode(exception.code),
    );
  }

  /// Maps Firestore and validation error codes to safe, user-readable messages.
  static String messageForErrorCode(String code) {
    switch (code) {
      case 'permission-denied':
        return 'You do not have permission to access or modify this machine.';
      case 'not-found':
        return 'The requested machine was not found.';
      case 'already-exists':
        return 'A machine with this ID already exists.';
      case 'unavailable':
        return 'Firestore is currently unavailable. Please check your network connection.';
      case 'deadline-exceeded':
        return 'The operation timed out. Please try again.';
      case 'unauthenticated':
        return 'User is not authenticated. Please log in.';
      case 'invalid-argument':
        return 'Invalid machine data provided.';
      case 'invalid-id':
        return 'A valid machine identifier is required.';
      case 'invalid-name':
        return 'A valid machine name is required.';
      case 'invalid-line':
        return 'A valid production line is required.';
      case 'invalid-status':
        return 'The specified machine status is invalid. Allowed statuses are Operational, Warning, Critical, or Under Maintenance.';
      default:
        return defaultErrorMessage;
    }
  }

  @override
  String toString() =>
      'MachineServiceException(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineServiceException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Service wrapper around Cloud Firestore for managing machine documents
/// in the `machines` collection (`machines/{machineId}`).
class MachineService {
  final FirebaseFirestore _firestore;

  /// Canonical recognized operational statuses for machines.
  static const Set<String> recognizedStatuses = {
    AppConstants.machineStatusOperational,
    AppConstants.machineStatusWarning,
    AppConstants.machineStatusCritical,
    AppConstants.machineStatusUnderMaintenance,
  };

  /// Creates a [MachineService] instance.
  ///
  /// Optionally accepts a [FirebaseFirestore] instance for dependency injection in tests.
  /// Defaults to [FirebaseFirestore.instance].
  MachineService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Internal access to the underlying [FirebaseFirestore] instance.
  FirebaseFirestore get firestore => _firestore;

  /// Reference to the `machines` collection.
  CollectionReference<Map<String, dynamic>> get _machinesCollection =>
      _firestore.collection(AppConstants.machinesCollection);

  /// Returns canonical document reference for a given machine ID: `machines/{machineId}`.
  DocumentReference<Map<String, dynamic>> machineDoc(String machineId) {
    if (machineId.trim().isEmpty) {
      throw MachineServiceException(
        code: 'invalid-id',
        message: 'A non-empty machine ID is required.',
      );
    }
    return _machinesCollection.doc(machineId.trim());
  }

  /// Checks whether a given status string matches one of the recognized statuses (case-insensitive).
  static bool isRecognizedStatus(String? status) {
    if (status == null) return false;
    final trimmed = status.trim().toLowerCase();
    return recognizedStatuses.any((s) => s.toLowerCase() == trimmed);
  }

  /// Validates and normalizes a machine status to its canonical casing.
  ///
  /// Throws [MachineServiceException] if status is null, empty, or unrecognized.
  static String validateStatus(String? status) {
    if (status == null || status.trim().isEmpty) {
      throw MachineServiceException(
        code: 'invalid-status',
        message: 'A machine status is required.',
      );
    }
    final trimmed = status.trim().toLowerCase();
    for (final canonical in recognizedStatuses) {
      if (canonical.toLowerCase() == trimmed) {
        return canonical;
      }
    }
    throw MachineServiceException(
      code: 'invalid-status',
      message:
          'Status "$status" is invalid. Allowed statuses are Operational, Warning, Critical, or Under Maintenance.',
    );
  }

  /// Validates a non-empty machine identifier.
  static String validateId(String? id) {
    if (id == null || id.trim().isEmpty) {
      throw MachineServiceException(
        code: 'invalid-id',
        message: 'A non-empty machine ID is required.',
      );
    }
    return id.trim();
  }

  /// Validates a non-empty machine name.
  static String validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      throw MachineServiceException(
        code: 'invalid-name',
        message: 'A non-empty machine name is required.',
      );
    }
    return name.trim();
  }

  /// Validates a non-empty production line name.
  static String validateProductionLine(String? line) {
    if (line == null || line.trim().isEmpty) {
      throw MachineServiceException(
        code: 'invalid-line',
        message: 'A non-empty production line is required.',
      );
    }
    return line.trim();
  }

  /// Adds a machine document to the `machines` collection at `machines/{machine.id}`.
  ///
  /// Throws [MachineServiceException] if inputs are invalid or Firestore operation fails.
  Future<void> addMachine(MachineModel machine) async {
    try {
      final validId = validateId(machine.id);
      final validName = validateName(machine.name);
      final validLine = validateProductionLine(machine.productionLine);
      final validStatus = validateStatus(machine.status);

      final docRef = machineDoc(validId);

      final data = <String, dynamic>{
        'id': validId,
        'machineId': validId,
        'name': validName,
        'productionLine': validLine,
        'modelNumber': machine.modelNumber?.trim(),
        'status': validStatus,
        'healthScore': machine.healthScore,
        'temperature': machine.temperature,
        'vibration': machine.vibration,
        'lastInspection': machine.lastInspection != null
            ? Timestamp.fromDate(machine.lastInspection!)
            : null,
        'createdAt': machine.createdAt != null
            ? Timestamp.fromDate(machine.createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);
    } on FirebaseException catch (e) {
      throw MachineServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MachineServiceException) rethrow;
      throw MachineServiceException(
        code: 'unknown',
        message: 'Failed to add machine: $e',
      );
    }
  }

  /// Creates a machine document from a raw data map.
  ///
  /// If `id` or `machineId` is not provided, an auto-generated Firestore document ID is used.
  Future<MachineModel> createMachineFromMap(Map<String, dynamic> data) async {
    try {
      final docId =
          (data['id'] as String?)?.trim() ??
          (data['machineId'] as String?)?.trim() ??
          _machinesCollection.doc().id;

      final machine = MachineModel.fromMap(data, docId);
      await addMachine(machine);
      return machine;
    } on FirebaseException catch (e) {
      throw MachineServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MachineServiceException) rethrow;
      throw MachineServiceException(
        code: 'unknown',
        message: 'Failed to create machine: $e',
      );
    }
  }

  /// Retrieves a machine by its document ID: `machines/{machineId}`.
  ///
  /// Returns `null` if the machine does not exist.
  /// Throws [MachineServiceException] on Firestore error.
  Future<MachineModel?> getMachineById(String machineId) async {
    try {
      final docRef = machineDoc(machineId);
      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return MachineModel.fromMap(snapshot.data()!, snapshot.id);
    } on FirebaseException catch (e) {
      throw MachineServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MachineServiceException) rethrow;
      throw MachineServiceException(
        code: 'unknown',
        message: 'Failed to retrieve machine: $e',
      );
    }
  }

  /// Alias for [getMachineById].
  Future<MachineModel?> getMachine(String machineId) =>
      getMachineById(machineId);

  /// Checks whether a machine document exists at `machines/{machineId}`.
  Future<bool> machineExists(String machineId) async {
    try {
      final docRef = machineDoc(machineId);
      final snapshot = await docRef.get();
      return snapshot.exists;
    } on FirebaseException catch (e) {
      throw MachineServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MachineServiceException) rethrow;
      throw MachineServiceException(
        code: 'unknown',
        message: 'Failed to check machine existence: $e',
      );
    }
  }

  /// Retrieves a list of machines, with optional filtering by [productionLine] and/or [status].
  ///
  /// Throws [MachineServiceException] on Firestore error.
  Future<List<MachineModel>> getMachines({
    String? productionLine,
    String? status,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _machinesCollection;

      if (productionLine != null && productionLine.trim().isNotEmpty) {
        query = query.where('productionLine', isEqualTo: productionLine.trim());
      }

      if (status != null && status.trim().isNotEmpty) {
        query = query.where('status', isEqualTo: validateStatus(status));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => MachineModel.fromMap(doc.data(), doc.id))
          .toList();
    } on FirebaseException catch (e) {
      throw MachineServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MachineServiceException) rethrow;
      throw MachineServiceException(
        code: 'unknown',
        message: 'Failed to retrieve machines: $e',
      );
    }
  }

  /// Alias for [getMachines].
  Future<List<MachineModel>> getMachineList({
    String? productionLine,
    String? status,
  }) => getMachines(productionLine: productionLine, status: status);

  /// Updates arbitrary machine fields for `machines/{machineId}`.
  ///
  /// Validates [machineId] and checks that [fields] is not empty.
  /// If [fields] contains a 'status' key, validates that it is a recognized status.
  /// Automatically sets `updatedAt` to `FieldValue.serverTimestamp()`.
  ///
  /// Throws [MachineServiceException] on failure.
  Future<void> updateMachine(
    String machineId,
    Map<String, dynamic> fields,
  ) async {
    try {
      final docRef = machineDoc(machineId);

      if (fields.isEmpty) {
        throw MachineServiceException(
          code: 'invalid-argument',
          message: 'No fields provided to update.',
        );
      }

      final updates = Map<String, dynamic>.from(fields);

      if (updates.containsKey('status')) {
        updates['status'] = validateStatus(updates['status'] as String?);
      }

      if (updates.containsKey('name')) {
        updates['name'] = validateName(updates['name'] as String?);
      }

      if (updates.containsKey('productionLine')) {
        updates['productionLine'] = validateProductionLine(
          updates['productionLine'] as String?,
        );
      }

      if (updates.containsKey('lastInspection') &&
          updates['lastInspection'] is DateTime) {
        updates['lastInspection'] = Timestamp.fromDate(
          updates['lastInspection'] as DateTime,
        );
      }

      updates['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.update(updates);
    } on FirebaseException catch (e) {
      throw MachineServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MachineServiceException) rethrow;
      throw MachineServiceException(
        code: 'unknown',
        message: 'Failed to update machine: $e',
      );
    }
  }

  /// Updates only the operational status of a machine at `machines/{machineId}`.
  ///
  /// Throws [MachineServiceException] if status is invalid or update fails.
  Future<void> updateMachineStatus(String machineId, String newStatus) async {
    final validStatus = validateStatus(newStatus);
    await updateMachine(machineId, {'status': validStatus});
  }

  /// Deletes a machine document from `machines/{machineId}`.
  ///
  /// Throws [MachineServiceException] if deletion fails.
  Future<void> deleteMachine(String machineId) async {
    try {
      final docRef = machineDoc(machineId);
      await docRef.delete();
    } on FirebaseException catch (e) {
      throw MachineServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MachineServiceException) rethrow;
      throw MachineServiceException(
        code: 'unknown',
        message: 'Failed to delete machine: $e',
      );
    }
  }

  /// Streams real-time updates for the machine collection.
  ///
  /// Optionally filters by [productionLine] and/or [status].
  Stream<List<MachineModel>> streamMachines({
    String? productionLine,
    String? status,
  }) {
    Query<Map<String, dynamic>> query = _machinesCollection;

    if (productionLine != null && productionLine.trim().isNotEmpty) {
      query = query.where('productionLine', isEqualTo: productionLine.trim());
    }

    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: validateStatus(status));
    }

    return query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MachineModel.fromMap(doc.data(), doc.id))
              .toList();
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            throw MachineServiceException.fromFirebaseException(error);
          }
          throw MachineServiceException(
            code: 'unknown',
            message: 'Stream error: $error',
          );
        });
  }

  /// Streams real-time updates for a single machine at `machines/{machineId}`.
  ///
  /// Emits `null` if the document does not exist.
  Stream<MachineModel?> streamMachine(String machineId) {
    final docRef = machineDoc(machineId);
    return docRef
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return null;
          }
          return MachineModel.fromMap(snapshot.data()!, snapshot.id);
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            throw MachineServiceException.fromFirebaseException(error);
          }
          throw MachineServiceException(
            code: 'unknown',
            message: 'Stream error: $error',
          );
        });
  }

  /// Alias for [streamMachine].
  Stream<MachineModel?> streamMachineById(String machineId) =>
      streamMachine(machineId);
}
