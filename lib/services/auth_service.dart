import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      case 'popup-closed-by-user':
        return 'Google Sign-In was cancelled.';
      case 'unauthorized-domain':
        return 'This domain is not authorized for OAuth operations in your Firebase project.';
      case 'google-sign-in-failed':
        return 'Google Sign-In failed. Please try again.';
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

/// Signature for custom Google credential provider function used for testing or injection.
typedef GoogleCredentialProvider = Future<AuthCredential?> Function();

/// Service wrapper around [FirebaseAuth] for managing authentication.
class AuthService {
  /// Web/Server OAuth Client ID required on Android by Google Sign-In / Credential Manager
  /// to mint an ID token for Firebase Authentication.
  static const String defaultServerClientId =
      '297020906537-17f2d3otmucvr1n5lcofrq92r7rion7v.apps.googleusercontent.com';

  final FirebaseAuth _firebaseAuth;
  final GoogleCredentialProvider? googleCredentialProvider;
  final String? serverClientId;
  bool _googleSignInInitialized = false;

  /// Creates an [AuthService] instance.
  ///
  /// Optionally accepts a [FirebaseAuth] instance, [googleCredentialProvider]
  /// for dependency injection in testing, and [serverClientId] for specifying the
  /// Google OAuth Web Client ID for Android ID token retrieval.
  /// Defaults to [FirebaseAuth.instance] and [defaultServerClientId].
  AuthService({
    FirebaseAuth? firebaseAuth,
    this.googleCredentialProvider,
    this.serverClientId = defaultServerClientId,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  /// Internal access to the underlying [FirebaseAuth] instance.
  FirebaseAuth get firebaseAuth => _firebaseAuth;

  /// Convenience getter for the underlying [FirebaseAuth] instance.
  FirebaseAuth get auth => _firebaseAuth;

  /// Returns the currently signed-in [User], or `null` if no user is signed in.
  ///
  /// On Android and iOS, Firebase Authentication automatically restores the
  /// signed-in user's session from native secure storage upon app startup.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of authentication state changes.
  ///
  /// Emits the active [User] when a persisted session is restored on startup
  /// or when a user signs in, and emits `null` when signed out or when no
  /// session exists.
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

  /// Signs in the user with Google.
  ///
  /// On mobile platforms, initiates the Google Sign-In authentication flow
  /// using [GoogleSignIn.instance.authenticate] and signs into Firebase with
  /// the resulting credential.
  /// On Web, initiates [FirebaseAuth.signInWithPopup] with a [GoogleAuthProvider].
  ///
  /// Returns the authenticated [UserCredential], or `null` if the sign-in was
  /// cancelled by the user.
  ///
  /// Throws [AuthServiceException] on failure.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      AuthCredential? credential;

      if (googleCredentialProvider != null) {
        credential = await googleCredentialProvider!();
        if (credential == null) {
          return null; // User cancelled
        }
      } else if (kIsWeb) {
        final authProvider = GoogleAuthProvider();
        return await _firebaseAuth.signInWithPopup(authProvider);
      } else {
        if (!_googleSignInInitialized) {
          try {
            await GoogleSignIn.instance.initialize(
              serverClientId: serverClientId,
            );
          } catch (initError) {
            if (kDebugMode) {
              debugPrint(
                '[AuthService] GoogleSignIn.initialize() non-fatal info: $initError',
              );
            }
          }
          _googleSignInInitialized = true;
        }

        final GoogleSignInAccount googleUser = await GoogleSignIn.instance
            .authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[AuthService] Google Sign-In succeeded but idToken was null/empty.',
            );
          }
          throw AuthServiceException(
            code: 'google-sign-in-failed',
            message: 'Failed to retrieve Google ID token. Ensure OAuth clients are configured in Firebase.',
          );
        }

        credential = GoogleAuthProvider.credential(idToken: idToken);
      }

      return await _firebaseAuth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AuthService] GoogleSignInException: code=${e.code}, description=${e.description}',
        );
      }
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      throw AuthServiceException(
        code: 'google-sign-in-failed',
        message: _messageForGoogleSignInException(e),
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AuthService] PlatformException: code=${e.code}, message=${e.message}, details=${e.details}',
        );
      }
      if (e.code == 'sign_in_canceled' || e.code == 'canceled') {
        return null;
      }
      throw AuthServiceException(
        code: 'google-sign-in-failed',
        message: _messageForPlatformException(e),
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AuthService] FirebaseAuthException: code=${e.code}, message=${e.message}',
        );
      }
      throw AuthServiceException.fromFirebaseAuthException(e);
    } catch (e) {
      if (e is AuthServiceException) rethrow;
      if (kDebugMode) {
        debugPrint(
          '[AuthService] Unexpected Google Sign-In error: type=${e.runtimeType}, error=$e',
        );
      }
      throw AuthServiceException(
        code: 'google-sign-in-failed',
        message: 'Google Sign-In failed. Please try again.',
      );
    }
  }

  static String _messageForGoogleSignInException(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google Sign-In was cancelled.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google Sign-In was interrupted. Please try again.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google Sign-In is temporarily unavailable on this device.';
      default:
        final desc = e.description?.toLowerCase() ?? '';
        if (desc.contains('10') || desc.contains('developer_error')) {
          return 'Google Sign-In configuration error: Please register your SHA-1 fingerprint in Firebase Console.';
        }
        if (desc.contains('network') || desc.contains('7')) {
          return 'Network error during Google Sign-In. Please check your internet connection.';
        }
        return 'Google Sign-In failed. Please try again.';
    }
  }

  static String _messageForPlatformException(PlatformException e) {
    final message = (e.message ?? '').toLowerCase();
    final details = (e.details?.toString() ?? '').toLowerCase();
    if (e.code == '10' ||
        message.contains('10') ||
        message.contains('developer_error') ||
        details.contains('10') ||
        details.contains('developer_error')) {
      return 'Google Sign-In configuration error: Please register your SHA-1 fingerprint in Firebase Console.';
    }
    if (e.code == '7' ||
        message.contains('network') ||
        details.contains('network')) {
      return 'Network error during Google Sign-In. Please check your internet connection.';
    }
    if (e.code == 'sign_in_canceled' || e.code == 'canceled') {
      return 'Google Sign-In was cancelled.';
    }
    return 'Google Sign-In failed. Please try again.';
  }

  /// Signs out the currently authenticated user.
  ///
  /// Clears both Google Sign-In state (on non-web platforms) and Firebase Authentication.
  /// Throws an [AuthServiceException] if Firebase Authentication fails.
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await GoogleSignIn.instance.signOut();
        } catch (_) {
          // Ignore Google sign out failure if not signed in with Google or in test environment
        }
      }
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException.fromFirebaseAuthException(e);
    }
  }
}
