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

    test('setInitializing updates status to initializing and notifies listeners', () {
      provider.setUnauthenticated();

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setInitializing();

      expect(provider.status, AppStatus.initializing);
      expect(provider.isInitializing, isTrue);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.isUnauthenticated, isFalse);
      expect(notifyCount, 1);
    });

    test(
      'setUnauthenticated updates status, clears user, defaults route to login, and notifies listeners',
      () {
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
      },
    );

    test('setUnauthenticated allows custom route override', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setUnauthenticated(route: AppRoute.signup);

      expect(provider.status, AppStatus.unauthenticated);
      expect(provider.route, AppRoute.signup);
      expect(provider.isUnauthenticated, isTrue);
      expect(notifyCount, 1);
    });

    test(
      'setAuthenticated stores user, sets authenticated status, defaults route to home, and notifies listeners',
      () {
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
      },
    );

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

    test(
      'navigateTo updates route, notifies listeners, and preserves auth status and user',
      () {
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
      },
    );

    test(
      'clearSession resets authenticated state to unauthenticated, clears user, sets route to login, and notifies listeners',
      () {
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
      },
    );
  });
}
