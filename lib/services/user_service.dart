import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../utils/app_constants.dart';

/// Exception thrown by [UserService] operations when Firestore operations fail
/// or business validation rules are violated.
class UserServiceException implements Exception {
  static const String defaultErrorMessage =
      'A database error occurred. Please try again.';

  /// The error code preserved from Firebase Firestore or generated for validation errors.
  final String code;

  /// A safe, user-readable error message.
  final String message;

  UserServiceException({required this.code, String? message})
    : message = message ?? messageForErrorCode(code);

  /// Creates a [UserServiceException] from a [FirebaseException].
  factory UserServiceException.fromFirebaseException(
    FirebaseException exception,
  ) {
    return UserServiceException(
      code: exception.code,
      message: messageForErrorCode(exception.code),
    );
  }

  /// Maps Firestore error codes to safe, user-readable messages.
  static String messageForErrorCode(String code) {
    switch (code) {
      case 'permission-denied':
        return 'You do not have permission to access or modify this profile.';
      case 'not-found':
        return 'The requested user profile was not found.';
      case 'already-exists':
        return 'A user profile with this ID already exists.';
      case 'unavailable':
        return 'Firestore is currently unavailable. Please check your network connection.';
      case 'deadline-exceeded':
        return 'The operation timed out. Please try again.';
      case 'unauthenticated':
        return 'User is not authenticated. Please log in.';
      case 'invalid-argument':
        return 'Invalid user profile data provided.';
      case 'role-escalation-denied':
        return 'Self-assignment to the manager role is not permitted.';
      case 'invalid-role':
        return 'The specified role is invalid. Allowed roles are operator, technician, or manager.';
      case 'invalid-uid':
        return 'A valid user identifier (UID) is required.';
      default:
        return defaultErrorMessage;
    }
  }

  @override
  String toString() => 'UserServiceException(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserServiceException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Service wrapper around Cloud Firestore for managing user profile documents
/// in the `users` collection (`users/{uid}`).
class UserService {
  final FirebaseFirestore _firestore;

  /// Canonical recognized roles for MachAlert.
  static const Set<String> recognizedRoles = {
    AppConstants.roleOperator,
    AppConstants.roleTechnician,
    AppConstants.roleManager,
  };

  /// Creates a [UserService] instance.
  ///
  /// Optionally accepts a [FirebaseFirestore] instance for dependency injection in tests.
  /// Defaults to [FirebaseFirestore.instance].
  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Internal access to the underlying [FirebaseFirestore] instance.
  FirebaseFirestore get firestore => _firestore;

  /// Reference to the `users` collection.
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(AppConstants.usersCollection);

  /// Returns canonical document reference for a given user UID: `users/{uid}`.
  DocumentReference<Map<String, dynamic>> userDoc(String uid) {
    if (uid.trim().isEmpty) {
      throw UserServiceException(
        code: 'invalid-uid',
        message: 'A non-empty user UID is required.',
      );
    }
    return _usersCollection.doc(uid.trim());
  }

  /// Checks whether a given role string matches one of the recognized roles.
  static bool isRecognizedRole(String? role) {
    if (role == null) return false;
    return recognizedRoles.contains(role.trim().toLowerCase());
  }

  /// Validates a role for client-side registration or update.
  ///
  /// - Empty or null defaults to [AppConstants.roleOperator].
  /// - Explicit request for [AppConstants.roleManager] throws a [UserServiceException]
  ///   to prevent client-side privilege escalation.
  /// - Any unrecognized role string throws a [UserServiceException].
  static String validateClientAssignableRole(String? role) {
    final sanitized = (role == null || role.trim().isEmpty)
        ? AppConstants.roleOperator
        : role.trim().toLowerCase();

    if (sanitized == AppConstants.roleManager) {
      throw UserServiceException(
        code: 'role-escalation-denied',
        message: 'Self-assignment to the manager role is not permitted.',
      );
    }

    if (!recognizedRoles.contains(sanitized)) {
      throw UserServiceException(
        code: 'invalid-role',
        message:
            'Role "$role" is not recognized. Recognized roles are operator, technician, or manager.',
      );
    }

    return sanitized;
  }

  /// Retrieves all users matching [role] (e.g., 'technician', 'manager', 'operator').
  ///
  /// Validates [role] against [recognizedRoles].
  /// Queries the `users` collection server-side using `.where('role', isEqualTo: sanitizedRole)`.
  /// Returns users sorted alphabetically by display name.
  /// Throws [UserServiceException] on validation or Firestore failure without exposing raw backend errors.
  Future<List<UserModel>> getUsersByRole(String role) async {
    final sanitizedRole = role.trim().toLowerCase();
    if (!recognizedRoles.contains(sanitizedRole)) {
      throw UserServiceException(
        code: 'invalid-role',
        message:
            'Role "$role" is not recognized. Recognized roles are operator, technician, or manager.',
      );
    }

    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: sanitizedRole)
          .get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      users.sort((a, b) {
        final nameA = a.name.trim().isNotEmpty ? a.name.trim() : a.email.trim();
        final nameB = b.name.trim().isNotEmpty ? b.name.trim() : b.email.trim();
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

      return users;
    } on FirebaseException catch (e) {
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: UserServiceException.messageForErrorCode('unknown'),
      );
    }
  }

  /// Retrieves a user profile by UID from `users/{uid}`.
  ///
  /// Returns `null` if the document does not exist.
  /// Note: If the document exists with an unrecognized role in Firestore,
  /// the raw role is preserved to let the UI display its safe default fallback
  /// without silent escalation.
  ///
  /// Throws [UserServiceException] if a Firestore exception occurs.
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final docRef = userDoc(uid);
      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return UserModel.fromFirestore(snapshot);
    } on FirebaseException catch (e) {
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: 'Failed to retrieve user profile: $e',
      );
    }
  }

  /// Checks if a user profile document exists at `users/{uid}`.
  Future<bool> userProfileExists(String uid) async {
    try {
      final docRef = userDoc(uid);
      final snapshot = await docRef.get();
      return snapshot.exists;
    } on FirebaseException catch (e) {
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: 'Failed to check user profile existence: $e',
      );
    }
  }

  /// Creates a user profile if one does not already exist at `users/{uid}`.
  ///
  /// If the document already exists, this method returns the existing profile
  /// **WITHOUT overwriting** any data.
  ///
  /// Newly registered profiles default to role `operator` if unspecified.
  /// Self-assignment to `manager` is rejected.
  ///
  /// Throws [UserServiceException] on failure.
  Future<UserModel> createProfileIfAbsent({
    required String uid,
    required String email,
    String? displayName,
    String? role,
  }) async {
    try {
      final trimmedUid = uid.trim();
      final docRef = userDoc(trimmedUid);

      if (kDebugMode) {
        debugPrint(
          '[UserService] createProfileIfAbsent: checking profile for UID: $trimmedUid (target: users/$trimmedUid)',
        );
      }

      final snapshot = await docRef.get();

      if (snapshot.exists && snapshot.data() != null) {
        // Profile already exists: do not overwrite!
        if (kDebugMode) {
          debugPrint(
            '[UserService] Profile already exists for UID: $trimmedUid with role: ${snapshot.data()?['role']}. Preserving existing profile.',
          );
        }
        return UserModel.fromFirestore(snapshot);
      }

      final assignedRole = validateClientAssignableRole(role);
      final trimmedName = displayName?.trim() ?? '';
      final trimmedEmail = email.trim();

      if (kDebugMode) {
        debugPrint(
          '[UserService] No existing profile for UID: $trimmedUid. Writing profile with role: $assignedRole to users/$trimmedUid',
        );
      }

      final data = <String, dynamic>{
        'uid': trimmedUid,
        'userId': trimmedUid,
        'displayName': trimmedName,
        'name': trimmedName,
        'email': trimmedEmail,
        'role': assignedRole,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      if (kDebugMode) {
        debugPrint(
          '[UserService] Successfully created user profile at users/$trimmedUid',
        );
      }

      return UserModel(
        id: trimmedUid,
        name: trimmedName,
        email: trimmedEmail,
        role: assignedRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[UserService] FirebaseException creating profile for UID: $uid: code=${e.code}, message=${e.message}',
        );
      }
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[UserService] Unexpected error creating profile for UID: $uid: $e',
        );
      }
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: 'Failed to create user profile: $e',
      );
    }
  }

  /// Saves or creates a user profile at `users/{user.id}`.
  ///
  /// If [merge] is true, fields are merged with any existing document.
  /// Validates that client cannot self-assign the manager role.
  ///
  /// Throws [UserServiceException] on validation or Firestore failure.
  Future<void> createUserProfile(UserModel user, {bool merge = false}) async {
    try {
      final assignedRole = validateClientAssignableRole(user.role);
      final docRef = userDoc(user.id);

      final data = <String, dynamic>{
        'uid': user.id,
        'userId': user.id,
        'displayName': user.name,
        'name': user.name,
        'email': user.email.trim(),
        'role': assignedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!merge) {
        data['createdAt'] = user.createdAt != null
            ? Timestamp.fromDate(user.createdAt!)
            : FieldValue.serverTimestamp();
      }

      await docRef.set(data, SetOptions(merge: merge));
    } on FirebaseException catch (e) {
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: 'Failed to create user profile: $e',
      );
    }
  }

  /// Updates allowed profile fields (such as display name) for `users/{uid}`.
  ///
  /// Restricted fields (such as `role`, `uid`, and `createdAt`) cannot be mutated
  /// via this method to prevent unauthorized elevation.
  ///
  /// Throws [UserServiceException] on failure.
  Future<void> updateProfile({required String uid, String? displayName}) async {
    try {
      final docRef = userDoc(uid);
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) {
        final trimmed = displayName.trim();
        updates['displayName'] = trimmed;
        updates['name'] = trimmed;
      }

      await docRef.update(updates);
    } on FirebaseException catch (e) {
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: 'Failed to update user profile: $e',
      );
    }
  }

  /// Updates permitted profile fields (displayName, name) of [user] in `users/{user.id}`.
  ///
  /// Protected fields (such as `role`, `uid`, `userId`, `email`, and `createdAt`) are
  /// not mutated by this user-facing method to prevent unauthorized elevation
  /// and adhere to the security rules allowlist.
  Future<void> updateUserProfile(UserModel user) async {
    try {
      final docRef = userDoc(user.id);
      final updates = <String, dynamic>{
        'displayName': user.name.trim(),
        'name': user.name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.update(updates);
    } on FirebaseException catch (e) {
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: 'Failed to update user profile: $e',
      );
    }
  }

  /// Assigns a new role to [targetUid] in `users/{targetUid}`.
  ///
  /// Intended for managerial role assignment. Rejects unrecognized roles.
  /// Cloud Firestore security rules enforce that only an authenticated manager
  /// can update another user's role.
  Future<void> updateUserRole({
    required String targetUid,
    required String newRole,
  }) async {
    try {
      final normalized = newRole.trim().toLowerCase();
      if (!recognizedRoles.contains(normalized)) {
        throw UserServiceException(
          code: 'invalid-role',
          message:
              'Cannot assign unrecognized role "$newRole". Allowed roles are operator, technician, or manager.',
        );
      }

      final docRef = userDoc(targetUid);
      await docRef.update({
        'role': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw UserServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is UserServiceException) rethrow;
      throw UserServiceException(
        code: 'unknown',
        message: 'Failed to update user role: $e',
      );
    }
  }

  /// Streams real-time updates for a user document at `users/{uid}`.
  ///
  /// Emits `null` if the document does not exist.
  Stream<UserModel?> streamUserProfile(String uid) {
    final docRef = userDoc(uid);
    return docRef
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return null;
          }
          return UserModel.fromFirestore(snapshot);
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            throw UserServiceException.fromFirebaseException(error);
          }
          throw UserServiceException(
            code: 'unknown',
            message: 'Stream error: $error',
          );
        });
  }
}
