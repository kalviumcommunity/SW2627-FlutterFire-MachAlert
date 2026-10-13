import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/auth_gate.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/splash/splash_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:provider/provider.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();
}

void main() {
  group('MachAlertApp Root Configuration Tests', () {
    testWidgets('root app builds with MultiProvider', (tester) async {
      await tester.pumpWidget(const MachAlertApp());

      expect(find.byType(MultiProvider), findsOneWidget);

      expect(find.byType(MaterialApp), findsOneWidget);

      expect(find.byType(AuthGate), findsOneWidget);
    });

    testWidgets('AppStateProvider is available to descendants', (tester) async {
      await tester.pumpWidget(const MachAlertApp());

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
      final fakeAuth = _FakeFirebaseAuth();
      final authService = AuthService(firebaseAuth: fakeAuth);

      await tester.pumpWidget(MachAlertApp(authService: authService));

      await tester.pump();

      final authGateContext = tester.element(find.byType(AuthGate));

      final retrievedAuthService = Provider.of<AuthService>(
        authGateContext,
        listen: false,
      );

      expect(retrievedAuthService, isNotNull);
      expect(retrievedAuthService, same(authService));
    });

    testWidgets('initial state shows splash screen', (tester) async {
      await tester.pumpWidget(const MachAlertApp());

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

        await tester.pumpWidget(MachAlertApp(authService: authService));
        await tester.pump();

        expect(find.byType(SplashScreen), findsOneWidget);

        authStreamController.add(
          _FakeUser(uid: 'root_user', email: 'root@test.com'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
      },
    );
  });
}

class _FakeFirebaseAuthWithController extends Fake implements FirebaseAuth {
  final Stream<User?> _stream;
  _FakeFirebaseAuthWithController(this._stream);

  @override
  Stream<User?> authStateChanges() => _stream;
}

class _FakeUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  _FakeUser({required this.uid, this.email});
}
