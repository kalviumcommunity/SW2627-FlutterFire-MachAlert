import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/auth_gate.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/onboarding/onboarding_screen.dart';
import 'package:mach_alert/screens/splash/splash_screen.dart';
import 'package:mach_alert/widgets/mach_alert_logo.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserModel _createTestUser() {
  return UserModel(
    id: 'user_123',
    name: 'Alex Operator',
    email: 'alex@factory.com',
    role: 'operator',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MachAlert Startup, Splash & Onboarding Navigation Flow', () {
    testWidgets(
      '1. SplashScreen displays during initial authentication resolution',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final appState = AppStateProvider();
        addTearDown(appState.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const MaterialApp(
              home: AuthGate(minSplashDuration: Duration(milliseconds: 1500)),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets('2. Splash remains visible for minimum 1.5 seconds', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppStateProvider()..setUnauthenticated();
      addTearDown(appState.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: AuthGate(minSplashDuration: Duration(milliseconds: 1500)),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      // At 1.0s: splash must remain visible
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);

      // At 1.5s total: splash dismisses and first-launch onboarding appears
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('3. First installation displays OnboardingScreen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppStateProvider()..setUnauthenticated();
      addTearDown(appState.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: AuthGate(minSplashDuration: Duration.zero),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(MachAlertLogo), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('4. Onboarding contains all three pages', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppStateProvider()..setUnauthenticated();
      addTearDown(appState.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: AuthGate(minSplashDuration: Duration.zero),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Page 1
      expect(find.text('Monitor in Real-Time'), findsOneWidget);
      expect(
        find.text(
          'Log inspections and breakdowns instantly from the shop floor.',
        ),
        findsOneWidget,
      );

      // Advance to Page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Detect Issues Early'), findsOneWidget);
      expect(
        find.text('Identify recurring faults and reduce unexpected downtime.'),
        findsOneWidget,
      );

      // Advance to Page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Keep Production Running'), findsOneWidget);
      expect(
        find.text('Simple, fast and reliable for every shift.'),
        findsOneWidget,
      );
    });

    testWidgets('5. Next button advances pages', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppStateProvider()..setUnauthenticated();
      addTearDown(appState.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: AuthGate(minSplashDuration: Duration.zero),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Starts on Page 1
      expect(find.text('Monitor in Real-Time'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      // Tap Next -> moves to Page 2
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text('Detect Issues Early'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

      // Tap Next -> moves to Page 3
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      expect(find.text('Keep Production Running'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Get Started'), findsOneWidget);
    });

    testWidgets('6. Get Started persists onboarding completion', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppStateProvider()..setUnauthenticated();
      addTearDown(appState.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: AuthGate(minSplashDuration: Duration.zero),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Page 1 -> 2
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Page 2 -> 3
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Tap Get Started on Page 3
      await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AuthGate.hasCompletedOnboardingKey), isTrue);
    });

    testWidgets(
      '7. Completed onboarding is not displayed on subsequent launches',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          AuthGate.hasCompletedOnboardingKey: true,
        });
        final appState = AppStateProvider()..setUnauthenticated();
        addTearDown(appState.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const MaterialApp(
              home: AuthGate(minSplashDuration: Duration.zero),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      '8. Unauthenticated first-launch user reaches LoginScreen after onboarding',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final appState = AppStateProvider()..setUnauthenticated();
        addTearDown(appState.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const MaterialApp(
              home: AuthGate(minSplashDuration: Duration.zero),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // Advance through onboarding
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      '9. Previously authenticated first-launch user reaches HomeScreen after onboarding',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final appState = AppStateProvider()
          ..setAuthenticated(_createTestUser());
        addTearDown(appState.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const MaterialApp(
              home: AuthGate(minSplashDuration: Duration.zero),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // First-launch still shows onboarding
        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Advance through onboarding
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
        await tester.pumpAndSettle();

        // Preserved session routes to HomeScreen
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets('10. Subsequent authenticated launch skips onboarding', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        AuthGate.hasCompletedOnboardingKey: true,
      });
      final appState = AppStateProvider()..setAuthenticated(_createTestUser());
      addTearDown(appState.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const MaterialApp(
            home: AuthGate(minSplashDuration: Duration.zero),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets(
      '11. Subsequent unauthenticated launch skips onboarding and reaches LoginScreen',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          AuthGate.hasCompletedOnboardingKey: true,
        });
        final appState = AppStateProvider()..setUnauthenticated();
        addTearDown(appState.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const MaterialApp(
              home: AuthGate(minSplashDuration: Duration.zero),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        expect(find.byType(OnboardingScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(HomeScreen), findsNothing);
      },
    );

    testWidgets(
      '12. Firebase authentication initialization errors do not cause an indefinite splash screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          AuthGate.hasCompletedOnboardingKey: true,
        });
        final streamController = StreamController<User?>.broadcast();
        addTearDown(streamController.close);

        final appState = AppStateProvider(authStream: streamController.stream);
        addTearDown(appState.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const MaterialApp(
              home: AuthGate(
                minSplashDuration: Duration(milliseconds: 200),
                authTimeout: Duration(milliseconds: 300),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(SplashScreen), findsOneWidget);

        // Stream emits error
        streamController.addError(Exception('Firebase auth offline'));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();

        // Error handler sets unauthenticated, splash dismisses safely
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );

    testWidgets(
      '13. Splash and onboarding transitions do not introduce duplicate navigation stacks',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final appState = AppStateProvider()..setUnauthenticated();
        addTearDown(appState.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const MaterialApp(
              home: AuthGate(minSplashDuration: Duration.zero),
            ),
          ),
        );

        await tester.pump();
        await tester.pump();

        // Onboarding active: no root session Navigator is instantiated yet
        expect(find.byType(OnboardingScreen), findsOneWidget);

        // Complete onboarding
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Get Started'));
        await tester.pumpAndSettle();

        // Session Navigator now hosts LoginScreen
        expect(find.byType(LoginScreen), findsOneWidget);
        final loginContext = tester.element(find.byType(LoginScreen));

        // Root session cannot pop backwards into onboarding or splash
        expect(Navigator.of(loginContext).canPop(), isFalse);
      },
    );
  });
}
