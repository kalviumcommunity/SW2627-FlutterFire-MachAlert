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

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  FakeFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

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
      final fakeUser = FakeUser(uid: 'user_456', email: 'operator@machalert.com');

      expect(
        authService.authStateChanges(),
        emitsInOrder([
          fakeUser,
          isNull,
        ]),
      );

      fakeAuth.emitAuthState(fakeUser);
      fakeAuth.emitAuthState(null);
    });
  });
}
