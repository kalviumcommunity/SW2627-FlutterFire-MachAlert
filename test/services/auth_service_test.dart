import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/services/auth_service.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  FakeUser({required this.uid, this.email});
}

class FakeUserCredential extends Fake implements UserCredential {
  @override
  final User? user;

  FakeUserCredential({this.user});
}

class FakeAuthCredential extends Fake implements AuthCredential {}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  String? lastCreatedEmail;
  String? lastCreatedPassword;
  String? lastSignedInEmail;
  String? lastSignedInPassword;
  AuthCredential? lastSignedInCredential;
  bool signOutCalled = false;
  Object? errorToThrow;

  FakeFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    lastSignedInCredential = credential;
    final user = FakeUser(uid: 'google_user_123', email: 'google@test.com');
    _currentUser = user;
    _authStateController.add(user);
    return FakeUserCredential(user: user);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    lastCreatedEmail = email;
    lastCreatedPassword = password;
    return FakeUserCredential(
      user: FakeUser(uid: 'user_created_123', email: email),
    );
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    lastSignedInEmail = email;
    lastSignedInPassword = password;
    return FakeUserCredential(
      user: FakeUser(uid: 'user_signed_in_123', email: email),
    );
  }

  @override
  Future<void> signOut() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    signOutCalled = true;
    _currentUser = null;
    _authStateController.add(null);
  }

  void emitAuthState(User? user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  void dispose() {
    _authStateController.close();
  }
}

void main() {
  group('AuthService Tests', () {
    late FakeFirebaseAuth fakeAuth;
    late AuthService authService;

    setUp(() {
      fakeAuth = FakeFirebaseAuth();
      authService = AuthService(firebaseAuth: fakeAuth);
    });

    tearDown(() {
      fakeAuth.dispose();
    });

    group('Getters and Streams', () {
      test('exposes underlying FirebaseAuth instance', () {
        expect(authService.firebaseAuth, same(fakeAuth));
        expect(authService.auth, same(fakeAuth));
      });

      test('returns null currentUser when no user is signed in', () {
        expect(authService.currentUser, isNull);
      });

      test('returns currentUser when a user is signed in', () {
        final fakeUser = FakeUser(uid: 'user_123', email: 'test@machalert.com');
        final authWithUser = AuthService(
          firebaseAuth: FakeFirebaseAuth(initialUser: fakeUser),
        );

        expect(authWithUser.currentUser, isNotNull);
        expect(authWithUser.currentUser?.uid, 'user_123');
        expect(authWithUser.currentUser?.email, 'test@machalert.com');
      });

      test('emits authStateChanges events from underlying stream', () async {
        final fakeUser = FakeUser(
          uid: 'user_456',
          email: 'operator@machalert.com',
        );

        expect(
          authService.authStateChanges(),
          emitsInOrder([fakeUser, isNull]),
        );

        fakeAuth.emitAuthState(fakeUser);
        fakeAuth.emitAuthState(null);
      });
    });

    group('signUp', () {
      test('delegates to Firebase with correct credentials and returns UserCredential', () async {
        final credential = await authService.signUp(
          email: 'engineer@factory.com',
          password: 'SecurePassword123!',
        );

        expect(fakeAuth.lastCreatedEmail, 'engineer@factory.com');
        expect(fakeAuth.lastCreatedPassword, 'SecurePassword123!');
        expect(credential.user?.email, 'engineer@factory.com');
        expect(credential.user?.uid, 'user_created_123');
      });

      test(
        'trims surrounding whitespace from email while preserving password',
        () async {
          const rawEmail = '   operator@plant.org  \t\n ';
          const rawPassword = '  exact_spaces_preserved  ';

          await authService.signUp(email: rawEmail, password: rawPassword);

          expect(fakeAuth.lastCreatedEmail, 'operator@plant.org');
          expect(fakeAuth.lastCreatedPassword, rawPassword);
        },
      );

      test('converts FirebaseAuthException into AuthServiceException preserving code', () async {
        fakeAuth.errorToThrow = FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Backend sensitive error details',
        );

        expect(
          () => authService.signUp(
            email: 'existing@machalert.com',
            password: 'password123',
          ),
          throwsA(
            isA<AuthServiceException>()
                .having((e) => e.code, 'code', 'email-already-in-use')
                .having(
                  (e) => e.message,
                  'message',
                  'An account already exists for this email.',
                ),
          ),
        );
      });

      test(
        'converts weak-password error on signup to user-friendly message',
        () async {
          fakeAuth.errorToThrow = FirebaseAuthException(
            code: 'weak-password',
            message: 'Password should be at least 6 characters',
          );

          expect(
            () =>
                authService.signUp(email: 'new@machalert.com', password: '123'),
            throwsA(
              isA<AuthServiceException>()
                  .having((e) => e.code, 'code', 'weak-password')
                  .having(
                    (e) => e.message,
                    'message',
                    'The password provided is too weak.',
                  ),
            ),
          );
        },
      );

      test(
        'does not catch non-FirebaseAuthException errors indiscriminately',
        () async {
          fakeAuth.errorToThrow = StateError(
            'critical internal programming error',
          );

          expect(
            () => authService.signUp(
              email: 'user@machalert.com',
              password: 'password123',
            ),
            throwsA(isA<StateError>()),
          );
        },
      );
    });

    group('signIn', () {
      test('delegates to Firebase with correct credentials and returns UserCredential', () async {
        final credential = await authService.signIn(
          email: 'technician@machalert.com',
          password: 'TechPassword456!',
        );

        expect(fakeAuth.lastSignedInEmail, 'technician@machalert.com');
        expect(fakeAuth.lastSignedInPassword, 'TechPassword456!');
        expect(credential.user?.email, 'technician@machalert.com');
        expect(credential.user?.uid, 'user_signed_in_123');
      });

      test(
        'trims surrounding whitespace from email while preserving password',
        () async {
          const rawEmail = '   tech@factory.io  ';
          const rawPassword = ' P@ssw0rd with spaces ';

          await authService.signIn(email: rawEmail, password: rawPassword);

          expect(fakeAuth.lastSignedInEmail, 'tech@factory.io');
          expect(fakeAuth.lastSignedInPassword, rawPassword);
        },
      );

      test('converts FirebaseAuthException into AuthServiceException preserving code', () async {
        fakeAuth.errorToThrow = FirebaseAuthException(
          code: 'wrong-password',
          message: 'Firebase internal backend message',
        );

        expect(
          () => authService.signIn(
            email: 'tech@machalert.com',
            password: 'wrongpass',
          ),
          throwsA(
            isA<AuthServiceException>()
                .having((e) => e.code, 'code', 'wrong-password')
                .having(
                  (e) => e.message,
                  'message',
                  'Incorrect password. Please try again.',
                ),
          ),
        );
      });

      test('converts invalid-credential error on sign in to safe user-friendly message', () async {
        fakeAuth.errorToThrow = FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Invalid credential provided',
        );

        expect(
          () => authService.signIn(
            email: 'tech@machalert.com',
            password: 'badpassword',
          ),
          throwsA(
            isA<AuthServiceException>()
                .having((e) => e.code, 'code', 'invalid-credential')
                .having(
                  (e) => e.message,
                  'message',
                  'Invalid email or password. Please try again.',
                ),
          ),
        );
      });

      test(
        'does not catch non-FirebaseAuthException errors indiscriminately',
        () async {
          fakeAuth.errorToThrow = ArgumentError('invalid argument encountered');

          expect(
            () => authService.signIn(
              email: 'tech@machalert.com',
              password: 'password123',
            ),
            throwsA(isA<ArgumentError>()),
          );
        },
      );
    });

    group('signOut', () {
      test('delegates to Firebase signOut', () async {
        expect(fakeAuth.signOutCalled, isFalse);

        await authService.signOut();

        expect(fakeAuth.signOutCalled, isTrue);
      });

      test(
        'converts FirebaseAuthException during signOut to AuthServiceException',
        () async {
          fakeAuth.errorToThrow = FirebaseAuthException(
            code: 'network-request-failed',
            message: 'Connection dropped',
          );

          expect(
            () => authService.signOut(),
            throwsA(
              isA<AuthServiceException>()
                  .having((e) => e.code, 'code', 'network-request-failed')
                  .having(
                    (e) => e.message,
                    'message',
                    'A network error occurred. Please check your internet connection.',
                  ),
            ),
          );
        },
      );

      test('does not catch non-FirebaseAuthException errors indiscriminately during signOut', () async {
        fakeAuth.errorToThrow = UnsupportedError('unsupported operation');

        expect(() => authService.signOut(), throwsA(isA<UnsupportedError>()));
      });
    });

    group('AuthServiceException and Error Code Mappings', () {
      final expectedMappings = <String, String>{
        'invalid-email': 'The email address is invalid.',
        'user-not-found': 'No user found with this email.',
        'wrong-password': 'Incorrect password. Please try again.',
        'invalid-credential': 'Invalid email or password. Please try again.',
        'email-already-in-use': 'An account already exists for this email.',
        'weak-password': 'The password provided is too weak.',
        'network-request-failed':
            'A network error occurred. Please check your internet connection.',
        'too-many-requests': 'Too many requests. Please try again later.',
        'user-disabled': 'This user account has been disabled.',
        'operation-not-allowed':
            'Operation not allowed. Please contact support.',
      };

      for (final entry in expectedMappings.entries) {
        test('maps code "${entry.key}" to expected user-readable message', () {
          final exception = AuthServiceException.fromFirebaseAuthException(
            FirebaseAuthException(code: entry.key),
          );

          expect(exception.code, entry.key);
          expect(exception.message, entry.value);
        });
      }

      test('maps unknown error codes to safe generic message without exposing backend internals', () {
        final exception = AuthServiceException.fromFirebaseAuthException(
          FirebaseAuthException(
            code: 'unrecognized-backend-internal-failure',
            message: 'Sensitive SQL/NoSQL credentials or stacktrace leaked',
          ),
        );

        expect(exception.code, 'unrecognized-backend-internal-failure');
        expect(exception.message, AuthServiceException.defaultErrorMessage);
        expect(
          exception.message,
          'An authentication error occurred. Please try again.',
        );
      });

      test('supports constructor with default message resolution and custom message', () {
        final autoMessageEx = AuthServiceException(code: 'weak-password');
        expect(autoMessageEx.code, 'weak-password');
        expect(autoMessageEx.message, 'The password provided is too weak.');

        final customMessageEx = AuthServiceException(
          code: 'weak-password',
          message: 'Custom weak password warning',
        );
        expect(customMessageEx.code, 'weak-password');
        expect(customMessageEx.message, 'Custom weak password warning');
      });

      test('implements toString, equality, and hashCode', () {
        final ex1 = AuthServiceException(
          code: 'invalid-email',
          message: 'The email address is invalid.',
        );
        final ex2 = AuthServiceException(
          code: 'invalid-email',
          message: 'The email address is invalid.',
        );
        final ex3 = AuthServiceException(
          code: 'user-not-found',
          message: 'No user found with this email.',
        );

        expect(ex1.toString(), contains('invalid-email'));
        expect(ex1.toString(), contains('The email address is invalid.'));
        expect(ex1, equals(ex2));
        expect(ex1.hashCode, equals(ex2.hashCode));
        expect(ex1, isNot(equals(ex3)));
      });
    });

    group('Persistent Authentication & Session Lifecycle', () {
      test('restores existing user session on startup without requiring re-authentication', () {
        final persistedUser = FakeUser(
          uid: 'persisted_operator_001',
          email: 'operator@machalert.com',
        );
        final persistentAuth = FakeFirebaseAuth(initialUser: persistedUser);
        addTearDown(persistentAuth.dispose);
        final service = AuthService(firebaseAuth: persistentAuth);

        expect(service.currentUser, isNotNull);
        expect(service.currentUser?.uid, 'persisted_operator_001');
        expect(service.currentUser?.email, 'operator@machalert.com');
      });

      test(
        'returns null currentUser on startup when no session was persisted',
        () {
          final freshAuth = FakeFirebaseAuth(initialUser: null);
          addTearDown(freshAuth.dispose);
          final service = AuthService(firebaseAuth: freshAuth);

          expect(service.currentUser, isNull);
        },
      );

      test('emits restored user session immediately on startup via authStateChanges', () async {
        final persistedUser = FakeUser(
          uid: 'persisted_tech_002',
          email: 'tech@machalert.com',
        );
        final persistentAuth = FakeFirebaseAuth(initialUser: persistedUser);
        addTearDown(persistentAuth.dispose);
        final service = AuthService(firebaseAuth: persistentAuth);

        final authFuture = expectLater(
          service.authStateChanges(),
          emits(persistedUser),
        );

        persistentAuth.emitAuthState(persistedUser);
        await authFuture;
      });

      test('emits null via authStateChanges when startup resolves as unauthenticated', () async {
        final persistentAuth = FakeFirebaseAuth(initialUser: null);
        addTearDown(persistentAuth.dispose);
        final service = AuthService(firebaseAuth: persistentAuth);

        final authFuture = expectLater(
          service.authStateChanges(),
          emits(isNull),
        );

        persistentAuth.emitAuthState(null);
        await authFuture;
      });

      test('multiple listeners receive session restoration broadcasts independently', () async {
        final persistedUser = FakeUser(
          uid: 'multi_listener_user',
          email: 'multi@machalert.com',
        );
        final persistentAuth = FakeFirebaseAuth(initialUser: persistedUser);
        addTearDown(persistentAuth.dispose);
        final service = AuthService(firebaseAuth: persistentAuth);

        final listener1 = expectLater(
          service.authStateChanges(),
          emits(persistedUser),
        );
        final listener2 = expectLater(
          service.authStateChanges(),
          emits(persistedUser),
        );

        persistentAuth.emitAuthState(persistedUser);

        await Future.wait([listener1, listener2]);
      });

      test('signOut terminates persisted session and updates currentUser and stream to null', () async {
        final persistedUser = FakeUser(
          uid: 'session_user_logout',
          email: 'logout@machalert.com',
        );
        final persistentAuth = FakeFirebaseAuth(initialUser: persistedUser);
        addTearDown(persistentAuth.dispose);
        final service = AuthService(firebaseAuth: persistentAuth);

        expect(service.currentUser, isNotNull);

        final expectation = expectLater(
          service.authStateChanges(),
          emits(isNull),
        );

        await service.signOut();

        expect(persistentAuth.signOutCalled, isTrue);
        expect(service.currentUser, isNull);
        await expectation;
      });

      test(
        'persisted session survives new AuthService wrapper instantiation',
        () {
          final persistedUser = FakeUser(
            uid: 'persisted_lifecycle_user',
            email: 'lifecycle@machalert.com',
          );
          final persistentAuth = FakeFirebaseAuth(initialUser: persistedUser);
          addTearDown(persistentAuth.dispose);

          // Simulates initial app boot
          final serviceInstance1 = AuthService(firebaseAuth: persistentAuth);
          expect(serviceInstance1.currentUser?.uid, 'persisted_lifecycle_user');

          // Simulates app component recreation / dependency re-read
          final serviceInstance2 = AuthService(firebaseAuth: persistentAuth);
          expect(serviceInstance2.currentUser?.uid, 'persisted_lifecycle_user');
          expect(
            serviceInstance2.currentUser,
            same(serviceInstance1.currentUser),
          );
        },
      );
    });

    group('Google Sign-In Tests', () {
      test(
        'signInWithGoogle signs in using injected credential provider',
        () async {
          final fakeCredential = FakeAuthCredential();
          final fakeAuth = FakeFirebaseAuth();
          addTearDown(fakeAuth.dispose);

          final service = AuthService(
            firebaseAuth: fakeAuth,
            googleCredentialProvider: () async => fakeCredential,
          );

          final result = await service.signInWithGoogle();

          expect(result, isNotNull);
          expect(result!.user?.uid, 'google_user_123');
          expect(fakeAuth.lastSignedInCredential, same(fakeCredential));
          expect(service.currentUser?.uid, 'google_user_123');
        },
      );

      test('signInWithGoogle returns null when credential provider returns null (cancelled)', () async {
        final fakeAuth = FakeFirebaseAuth();
        addTearDown(fakeAuth.dispose);

        final service = AuthService(
          firebaseAuth: fakeAuth,
          googleCredentialProvider: () async => null,
        );

        final result = await service.signInWithGoogle();

        expect(result, isNull);
        expect(fakeAuth.lastSignedInCredential, isNull);
      });

      test(
        'signInWithGoogle maps FirebaseAuthException to AuthServiceException',
        () async {
          final fakeAuth = FakeFirebaseAuth();
          fakeAuth.errorToThrow = FirebaseAuthException(
            code: 'account-exists-with-different-credential',
            message: 'Account exists with different credential.',
          );
          addTearDown(fakeAuth.dispose);

          final service = AuthService(
            firebaseAuth: fakeAuth,
            googleCredentialProvider: () async => FakeAuthCredential(),
          );

          expect(
            () => service.signInWithGoogle(),
            throwsA(
              isA<AuthServiceException>().having(
                (e) => e.code,
                'code',
                'account-exists-with-different-credential',
              ),
            ),
          );
        },
      );

      test(
        'signInWithGoogle wraps unexpected errors into AuthServiceException',
        () async {
          final fakeAuth = FakeFirebaseAuth();
          fakeAuth.errorToThrow = Exception('Unexpected native error');
          addTearDown(fakeAuth.dispose);

          final service = AuthService(
            firebaseAuth: fakeAuth,
            googleCredentialProvider: () async => FakeAuthCredential(),
          );

          expect(
            () => service.signInWithGoogle(),
            throwsA(
              isA<AuthServiceException>().having(
                (e) => e.code,
                'code',
                'google-sign-in-failed',
              ),
            ),
          );
        },
      );

      test('AuthServiceException maps Google and OAuth codes to user-friendly messages', () {
        expect(
          AuthServiceException.messageForErrorCode('popup-closed-by-user'),
          'Google Sign-In was cancelled.',
        );
        expect(
          AuthServiceException.messageForErrorCode(
            'account-exists-with-different-credential',
          ),
          'An account already exists with the same email address but different sign-in credentials.',
        );
        expect(
          AuthServiceException.messageForErrorCode('unauthorized-domain'),
          'This domain is not authorized for OAuth operations in your Firebase project.',
        );
        expect(
          AuthServiceException.messageForErrorCode('google-sign-in-failed'),
          'Google Sign-In failed. Please try again.',
        );
      });
    });
  });
}
