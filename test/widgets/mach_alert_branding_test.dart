import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/onboarding/onboarding_screen.dart';
import 'package:mach_alert/screens/profile/profile_screen.dart';
import 'package:mach_alert/screens/reports/reports_screen.dart';
import 'package:mach_alert/screens/splash/splash_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:mach_alert/widgets/mach_alert_logo.dart';
import 'package:provider/provider.dart';

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();

  @override
  Future<void> signOut() async {}
}

class _FakeFaultService extends Fake implements FaultService {
  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
  }) async => [];

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
  }) => const Stream<List<FaultModel>>.empty();
}

void main() {
  group('MachAlert Brand Consistency Audit & Verification', () {
    test('Requirement 9 & 10: Approved color palette constants match specifications', () {
      expect(AppTheme.navy, const Color(0xFF344C6B));
      expect(AppTheme.sageTeal, const Color(0xFF78B5A8));
      expect(AppTheme.green, const Color(0xFF78B5A8));
      expect(AppTheme.teal, const Color(0xFF78B5A8));
      expect(AppTheme.background, const Color(0xFFF8FAFC));
    });

    testWidgets(
      'Requirement 7: MachAlertLogo widget does NOT render Icons.monitor_heart_outlined',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  MachAlertLogo(compact: false),
                  MachAlertLogo(compact: true),
                ],
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.monitor_heart_outlined), findsNothing);
      },
    );

    testWidgets(
      'Requirement 8: MachAlertLogo properly switches between full and compact modes',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  MachAlertLogo(compact: false),
                  MachAlertLogo(compact: true),
                ],
              ),
            ),
          ),
        );

        final fullLogoFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/branding/machalert_logo.png',
        );
        final compactEmblemFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/branding/machalert_emblem.png',
        );

        expect(fullLogoFinder, findsOneWidget);
        expect(compactEmblemFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Requirement 1: Splash screen displays the full approved logo',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

        expect(find.byType(MachAlertLogo), findsOneWidget);

        final fullLogoFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/branding/machalert_logo.png',
        );
        expect(fullLogoFinder, findsOneWidget);
        expect(find.byIcon(Icons.monitor_heart_outlined), findsNothing);
      },
    );

    testWidgets('Requirement 2: Login screen displays the full approved logo', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

      expect(find.byType(MachAlertLogo), findsOneWidget);

      final fullLogoFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/machalert_logo.png',
      );
      expect(fullLogoFinder, findsOneWidget);
    });

    testWidgets(
      'Requirement 3: Signup screen displays the full approved logo',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

        expect(find.byType(MachAlertLogo), findsOneWidget);

        final fullLogoFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/branding/machalert_logo.png',
        );
        expect(fullLogoFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Requirement 4: Dashboard displays the compact approved M emblem in AppBar',
      (tester) async {
        final appState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'test-user',
              name: 'Test Operator',
              email: 'operator@example.com',
              role: 'operator',
              createdAt: DateTime.now(),
            ),
          );
        final authService = AuthService(firebaseAuth: _FakeFirebaseAuth());
        final faultService = _FakeFaultService();

        addTearDown(() {
          appState.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<AuthService>.value(value: authService),
              Provider<FaultService>.value(value: faultService),
            ],
            child: MaterialApp(home: HomeScreen(faultService: faultService)),
          ),
        );

        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);

        final emblemInAppBar = find.descendant(
          of: appBarFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/branding/machalert_emblem.png',
          ),
        );
        expect(emblemInAppBar, findsOneWidget);
      },
    );

    testWidgets(
      'Requirement 5: Profile screen does not contain redundant logos',
      (tester) async {
        final appState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'test-user',
              name: 'Test Operator',
              email: 'operator@example.com',
              role: 'operator',
              createdAt: DateTime.now(),
            ),
          );
        final authService = AuthService(firebaseAuth: _FakeFirebaseAuth());

        addTearDown(() {
          appState.dispose();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              Provider<AuthService>.value(value: authService),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );

        expect(find.byType(MachAlertLogo), findsNothing);
        expect(find.text('Profile'), findsOneWidget);
      },
    );

    testWidgets(
      'Requirement 6: Reports screen does not contain redundant logos',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: ReportsScreen()));

        expect(find.byType(MachAlertLogo), findsNothing);
        expect(find.text('Reports'), findsOneWidget);
      },
    );

    testWidgets(
      'Requirement 11: Onboarding screen does NOT contain top-left logo',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: OnboardingScreen(onFinished: () {})),
        );

        expect(find.byType(MachAlertLogo), findsNothing);
        expect(find.text('Monitor in Real-Time'), findsOneWidget);
      },
    );

    testWidgets(
      'Requirement 12: Login screen displays official Google G logo asset',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

        final googleButton = find.byKey(const Key('google_sign_in_button'));
        expect(googleButton, findsOneWidget);

        final googleLogoFinder = find.descendant(
          of: googleButton,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/branding/google_g_logo.png',
          ),
        );
        expect(googleLogoFinder, findsOneWidget);
        expect(find.text('Sign in with Google'), findsOneWidget);
      },
    );

    testWidgets(
      'Requirement 13: Signup screen displays official Google G logo asset',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

        final googleButton = find.byKey(const Key('google_sign_up_button'));
        expect(googleButton, findsOneWidget);

        final googleLogoFinder = find.descendant(
          of: googleButton,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/branding/google_g_logo.png',
          ),
        );
        expect(googleLogoFinder, findsOneWidget);
        expect(find.text('Sign up with Google'), findsOneWidget);
      },
    );
  });
}
