import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/auth_gate.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:provider/provider.dart';

const _signupLinkText = "Don't have an account? Sign Up";
const _loginLinkText = 'Already have an account? Login';

Future<void> _pumpUnauthenticatedApp(WidgetTester tester) async {
  final appState = AppStateProvider()..setUnauthenticated();

  await tester.pumpWidget(
    ChangeNotifierProvider<AppStateProvider>.value(
      value: appState,
      child: const MaterialApp(home: AuthGate()),
    ),
  );

  await tester.pump();
}

Future<void> _tapVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);

  expect(finder, findsOneWidget);

  await tester.ensureVisible(finder);
  await tester.pump();

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App starts on the Login screen', (tester) async {
    await _pumpUnauthenticatedApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('MachAlert'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Sign Up opens and returns without duplicating Login', (
    tester,
  ) async {
    await _pumpUnauthenticatedApp(tester);

    for (var visit = 0; visit < 2; visit++) {
      await _tapVisibleText(tester, _signupLinkText);

      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      await _tapVisibleText(tester, _loginLinkText);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SignupScreen), findsNothing);

      final loginContext = tester.element(find.byType(LoginScreen));

      expect(Navigator.of(loginContext).canPop(), isFalse);
    }
  });

  testWidgets('App bar back button returns from Sign Up to Login', (
    tester,
  ) async {
    await _pumpUnauthenticatedApp(tester);

    await _tapVisibleText(tester, _signupLinkText);

    expect(find.byType(SignupScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });

  testWidgets('Day 5 Login submission is enabled', (tester) async {
    await _pumpUnauthenticatedApp(tester);

    final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Login');

    expect(loginButtonFinder, findsOneWidget);

    final loginButton = tester.widget<ElevatedButton>(loginButtonFinder);

    expect(loginButton.onPressed, isNotNull);
  });
}
