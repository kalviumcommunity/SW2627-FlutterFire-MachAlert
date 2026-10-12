import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';

void main() {
  group('AppStateProvider Tests', () {
    late AppStateProvider provider;
    late UserModel testUser;

    setUp(() {
      provider = AppStateProvider();
      testUser = UserModel(
        id: 'u123',
        name: 'Jane Operator',
        email: 'jane@machalert.com',
        role: 'operator',
      );
    });

    test('has correct initial state', () {
      expect(provider.status, AppStatus.initializing);
      expect(provider.route, AppRoute.login);
      expect(provider.user, isNull);
      expect(provider.isInitializing, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.isUnauthenticated, isFalse);
    });

    test(
      'setInitializing updates status to initializing and notifies listeners',
      () {
        provider.setUnauthenticated();

        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.setInitializing();

        expect(provider.status, AppStatus.initializing);
        expect(provider.isInitializing, isTrue);
        expect(provider.isAuthenticated, isFalse);
        expect(provider.isUnauthenticated, isFalse);
        expect(notifyCount, 1);
      },
    );

    test('setUnauthenticated updates status, clears user, defaults route to login, and notifies listeners', () {
      provider.setAuthenticated(testUser);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setUnauthenticated();

      expect(provider.status, AppStatus.unauthenticated);
      expect(provider.user, isNull);
      expect(provider.route, AppRoute.login);
      expect(provider.isUnauthenticated, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.isInitializing, isFalse);
      expect(notifyCount, 1);
    });

    test('setUnauthenticated allows custom route override', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setUnauthenticated(route: AppRoute.signup);

      expect(provider.status, AppStatus.unauthenticated);
      expect(provider.route, AppRoute.signup);
      expect(provider.isUnauthenticated, isTrue);
      expect(notifyCount, 1);
    });

    test('setAuthenticated stores user, sets authenticated status, defaults route to home, and notifies listeners', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setAuthenticated(testUser);

      expect(provider.status, AppStatus.authenticated);
      expect(provider.user, testUser);
      expect(provider.route, AppRoute.home);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.isInitializing, isFalse);
      expect(provider.isUnauthenticated, isFalse);
      expect(notifyCount, 1);
    });

    test('setAuthenticated allows custom route override', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setAuthenticated(testUser, route: AppRoute.login);

      expect(provider.status, AppStatus.authenticated);
      expect(provider.user, testUser);
      expect(provider.route, AppRoute.login);
      expect(provider.isAuthenticated, isTrue);
      expect(notifyCount, 1);
    });

    test('navigateTo updates route, notifies listeners, and preserves auth status and user', () {
      provider.setAuthenticated(testUser);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Navigate to signup
      provider.navigateTo(AppRoute.signup);
      expect(provider.route, AppRoute.signup);
      expect(provider.status, AppStatus.authenticated);
      expect(provider.user, testUser);
      expect(notifyCount, 1);

      // Navigate to login
      provider.navigateTo(AppRoute.login);
      expect(provider.route, AppRoute.login);
      expect(provider.status, AppStatus.authenticated);
      expect(provider.user, testUser);
      expect(notifyCount, 2);

      // Navigate to home
      provider.navigateTo(AppRoute.home);
      expect(provider.route, AppRoute.home);
      expect(provider.status, AppStatus.authenticated);
      expect(provider.user, testUser);
      expect(notifyCount, 3);
    });

    test('clearSession resets authenticated state to unauthenticated, clears user, sets route to login, and notifies listeners', () {
      provider.setAuthenticated(testUser);

      expect(provider.isAuthenticated, isTrue);
      expect(provider.user, isNotNull);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearSession();

      expect(provider.status, AppStatus.unauthenticated);
      expect(provider.user, isNull);
      expect(provider.route, AppRoute.login);
      expect(provider.isUnauthenticated, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.isInitializing, isFalse);
      expect(notifyCount, 1);
    });
  });

  group('AppStateProvider Firebase Auth Stream Integration Tests', () {
    late StreamController<User?> authStreamController;
    late AppStateProvider providerWithStream;

    setUp(() {
      authStreamController = StreamController<User?>.broadcast();
      providerWithStream = AppStateProvider(
        authStream: authStreamController.stream,
      );
    });

    tearDown(() {
      authStreamController.close();
      if (!providerWithStream.isDisposed) {
        providerWithStream.dispose();
      }
    });

    test('initial state is initializing prior to any stream event', () {
      expect(providerWithStream.status, AppStatus.initializing);
      expect(providerWithStream.isInitializing, isTrue);
      expect(providerWithStream.user, isNull);
      expect(providerWithStream.hasActiveSubscription, isTrue);
    });

    test(
      'signed-out state (null) transitions provider to unauthenticated',
      () async {
        int notifyCount = 0;
        providerWithStream.addListener(() => notifyCount++);

        authStreamController.add(null);
        await pumpEventQueue();

        expect(providerWithStream.status, AppStatus.unauthenticated);
        expect(providerWithStream.isUnauthenticated, isTrue);
        expect(providerWithStream.route, AppRoute.login);
        expect(providerWithStream.user, isNull);
        expect(notifyCount, 1);
      },
    );

    test('signed-in Firebase user transitions provider to authenticated and stores mapped UserModel', () async {
      int notifyCount = 0;
      providerWithStream.addListener(() => notifyCount++);

      final fakeUser = _FakeUser(
        uid: 'firebase_uid_123',
        email: 'operator@factory.com',
        displayName: 'Factory Operator',
      );

      authStreamController.add(fakeUser);
      await pumpEventQueue();

      expect(providerWithStream.status, AppStatus.authenticated);
      expect(providerWithStream.isAuthenticated, isTrue);
      expect(providerWithStream.route, AppRoute.home);
      expect(providerWithStream.user, isNotNull);
      expect(providerWithStream.user?.id, 'firebase_uid_123');
      expect(providerWithStream.user?.name, 'Factory Operator');
      expect(providerWithStream.user?.email, 'operator@factory.com');
      expect(providerWithStream.user?.role, '');
      expect(notifyCount, 1);
    });

    test(
      'maps Firebase user with null displayName and email safely without error',
      () async {
        final fakeUser = _FakeUser(uid: 'uid_no_profile');

        authStreamController.add(fakeUser);
        await pumpEventQueue();

        expect(providerWithStream.user?.id, 'uid_no_profile');
        expect(providerWithStream.user?.name, '');
        expect(providerWithStream.user?.email, '');
        expect(providerWithStream.user?.role, '');
      },
    );

    test(
      'signing out clears the stored user and resets route to login',
      () async {
        final fakeUser = _FakeUser(
          uid: 'active_user',
          email: 'user@factory.com',
        );

        authStreamController.add(fakeUser);
        await pumpEventQueue();

        expect(providerWithStream.isAuthenticated, isTrue);
        expect(providerWithStream.user, isNotNull);

        // Now emit null (sign out)
        authStreamController.add(null);
        await pumpEventQueue();

        expect(providerWithStream.status, AppStatus.unauthenticated);
        expect(providerWithStream.isUnauthenticated, isTrue);
        expect(providerWithStream.user, isNull);
        expect(providerWithStream.route, AppRoute.login);
      },
    );

    test('stream errors safely transition provider to unauthenticated without hanging in initializing', () async {
      authStreamController.addError(
        Exception('Network error during auth stream'),
      );
      await pumpEventQueue();

      expect(providerWithStream.status, AppStatus.unauthenticated);
      expect(providerWithStream.isUnauthenticated, isTrue);
      expect(providerWithStream.user, isNull);
    });

    test('stream subscription is cleaned up when provider is disposed', () {
      expect(providerWithStream.hasActiveSubscription, isTrue);

      providerWithStream.dispose();

      expect(providerWithStream.hasActiveSubscription, isFalse);
      expect(providerWithStream.isDisposed, isTrue);
    });

    test(
      'does not call notifyListeners after disposal even if stream emits later',
      () async {
        providerWithStream.dispose();

        // Emitting on stream after disposal should not throw FlutterError
        authStreamController.add(_FakeUser(uid: 'post_dispose_user'));
        await pumpEventQueue();

        expect(providerWithStream.isDisposed, isTrue);
      },
    );
  });
}

class _FakeUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  _FakeUser({required this.uid, this.email, this.displayName});
}
