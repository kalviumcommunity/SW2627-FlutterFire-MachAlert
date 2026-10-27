import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/fault_model.dart';
import '../utils/app_constants.dart';

/// Exception thrown by [FaultService] operations when Firestore operations fail
/// or business validation rules are violated.
class FaultServiceException implements Exception {
  static const String defaultErrorMessage =
      'A fault database error occurred. Please try again.';

  /// The error code preserved from Firebase Firestore or generated for validation errors.
  final String code;

  /// A safe, user-readable error message.
  final String message;

  FaultServiceException({required this.code, String? message})
    : message = message ?? messageForErrorCode(code);

  /// Creates a [FaultServiceException] from a [FirebaseException].
  factory FaultServiceException.fromFirebaseException(
    FirebaseException exception,
  ) {
    final normalizedCode = exception.code.toLowerCase().replaceAll('_', '-');
    return FaultServiceException(
      code: normalizedCode,
      message: messageForErrorCode(normalizedCode),
    );
  }

  /// Maps Firestore and validation error codes to safe, user-readable messages.
  static String messageForErrorCode(String code) {
    switch (code.toLowerCase().replaceAll('_', '-')) {
      case 'permission-denied':
        return 'You do not have permission to access or report this fault.';
      case 'not-found':
        return 'The requested fault was not found.';
      case 'already-exists':
        return 'A fault with this ID already exists.';
      case 'unavailable':
        return 'Firestore is currently unavailable. Please check your network connection.';
      case 'deadline-exceeded':
        return 'The operation timed out. Please try again.';
      case 'unauthenticated':
        return 'User is not authenticated. Please log in.';
      case 'invalid-argument':
        return 'Invalid fault data provided.';
      case 'invalid-id':
        return 'A valid fault identifier is required.';
      case 'invalid-machine-id':
        return 'Machine ID is required.';
      case 'invalid-type':
        return 'The specified fault type is invalid.';
      case 'invalid-severity':
        return 'The specified fault severity is invalid.';
      case 'invalid-description':
        return 'Description is required.';
      case 'invalid-status':
        return 'The specified fault status is invalid.';
      default:
        return defaultErrorMessage;
    }
  }

  @override
  String toString() => 'FaultServiceException(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaultServiceException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Service wrapper around Cloud Firestore for managing fault documents
/// in the `faults` collection (`faults/{faultId}`).
class FaultService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  /// Creates a [FaultService] instance.
  ///
  /// Optionally accepts [FirebaseFirestore] and [FirebaseAuth] instances for dependency injection in tests.
  /// Defaults to [FirebaseFirestore.instance] and [FirebaseAuth.instance].
  FaultService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Internal access to the underlying [FirebaseFirestore] instance.
  FirebaseFirestore get firestore => _firestore;

  /// Internal access to the underlying [FirebaseAuth] instance.
  FirebaseAuth get auth => _firebaseAuth;

  /// Reference to the `faults` collection.
  CollectionReference<Map<String, dynamic>> get _faultsCollection =>
      _firestore.collection(AppConstants.faultsCollection);

  /// Returns canonical document reference for a given fault ID: `faults/{faultId}`.
  DocumentReference<Map<String, dynamic>> faultDoc(String faultId) {
    if (faultId.trim().isEmpty) {
      throw FaultServiceException(
        code: 'invalid-id',
        message: 'A non-empty fault ID is required.',
      );
    }
    return _faultsCollection.doc(faultId.trim());
  }

  /// Creates a new fault document in the `faults` collection.
  ///
  /// Requirements:
  /// - Requires an authenticated user session; derives `reportedBy` from
  ///   `FirebaseAuth.currentUser.uid`. Never trusts a caller-supplied reporter UID.
  /// - Sets the default fault status to [AppConstants.faultStatusOpen].
  /// - Validates all required fields before attempting any Firestore write.
  /// - Writes to a newly generated document ID unless conventions require otherwise.
  /// - Uses [FaultModel.toFirestoreMap] and a server timestamp for creation.
  /// - Returns the created document ID.
  ///
  /// Throws [FaultServiceException] if unauthenticated, if input validation fails,
  /// or if a Firestore network or permission error occurs.
  Future<String> addFault(FaultModel fault) async {
    // 1. Verify authenticated user
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid.trim().isEmpty) {
      throw FaultServiceException(
        code: 'unauthenticated',
        message: 'User is not authenticated. Please log in.',
      );
    }
    final reporterUid = currentUser.uid.trim();

    // 2. Validate required machine ID
    if (fault.machineId.trim().isEmpty) {
      throw FaultServiceException(
        code: 'invalid-machine-id',
        message: 'Machine ID is required.',
      );
    }

    // 3. Validate fault type
    if (fault.type.trim().isEmpty || !fault.hasRecognizedType) {
      throw FaultServiceException(
        code: 'invalid-type',
        message: fault.type.trim().isEmpty
            ? 'Fault type is required.'
            : 'Fault type "${fault.type}" is invalid. Allowed types: ${AppConstants.faultTypes.join(", ")}.',
      );
    }

    // 4. Validate severity
    if (fault.severity.trim().isEmpty || !fault.hasRecognizedSeverity) {
      throw FaultServiceException(
        code: 'invalid-severity',
        message: fault.severity.trim().isEmpty
            ? 'Severity is required.'
            : 'Severity "${fault.severity}" is invalid. Allowed severities: ${AppConstants.severities.join(", ")}.',
      );
    }

    // 5. Validate description
    if (fault.description.trim().isEmpty) {
      throw FaultServiceException(
        code: 'invalid-description',
        message: 'Description is required.',
      );
    }

    // 6. Resolve status: defaults to AppConstants.faultStatusOpen if empty
    final resolvedStatus = fault.status.trim().isEmpty
        ? AppConstants.faultStatusOpen
        : fault.status.trim();

    if (!AppConstants.faultStatuses.any(
      (s) => s.toLowerCase() == resolvedStatus.toLowerCase(),
    )) {
      throw FaultServiceException(
        code: 'invalid-status',
        message:
            'Status "$resolvedStatus" is invalid. Allowed statuses: ${AppConstants.faultStatuses.join(", ")}.',
      );
    }

    // 7. Generate a new document reference and unique ID
    final docRef = _faultsCollection.doc();
    final generatedDocId = docRef.id;

    // 8. Construct complete validated model ensuring ID, status, and derived reporter UID
    final faultToCreate = fault.copyWith(
      id: generatedDocId,
      reportedBy: reporterUid,
      status: resolvedStatus,
    );

    final validationErrors = faultToCreate.validate();
    if (validationErrors.isNotEmpty) {
      throw FaultServiceException(
        code: 'invalid-argument',
        message: validationErrors.first,
      );
    }

    // 9. Serialize to Firestore map with server timestamp
    final data = faultToCreate.toFirestoreMap(isUpdate: false);
    data['id'] = generatedDocId;
    data['faultId'] = generatedDocId;
    data['reportedBy'] = reporterUid;
    data['status'] = resolvedStatus;

    if (fault.createdAt == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    // 10. Write to Firestore
    try {
      await docRef.set(data);
      return generatedDocId;
    } on FirebaseException catch (e) {
      throw FaultServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is FaultServiceException) rethrow;
      throw FaultServiceException(
        code: 'unknown',
        message: 'Failed to add fault: $e',
      );
    }
  }

  /// Retrieves a fault document by its ID: `faults/{faultId}`.
  ///
  /// Returns `null` if the fault document does not exist.
  /// Throws [FaultServiceException] on Firestore error.
  Future<FaultModel?> getFaultById(String faultId) async {
    try {
      final docRef = faultDoc(faultId);
      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return FaultModel.fromMap(snapshot.data()!, snapshot.id);
    } on FirebaseException catch (e) {
      throw FaultServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is FaultServiceException) rethrow;
      throw FaultServiceException(
        code: 'unknown',
        message: 'Failed to retrieve fault: $e',
      );
    }
  }

  /// Helper to build a Firestore query for the faults collection with optional filters.
  ///
  /// Supports exact-match filtering by [machineId], [status], and [severity].
  /// Trims whitespace and treats null, empty, or whitespace-only values as omitted.
  Query<Map<String, dynamic>> _buildFaultsQuery({
    String? machineId,
    String? status,
    String? severity,
  }) {
    Query<Map<String, dynamic>> query = _faultsCollection;

    if (machineId != null && machineId.trim().isNotEmpty) {
      query = query.where('machineId', isEqualTo: machineId.trim());
    }

    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim());
    }

    if (severity != null && severity.trim().isNotEmpty) {
      query = query.where('severity', isEqualTo: severity.trim());
    }

    return query;
  }

  /// Retrieves a list of faults, with optional filtering by [machineId],
  /// [status], and/or [severity].
  ///
  /// Throws [FaultServiceException] on Firestore error.
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
  }) async {
    try {
      final query = _buildFaultsQuery(
        machineId: machineId,
        status: status,
        severity: severity,
      );

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => FaultModel.fromMap(doc.data(), doc.id))
          .toList();
    } on FirebaseException catch (e) {
      throw FaultServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is FaultServiceException) rethrow;
      throw FaultServiceException(
        code: 'unknown',
        message: 'Failed to retrieve faults: $e',
      );
    }
  }

  /// Streams real-time updates for the faults collection.
  ///
  /// Optionally filters by [machineId], [status], and/or [severity].
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
  }) {
    final query = _buildFaultsQuery(
      machineId: machineId,
      status: status,
      severity: severity,
    );

    return query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FaultModel.fromMap(doc.data(), doc.id))
              .toList();
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            throw FaultServiceException.fromFirebaseException(error);
          }
          if (error is FaultServiceException) {
            throw error;
          }
          throw FaultServiceException(
            code: 'unknown',
            message:
                'A real-time fault stream error occurred. Please try again.',
          );
        });
  }
}
