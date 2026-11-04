import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/fault_model.dart';
import '../utils/app_constants.dart';
import '../utils/supabase_config.dart';
import 'storage_service.dart';

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

  /// Extracts the permanent storage path from a Supabase storage URL (signed or public).
  static String extractStoragePath(String url, {String bucket = 'fault-images'}) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final segments = uri.pathSegments;
      final bucketIdx = segments.indexOf(bucket);
      if (bucketIdx != -1 && bucketIdx + 1 < segments.length) {
        return segments.sublist(bucketIdx + 1).join('/');
      }
    }
    final match = RegExp('$bucket/(.+?)(\\?|\$)').firstMatch(url);
    if (match != null && match.group(1) != null) {
      return match.group(1)!;
    }
    return url;
  }

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

    // 8. Resolve permanent storagePath and storageProvider metadata.
    // Ensure expiring Supabase signed URLs are NOT stored in Firestore as permanent image references.
    String? permanentImageUrl = fault.imageUrl;
    String? permanentStoragePath = fault.storagePath;
    String? permanentStorageProvider = fault.storageProvider;

    final isSupabaseExpiringUrl = permanentImageUrl != null &&
        permanentImageUrl.contains('supabase.co') &&
        (permanentImageUrl.contains('/object/sign/') || permanentImageUrl.contains('token='));

    if (isSupabaseExpiringUrl) {
      permanentStoragePath ??= extractStoragePath(permanentImageUrl);
      permanentStorageProvider = AppConstants.storageProviderSupabase;
      permanentImageUrl = null; // Do NOT store expiring signed URL in Firestore
    } else if (permanentStoragePath != null && permanentStoragePath.trim().isNotEmpty) {
      permanentStorageProvider ??= AppConstants.storageProviderSupabase;
      if (permanentStorageProvider == AppConstants.storageProviderSupabase) {
        permanentImageUrl = null;
      }
    } else if (permanentImageUrl != null && permanentImageUrl.trim().isNotEmpty) {
      permanentStorageProvider ??= AppConstants.storageProviderFirebase;
    }

    // 9. Resolve reportedByName following Priority:
    // 1. Caller-supplied reportedByName (if valid, non-empty, and not equal to a raw UID)
    // 2. Firestore users/{uid} displayName
    // 3. Firestore users/{uid} name
    // 4. Firebase Auth displayName
    // 5. Firebase Auth email as last meaningful fallback
    String? resolvedReportedByName;
    final callerName = fault.reportedByName?.trim();
    if (callerName != null &&
        callerName.isNotEmpty &&
        callerName != reporterUid &&
        !_isRawUid(callerName)) {
      resolvedReportedByName = callerName;
    } else {
      resolvedReportedByName =
          await _resolveReporterName(reporterUid, currentUser);
    }

    // 10. Construct complete validated model ensuring ID, status, and derived reporter UID and name
    final faultToCreate = fault.copyWith(
      id: generatedDocId,
      reportedBy: reporterUid,
      reportedByName: resolvedReportedByName,
      status: resolvedStatus,
      imageUrl: permanentImageUrl,
      storagePath: permanentStoragePath,
      storageProvider: permanentStorageProvider,
    );

    final validationErrors = faultToCreate.validate();
    if (validationErrors.isNotEmpty) {
      throw FaultServiceException(
        code: 'invalid-argument',
        message: validationErrors.first,
      );
    }

    // 11. Serialize to Firestore map with server timestamp
    final data = faultToCreate.toFirestoreMap(isUpdate: false);
    data['id'] = generatedDocId;
    data['faultId'] = generatedDocId;
    data['reportedBy'] = reporterUid;
    data['reportedByName'] = resolvedReportedByName;
    data['status'] = resolvedStatus;
    data['imageUrl'] = permanentImageUrl;
    if (permanentStoragePath != null) {
      data['storagePath'] = permanentStoragePath;
    }
    if (permanentStorageProvider != null) {
      data['storageProvider'] = permanentStorageProvider;
    }

    if (fault.createdAt == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    // 12. Write to Firestore
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

  /// Resolves the reporter display name from Firestore profile or Firebase Auth session.
  Future<String?> _resolveReporterName(String uid, User? currentUser) async {
    // 1. Retrieve trusted Firestore profile from users/{uid}
    try {
      final docSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        final displayName = data['displayName']?.toString().trim();
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
        final name = data['name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    } catch (_) {}

    // 2. Firebase Auth displayName
    try {
      final authDisplayName = currentUser?.displayName?.trim();
      if (authDisplayName != null && authDisplayName.isNotEmpty) {
        return authDisplayName;
      }
    } catch (_) {}

    // 3. Firebase Auth email
    try {
      final authEmail = currentUser?.email?.trim();
      if (authEmail != null && authEmail.isNotEmpty) {
        return authEmail;
      }
    } catch (_) {}

    return null;
  }

  /// Checks whether [value] matches typical raw Firebase UID format.
  static bool _isRawUid(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 20 &&
        !trimmed.contains(' ') &&
        !trimmed.contains('@') &&
        RegExp(r'^[a-zA-Z0-9_-]{20,}$').hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  /// Dynamically resolves a displayable image URL for [fault].
  ///
  /// - Enforces role-based image access policy:
  ///   - Operators are strictly prohibited from viewing foreign operators' private fault images.
  ///   - Managers and technicians retain plant-wide authorized access.
  /// - If the fault has a private [storagePath] under Supabase, dynamically generates
  ///   a fresh signed URL for secure viewing.
  /// - If the fault has an existing [imageUrl] (Firebase Storage permanent record),
  ///   returns it directly, ensuring historical fault images continue to load.
  Future<String?> getFaultImageUrl(
    FaultModel fault, {
    StorageService? storageService,
    int expiresInSeconds = 3600,
    String? callerRole,
    String? callerUid,
  }) async {
    if (!fault.hasImage) return null;

    // Role-based image access authorization
    final uid = (callerUid != null && callerUid.trim().isNotEmpty)
        ? callerUid.trim()
        : _firebaseAuth.currentUser?.uid.trim();

    String? role = callerRole?.trim().toLowerCase();
    if (role == null && uid != null && uid.isNotEmpty) {
      try {
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          role = userDoc.data()!['role']?.toString().trim().toLowerCase();
        }
      } catch (_) {}
    }

    if (role == AppConstants.roleOperator && uid != null) {
      final reporter = fault.reportedBy.trim();
      if (reporter.isNotEmpty && reporter != uid) {
        // Operators cannot read foreign operators' private fault images
        return null;
      }
    }

    // 1. Dynamic signed URL generation for Supabase private storage
    if (fault.storageProvider == AppConstants.storageProviderSupabase ||
        (fault.storagePath != null && fault.storagePath!.trim().isNotEmpty)) {
      final path = fault.storagePath!;
      if (storageService != null) {
        return await storageService.getSignedUrl(
          path,
          expiresInSeconds: expiresInSeconds,
        );
      }
      if (SupabaseConfig.isConfigured && SupabaseConfig.client != null) {
        try {
          return await SupabaseConfig.client!.storage
              .from(SupabaseConfig.faultImagesBucket)
              .createSignedUrl(path, expiresInSeconds);
        } catch (e) {
          debugPrint('[FaultService] Failed to generate Supabase signed URL: $e');
        }
      }
    }

    // 2. Existing permanent imageUrl (Firebase Storage or direct URL)
    if (fault.imageUrl != null && fault.imageUrl!.trim().isNotEmpty) {
      return fault.imageUrl!.trim();
    }

    return null;
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
  /// Supports exact-match filtering by [machineId], [status], [severity], and [reportedBy].
  /// Trims whitespace and treats null, empty, or whitespace-only values as omitted.
  Query<Map<String, dynamic>> _buildFaultsQuery({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
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

    if (reportedBy != null && reportedBy.trim().isNotEmpty) {
      query = query.where('reportedBy', isEqualTo: reportedBy.trim());
    }

    return query;
  }

  /// Retrieves a list of faults, with optional filtering by [machineId],
  /// [status], [severity], and/or [reportedBy].
  ///
  /// Throws [FaultServiceException] on Firestore error.
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) async {
    try {
      final query = _buildFaultsQuery(
        machineId: machineId,
        status: status,
        severity: severity,
        reportedBy: reportedBy,
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
  /// Optionally filters by [machineId], [status], [severity], and/or [reportedBy].
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) {
    final query = _buildFaultsQuery(
      machineId: machineId,
      status: status,
      severity: severity,
      reportedBy: reportedBy,
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
