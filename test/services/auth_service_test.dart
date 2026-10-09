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

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  String? lastCreatedEmail;
  String? lastCreatedPassword;
  String? lastSignedInEmail;
  String? lastSignedInPassword;
  bool signOutCalled = false;
  Object? errorToThrow;

  FakeFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

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
  });
}
