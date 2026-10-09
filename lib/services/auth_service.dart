import 'package:firebase_auth/firebase_auth.dart';

/// Exception thrown by [AuthService] operations when authentication fails.
class AuthServiceException implements Exception {
  /// Default user-friendly error message used for unknown or unexpected error codes.
  static const String defaultErrorMessage =
      'An authentication error occurred. Please try again.';

  /// The error code preserved from Firebase Authentication.
  final String code;

  /// A safe, user-readable error message.
  final String message;

  /// Creates an [AuthServiceException].
  ///
  /// If [message] is not provided, it is automatically resolved using
  /// [messageForErrorCode] based on [code].
  AuthServiceException({required this.code, String? message})
    : message = message ?? messageForErrorCode(code);

  /// Creates an [AuthServiceException] by converting a [FirebaseAuthException].
  factory AuthServiceException.fromFirebaseAuthException(
    FirebaseAuthException exception,
  ) {
    return AuthServiceException(
      code: exception.code,
      message: messageForErrorCode(exception.code),
    );
  }

  /// Maps Firebase Authentication error codes to safe, user-readable messages.
  static String messageForErrorCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'network-request-failed':
        return 'A network error occurred. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return defaultErrorMessage;
    }
  }

  @override
  String toString() => 'AuthServiceException(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthServiceException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Service wrapper around [FirebaseAuth] for managing authentication.
class AuthService {
  final FirebaseAuth _firebaseAuth;

  /// Creates an [AuthService] instance.
  ///
  /// Optionally accepts a [FirebaseAuth] instance for testing or custom configuration.
  /// Defaults to [FirebaseAuth.instance].
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Internal access to the underlying [FirebaseAuth] instance.
  FirebaseAuth get firebaseAuth => _firebaseAuth;

  /// Convenience getter for the underlying [FirebaseAuth] instance.
  FirebaseAuth get auth => _firebaseAuth;

  /// Returns the currently signed-in [User], or `null` if no user is signed in.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of authentication state changes.
  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  /// Registers a new user with [email] and [password].
  ///
  /// Surrounding whitespace in [email] is trimmed before submission.
  /// The [password] is passed unchanged.
  ///
  /// Throws an [AuthServiceException] if Firebase Authentication fails.
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException.fromFirebaseAuthException(e);
    }
  }

  /// Signs in an existing user with [email] and [password].
  ///
  /// Surrounding whitespace in [email] is trimmed before submission.
  /// The [password] is passed unchanged.
  ///
  /// Throws an [AuthServiceException] if Firebase Authentication fails.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException.fromFirebaseAuthException(e);
    }
  }

  /// Signs out the currently authenticated user.
  ///
  /// Throws an [AuthServiceException] if Firebase Authentication fails.
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException.fromFirebaseAuthException(e);
    }
  }
}
