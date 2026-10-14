import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/auth_gate.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/splash/splash_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:provider/provider.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() {
    return const Stream<User?>.empty();
  }
}

class _FakeFirebaseAuthWithController extends Fake implements FirebaseAuth {
  final Stream<User?> _stream;

  _FakeFirebaseAuthWithController(this._stream);

  @override
  Stream<User?> authStateChanges() {
    return _stream;
  }
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

AuthService createFakeAuthService() {
  return AuthService(firebaseAuth: _FakeFirebaseAuth());
}

UserService createFakeUserService() {
  return UserService(firestore: FakeFirebaseFirestore());
}

void main() {
  group('MachAlertApp Root Configuration Tests', () {
    testWidgets('root app builds with MultiProvider', (tester) async {
      final authService = createFakeAuthService();
      final userService = createFakeUserService();

      await tester.pumpWidget(
        MachAlertApp(authService: authService, userService: userService),
      );

      await tester.pump();

      expect(find.byType(MultiProvider), findsOneWidget);

      expect(find.byType(MaterialApp), findsOneWidget);

      expect(find.byType(AuthGate), findsOneWidget);
    });

    testWidgets('AppStateProvider is available to descendants', (tester) async {
      final authService = createFakeAuthService();
      final userService = createFakeUserService();

      await tester.pumpWidget(
        MachAlertApp(authService: authService, userService: userService),
      );

      await tester.pump();

      final authGateContext = tester.element(find.byType(AuthGate));

      final appStateProvider = Provider.of<AppStateProvider>(
        authGateContext,
        listen: false,
      );

      expect(appStateProvider, isNotNull);

      expect(appStateProvider.status, AppStatus.initializing);

      expect(appStateProvider.route, AppRoute.login);

      expect(appStateProvider.user, isNull);
    });

    testWidgets('AuthService is available to descendants', (tester) async {
      final authService = createFakeAuthService();
      final userService = createFakeUserService();

      await tester.pumpWidget(
        MachAlertApp(authService: authService, userService: userService),
      );

      await tester.pump();

      final authGateContext = tester.element(find.byType(AuthGate));

      final retrievedAuthService = Provider.of<AuthService>(
        authGateContext,
        listen: false,
      );

      expect(retrievedAuthService, isNotNull);

      expect(retrievedAuthService, same(authService));
    });

    testWidgets('UserService is available to descendants', (tester) async {
      final authService = createFakeAuthService();
      final userService = createFakeUserService();

      await tester.pumpWidget(
        MachAlertApp(authService: authService, userService: userService),
      );

      await tester.pump();

      final authGateContext = tester.element(find.byType(AuthGate));

      final retrievedUserService = Provider.of<UserService>(
        authGateContext,
        listen: false,
      );

      expect(retrievedUserService, isNotNull);

      expect(retrievedUserService, same(userService));
    });

    testWidgets('initial state shows splash screen', (tester) async {
      final authService = createFakeAuthService();
      final userService = createFakeUserService();

      await tester.pumpWidget(
        MachAlertApp(authService: authService, userService: userService),
      );

      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'root AppStateProvider listens to root AuthService and drives AuthGate transitions',
      (tester) async {
        final authStreamController = StreamController<User?>.broadcast();

        addTearDown(authStreamController.close);

        final fakeAuth = _FakeFirebaseAuthWithController(
          authStreamController.stream,
        );

        final authService = AuthService(firebaseAuth: fakeAuth);

        final userService = UserService(firestore: FakeFirebaseFirestore());

        await tester.pumpWidget(
          MachAlertApp(authService: authService, userService: userService),
        );

        await tester.pump();

        expect(find.byType(SplashScreen), findsOneWidget);

        authStreamController.add(
          _FakeUser(
            uid: 'root_user',
            email: 'root@test.com',
            displayName: 'Root User',
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);

        expect(find.byType(SplashScreen), findsNothing);
      },
    );
  });
}
