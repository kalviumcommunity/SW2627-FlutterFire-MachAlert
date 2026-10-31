import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/maintenance_model.dart';
import '../utils/app_constants.dart';

/// Exception thrown by [MaintenanceService] operations when Firestore operations fail
/// or business validation rules are violated.
class MaintenanceServiceException implements Exception {
  static const String defaultErrorMessage =
      'A maintenance database error occurred. Please try again.';

  /// The error code preserved from Firebase Firestore or generated for validation errors.
  final String code;

  /// A safe, user-readable error message.
  final String message;

  MaintenanceServiceException({required this.code, String? message})
    : message = message ?? messageForErrorCode(code);

  /// Creates a [MaintenanceServiceException] from a [FirebaseException].
  ///
  /// Never exposes raw internal Firebase exception messages to users.
  factory MaintenanceServiceException.fromFirebaseException(
    FirebaseException exception,
  ) {
    final normalizedCode = exception.code.toLowerCase().replaceAll('_', '-');
    return MaintenanceServiceException(
      code: normalizedCode,
      message: messageForErrorCode(normalizedCode),
    );
  }

  /// Maps Firestore and validation error codes to safe, user-readable messages.
  static String messageForErrorCode(String code) {
    switch (code.toLowerCase().replaceAll('_', '-')) {
      case 'permission-denied':
        return 'You do not have permission to access or modify this maintenance task.';
      case 'unauthenticated':
        return 'User is not authenticated. Please log in.';
      case 'not-found':
        return 'The requested maintenance task was not found.';
      case 'already-exists':
        return 'A maintenance task with this ID already exists.';
      case 'unavailable':
        return 'Firestore is currently unavailable. Please check your network connection.';
      case 'deadline-exceeded':
        return 'The operation timed out. Please try again.';
      case 'invalid-id':
        return 'A valid maintenance task identifier is required.';
      case 'invalid-machine-id':
        return 'Machine ID is required.';
      case 'invalid-technician-id':
        return 'Technician ID is required.';
      case 'invalid-priority':
        return 'The specified maintenance priority is invalid.';
      case 'invalid-status':
        return 'The specified maintenance status is invalid.';
      case 'invalid-argument':
        return 'Invalid maintenance data provided.';
      case 'unknown':
      default:
        return defaultErrorMessage;
    }
  }

  @override
  String toString() =>
      'MaintenanceServiceException(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceServiceException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Service wrapper around Cloud Firestore for managing maintenance task documents
/// in the `maintenance` collection (`maintenance/{taskId}`).
///
/// Provides reusable capabilities for:
/// - Creating new maintenance tasks with default Pending status.
/// - Retrieving tasks by document ID.
/// - Querying tasks with combined equality filters (technicianId, machineId, status, priority).
/// - Streaming real-time updates for maintenance collections.
/// - Querying and streaming assigned tasks using the authenticated user UID.
/// - Sorting tasks by priority (Critical > High > Medium > Low).
/// - Normalizing the presentation status 'Completed' used by UI screens to canonical 'Resolved'.
class MaintenanceService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  /// Presentation status alias displayed in maintenance UI screens.
  ///
  /// Mapped to canonical [AppConstants.maintenanceStatusResolved] ('Resolved')
  /// in status filters.
  static const String statusCompletedAlias = 'Completed';

  /// Creates a [MaintenanceService] instance.
  ///
  /// Optionally accepts [FirebaseFirestore] and [FirebaseAuth] instances for dependency
  /// injection in unit tests. Defaults to [FirebaseFirestore.instance] and
  /// [FirebaseAuth.instance].
  MaintenanceService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Internal access to the underlying [FirebaseFirestore] instance.
  FirebaseFirestore get firestore => _firestore;

  /// Internal access to the underlying [FirebaseAuth] instance.
  FirebaseAuth get auth => _firebaseAuth;

  /// Reference to the `maintenance` collection.
  CollectionReference<Map<String, dynamic>> get _maintenanceCollection =>
      _firestore.collection(AppConstants.maintenanceCollection);

  /// Returns canonical document reference for a given maintenance task ID: `maintenance/{taskId}`.
  ///
  /// Throws [MaintenanceServiceException] if [taskId] is blank or empty.
  DocumentReference<Map<String, dynamic>> maintenanceDoc(String taskId) {
    if (taskId.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'invalid-id',
        message: MaintenanceServiceException.messageForErrorCode('invalid-id'),
      );
    }
    return _maintenanceCollection.doc(taskId.trim());
  }

  /// Checks whether a given status matches a recognized maintenance status (case-insensitive).
  ///
  /// When [allowCompletedAlias] is true, also recognizes 'Completed' as a presentation alias.
  static bool isRecognizedStatus(
    String? status, {
    bool allowCompletedAlias = true,
  }) {
    if (status == null || status.trim().isEmpty) return false;
    final trimmed = status.trim().toLowerCase();
    if (allowCompletedAlias && trimmed == statusCompletedAlias.toLowerCase()) {
      return true;
    }
    return AppConstants.maintenanceStatuses.any(
      (s) => s.toLowerCase() == trimmed,
    );
  }

  /// Validates and normalizes a maintenance status to its canonical casing.
  ///
  /// If [allowCompletedAlias] is true (used for query filters), 'Completed' is
  /// normalized to [AppConstants.maintenanceStatusResolved] ('Resolved').
  ///
  /// Throws [MaintenanceServiceException] if [status] is null, empty, or unrecognized.
  static String validateStatus(
    String? status, {
    bool allowCompletedAlias = true,
  }) {
    if (status == null || status.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'invalid-status',
        message: MaintenanceServiceException.messageForErrorCode(
          'invalid-status',
        ),
      );
    }

    final trimmed = status.trim().toLowerCase();

    if (allowCompletedAlias && trimmed == statusCompletedAlias.toLowerCase()) {
      return AppConstants.maintenanceStatusResolved;
    }

    for (final canonical in AppConstants.maintenanceStatuses) {
      if (canonical.toLowerCase() == trimmed) {
        return canonical;
      }
    }

    throw MaintenanceServiceException(
      code: 'invalid-status',
      message:
          'Status "$status" is invalid. Allowed statuses: ${AppConstants.maintenanceStatuses.join(", ")}.',
    );
  }

  /// Normalizes a status filter value, returning `null` when omitted, null, or whitespace-only.
  ///
  /// Normalizes the UI alias 'Completed' to canonical 'Resolved'.
  /// Throws [MaintenanceServiceException] if a non-empty unrecognized status is supplied.
  static String? normalizeStatusFilter(String? status) {
    if (status == null || status.trim().isEmpty) return null;
    return validateStatus(status, allowCompletedAlias: true);
  }

  /// Checks whether a given priority matches a recognized severity (case-insensitive).
  static bool isRecognizedPriority(String? priority) {
    if (priority == null || priority.trim().isEmpty) return false;
    final trimmed = priority.trim().toLowerCase();
    return AppConstants.severities.any((p) => p.toLowerCase() == trimmed);
  }

  /// Validates and normalizes a maintenance priority to its canonical casing.
  ///
  /// Throws [MaintenanceServiceException] if [priority] is null, empty, or unrecognized.
  static String validatePriority(String? priority) {
    if (priority == null || priority.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'invalid-priority',
        message: MaintenanceServiceException.messageForErrorCode(
          'invalid-priority',
        ),
      );
    }

    final trimmed = priority.trim().toLowerCase();
    for (final canonical in AppConstants.severities) {
      if (canonical.toLowerCase() == trimmed) {
        return canonical;
      }
    }

    throw MaintenanceServiceException(
      code: 'invalid-priority',
      message:
          'Priority "$priority" is invalid. Allowed priorities: ${AppConstants.severities.join(", ")}.',
    );
  }

  /// Normalizes a priority filter value, returning `null` when omitted, null, or whitespace-only.
  ///
  /// Throws [MaintenanceServiceException] if a non-empty unrecognized priority is supplied.
  static String? normalizePriorityFilter(String? priority) {
    if (priority == null || priority.trim().isEmpty) return null;
    return validatePriority(priority);
  }

  /// Validates a non-empty machine identifier.
  static String validateMachineId(String? machineId) {
    if (machineId == null || machineId.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'invalid-machine-id',
        message: MaintenanceServiceException.messageForErrorCode(
          'invalid-machine-id',
        ),
      );
    }
    return machineId.trim();
  }

  /// Validates a non-empty technician identifier.
  static String validateTechnicianId(String? technicianId) {
    if (technicianId == null || technicianId.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'invalid-technician-id',
        message: MaintenanceServiceException.messageForErrorCode(
          'invalid-technician-id',
        ),
      );
    }
    return technicianId.trim();
  }

  /// Returns sorting weight for priority ordering: Critical (0) > High (1) > Medium (2) > Low (3) > Unknown (4).
  static int priorityWeight(String? priority) {
    if (priority == null) return 4;
    switch (priority.trim().toLowerCase()) {
      case 'critical':
        return 0;
      case 'high':
        return 1;
      case 'medium':
        return 2;
      case 'low':
        return 3;
      default:
        return 4;
    }
  }

  /// Sorts maintenance tasks in priority order: Critical > High > Medium > Low.
  ///
  /// Maintains stable order among tasks with identical priority.
  /// Places tasks with unknown or legacy priority values after recognized priorities
  /// without throwing exceptions.
  static List<MaintenanceModel> sortTasksByPriority(
    List<MaintenanceModel> tasks,
  ) {
    if (tasks.length <= 1) return List<MaintenanceModel>.from(tasks);

    final indexed = List.generate(tasks.length, (i) => MapEntry(i, tasks[i]));

    indexed.sort((a, b) {
      final weightA = priorityWeight(a.value.priority);
      final weightB = priorityWeight(b.value.priority);
      final weightComp = weightA.compareTo(weightB);
      if (weightComp != 0) return weightComp;
      return a.key.compareTo(b.key);
    });

    return indexed.map((e) => e.value).toList();
  }

  /// Creates a new maintenance task document in the `maintenance` collection.
  ///
  /// Requirements:
  /// - Requires an authenticated Firebase user.
  /// - Validates non-empty `machineId` and `technicianId`.
  /// - Validates `priority` against [AppConstants.severities].
  /// - Defaults status to [AppConstants.maintenanceStatusPending].
  /// - Rejects non-Pending initial status; new assignments must begin in Pending status.
  /// - Generates a unique Firestore document ID and stores it in the `id` field.
  /// - Uses [FieldValue.serverTimestamp()] for `createdAt`.
  /// - Returns the generated document ID.
  ///
  /// Throws [MaintenanceServiceException] if validation fails or unauthenticated.
  Future<String> createMaintenanceTask(MaintenanceModel task) async {
    // 1. Verify authenticated user
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'unauthenticated',
        message: MaintenanceServiceException.messageForErrorCode(
          'unauthenticated',
        ),
      );
    }

    // 2. Validate machineId
    final validMachineId = validateMachineId(task.machineId);

    // 3. Validate technicianId
    final validTechnicianId = validateTechnicianId(task.technicianId);

    // 4. Validate priority
    final validPriority = validatePriority(task.priority);

    // 5. Resolve and validate initial status (must be Pending)
    final String initialStatus;
    if (task.status.trim().isEmpty) {
      initialStatus = AppConstants.maintenanceStatusPending;
    } else {
      final normalizedStatus = validateStatus(
        task.status,
        allowCompletedAlias: false,
      );
      if (normalizedStatus != AppConstants.maintenanceStatusPending) {
        throw MaintenanceServiceException(
          code: 'invalid-status',
          message: 'New maintenance tasks must start with Pending status.',
        );
      }
      initialStatus = AppConstants.maintenanceStatusPending;
    }

    // 6. Trim optional string fields
    final trimmedMachineName = task.machineName?.trim();
    final trimmedFaultId = task.faultId?.trim();
    final trimmedTechnicianName = task.technicianName?.trim();
    final trimmedNotes = task.notes?.trim();

    // 7. Generate unique document ID
    final docRef = _maintenanceCollection.doc();
    final generatedDocId = docRef.id;

    // 8. Prepare document data with server timestamp
    final data = <String, dynamic>{
      'id': generatedDocId,
      'maintenanceId': generatedDocId,
      'machineId': validMachineId,
      'machineName': trimmedMachineName,
      'faultId': trimmedFaultId,
      'technicianId': validTechnicianId,
      'technicianName': trimmedTechnicianName,
      'priority': validPriority,
      'status': initialStatus,
      'notes': trimmedNotes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': null,
    };

    // 9. Write to Firestore
    try {
      await docRef.set(data);
      return generatedDocId;
    } on FirebaseException catch (e) {
      throw MaintenanceServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MaintenanceServiceException) rethrow;
      throw MaintenanceServiceException(
        code: 'unknown',
        message: MaintenanceServiceException.messageForErrorCode('unknown'),
      );
    }
  }

  /// Retrieves a single maintenance task by ID: `maintenance/{taskId}`.
  ///
  /// Returns `null` if the document does not exist.
  /// Throws [MaintenanceServiceException] if [taskId] is invalid or on Firestore error.
  Future<MaintenanceModel?> getMaintenanceTaskById(String taskId) async {
    try {
      final docRef = maintenanceDoc(taskId);
      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return MaintenanceModel.fromMap(snapshot.data()!, snapshot.id);
    } on FirebaseException catch (e) {
      throw MaintenanceServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MaintenanceServiceException) rethrow;
      throw MaintenanceServiceException(
        code: 'unknown',
        message: MaintenanceServiceException.messageForErrorCode('unknown'),
      );
    }
  }

  /// Builds a Firestore query for the `maintenance` collection with optional equality filters.
  ///
  /// Trims whitespace and ignores null, empty, or whitespace-only filters.
  /// Normalizes the UI alias 'Completed' to canonical 'Resolved'.
  Query<Map<String, dynamic>> _buildMaintenanceQuery({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) {
    Query<Map<String, dynamic>> query = _maintenanceCollection;

    if (technicianId != null && technicianId.trim().isNotEmpty) {
      query = query.where('technicianId', isEqualTo: technicianId.trim());
    }

    if (machineId != null && machineId.trim().isNotEmpty) {
      query = query.where('machineId', isEqualTo: machineId.trim());
    }

    final normalizedStatus = normalizeStatusFilter(status);
    if (normalizedStatus != null) {
      query = query.where('status', isEqualTo: normalizedStatus);
    }

    final normalizedPriority = normalizePriorityFilter(priority);
    if (normalizedPriority != null) {
      query = query.where('priority', isEqualTo: normalizedPriority);
    }

    return query;
  }

  /// Retrieves a list of maintenance tasks matching the optional filters.
  ///
  /// Supports combined Firestore equality filters on:
  /// - [technicianId]
  /// - [machineId]
  /// - [status] (supports 'Completed' alias mapped to 'Resolved')
  /// - [priority]
  ///
  /// Returns tasks sorted by priority (Critical > High > Medium > Low).
  /// Throws [MaintenanceServiceException] on Firestore or validation failure.
  Future<List<MaintenanceModel>> getMaintenanceTasks({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) async {
    try {
      final query = _buildMaintenanceQuery(
        technicianId: technicianId,
        machineId: machineId,
        status: status,
        priority: priority,
      );

      final snapshot = await query.get();
      final tasks = snapshot.docs
          .map((doc) => MaintenanceModel.fromMap(doc.data(), doc.id))
          .toList();

      return sortTasksByPriority(tasks);
    } on FirebaseException catch (e) {
      throw MaintenanceServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is MaintenanceServiceException) rethrow;
      throw MaintenanceServiceException(
        code: 'unknown',
        message: MaintenanceServiceException.messageForErrorCode('unknown'),
      );
    }
  }

  /// Streams real-time updates for maintenance tasks matching the optional filters.
  ///
  /// Uses Firestore `.snapshots()`. Every emitted list is sorted by priority
  /// (Critical > High > Medium > Low) with stable ordering.
  ///
  /// Throws [MaintenanceServiceException] on stream failure.
  Stream<List<MaintenanceModel>> streamMaintenanceTasks({
    String? technicianId,
    String? machineId,
    String? status,
    String? priority,
  }) {
    try {
      final query = _buildMaintenanceQuery(
        technicianId: technicianId,
        machineId: machineId,
        status: status,
        priority: priority,
      );

      return query
          .snapshots()
          .map((snapshot) {
            final tasks = snapshot.docs
                .map((doc) => MaintenanceModel.fromMap(doc.data(), doc.id))
                .toList();
            return sortTasksByPriority(tasks);
          })
          .handleError((Object error) {
            if (error is FirebaseException) {
              throw MaintenanceServiceException.fromFirebaseException(error);
            }
            if (error is MaintenanceServiceException) {
              throw error;
            }
            throw MaintenanceServiceException(
              code: 'unknown',
              message: MaintenanceServiceException.messageForErrorCode(
                'unknown',
              ),
            );
          });
    } on MaintenanceServiceException {
      rethrow;
    } catch (e) {
      throw MaintenanceServiceException(
        code: 'unknown',
        message: MaintenanceServiceException.messageForErrorCode('unknown'),
      );
    }
  }

  /// Retrieves maintenance tasks assigned to the currently authenticated technician.
  ///
  /// Derives `technicianId` strictly from [FirebaseAuth.currentUser.uid].
  /// Never trusts a caller-supplied technician UID.
  ///
  /// Throws [MaintenanceServiceException] with code 'unauthenticated' if no user is signed in.
  Future<List<MaintenanceModel>> getAssignedMaintenanceTasks({
    String? status,
    String? machineId,
    String? priority,
  }) async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'unauthenticated',
        message: MaintenanceServiceException.messageForErrorCode(
          'unauthenticated',
        ),
      );
    }

    return getMaintenanceTasks(
      technicianId: currentUser.uid.trim(),
      status: status,
      machineId: machineId,
      priority: priority,
    );
  }

  /// Streams real-time maintenance tasks assigned to the currently authenticated technician.
  ///
  /// Derives `technicianId` strictly from [FirebaseAuth.currentUser.uid].
  /// Never trusts a caller-supplied technician UID.
  ///
  /// Throws [MaintenanceServiceException] with code 'unauthenticated' if no user is signed in.
  Stream<List<MaintenanceModel>> streamAssignedMaintenanceTasks({
    String? status,
    String? machineId,
    String? priority,
  }) {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null || currentUser.uid.trim().isEmpty) {
      throw MaintenanceServiceException(
        code: 'unauthenticated',
        message: MaintenanceServiceException.messageForErrorCode(
          'unauthenticated',
        ),
      );
    }

    return streamMaintenanceTasks(
      technicianId: currentUser.uid.trim(),
      status: status,
      machineId: machineId,
      priority: priority,
    );
  }
}
