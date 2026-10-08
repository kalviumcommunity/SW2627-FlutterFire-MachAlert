import 'package:firebase_auth/firebase_auth.dart';

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
}
