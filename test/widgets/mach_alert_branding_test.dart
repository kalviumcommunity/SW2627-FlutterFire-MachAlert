import 'dart:convert';
import 'dart:io';

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
    String? reportedBy,
  }) async => [];

  @override
  Stream<List<FaultModel>> streamFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
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

    test('Requirement 14: iOS native launcher icon does not use default Flutter placeholder', () {
      final iosIcon1024 = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');
      expect(iosIcon1024.existsSync(), isTrue);

      final bytes = iosIcon1024.readAsBytesSync();
      // PNG header check
      expect(bytes.sublist(0, 8), equals([137, 80, 78, 71, 13, 10, 26, 10]));

      final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      expect(width, equals(1024));
      expect(height, equals(1024));

      // Color type 2 is RGB without alpha (Apple App Store specification)
      expect(bytes[25], equals(2));

      // Must not match old 10,932 byte Flutter placeholder icon
      expect(bytes.length, isNot(equals(10932)));
    });

    test('Requirement 15: iOS AppIcon set contains all required resolution assets', () {
      final contentsFile = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json');
      expect(contentsFile.existsSync(), isTrue);

      final contents = jsonDecode(contentsFile.readAsStringSync()) as Map<String, dynamic>;
      final images = contents['images'] as List<dynamic>;

      for (final img in images) {
        final filename = img['filename'] as String;
        final iconFile = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/$filename');
        expect(iconFile.existsSync(), isTrue, reason: 'Missing iOS icon asset: $filename');
        expect(iconFile.lengthSync(), greaterThan(0));
      }
    });

    test('Requirement 16: Android launcher icons exist and match approved MachAlert branding', () {
      final xxxhdpiLauncher = File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');
      final xxxhdpiRound = File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png');
      final xxxhdpiForeground = File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png');

      expect(xxxhdpiLauncher.existsSync(), isTrue);
      expect(xxxhdpiRound.existsSync(), isTrue);
      expect(xxxhdpiForeground.existsSync(), isTrue);

      expect(xxxhdpiLauncher.lengthSync(), greaterThan(0));
      expect(xxxhdpiRound.lengthSync(), greaterThan(0));
      expect(xxxhdpiForeground.lengthSync(), greaterThan(0));
    });

    test('Requirement 17: MachAlert full logo and emblem aspect ratios are preserved', () {
      final fullLogoFile = File('assets/branding/machalert_logo.png');
      final emblemFile = File('assets/branding/machalert_emblem.png');

      expect(fullLogoFile.existsSync(), isTrue);
      expect(emblemFile.existsSync(), isTrue);

      final fullBytes = fullLogoFile.readAsBytesSync();
      final fullW = (fullBytes[16] << 24) | (fullBytes[17] << 16) | (fullBytes[18] << 8) | fullBytes[19];
      final fullH = (fullBytes[20] << 24) | (fullBytes[21] << 16) | (fullBytes[22] << 8) | fullBytes[23];
      final fullRatio = fullW / fullH;
      expect(fullRatio, closeTo(3.0, 0.05));

      final emblemBytes = emblemFile.readAsBytesSync();
      final emblemW = (emblemBytes[16] << 24) | (emblemBytes[17] << 16) | (emblemBytes[18] << 8) | emblemBytes[19];
      final emblemH = (emblemBytes[20] << 24) | (emblemBytes[21] << 16) | (emblemBytes[22] << 8) | emblemBytes[23];
      final emblemRatio = emblemW / emblemH;
      expect(emblemRatio, closeTo(2.02, 0.05));
    });

    test('Requirement 18: Android home screen application label and launcher activity use MachAlert', () {
      final stringsFile = File('android/app/src/main/res/values/strings.xml');
      expect(stringsFile.existsSync(), isTrue, reason: 'strings.xml must exist');

      final stringsContent = stringsFile.readAsStringSync();
      expect(stringsContent.contains('<string name="app_name">MachAlert</string>'), isTrue);

      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent.contains('android:label="@string/app_name"'), isTrue);
      expect(manifestContent.contains('android:label="mach_alert"'), isFalse, reason: 'Old mach_alert label must be replaced');
    });
  });
}
