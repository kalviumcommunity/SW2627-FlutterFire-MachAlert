import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';

const _signupLinkText = "Don't have an account? Sign Up";
const _loginLinkText = 'Already have an account? Login';

// Scroll a link into view before tapping it.
// This matters because the signup form is taller than some test screens.
Future<void> _tapVisibleText(WidgetTester tester, String text) async {
  final finder = find.text(text);

  expect(finder, findsOneWidget);

  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App starts on the Login screen', (tester) async {
    await tester.pumpWidget(const MachAlertApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('MachAlert'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Sign Up opens and returns without duplicating Login', (
    tester,
  ) async {
    await tester.pumpWidget(const MachAlertApp());
    await tester.pumpAndSettle();

    // Repeat the journey to verify that Login screens do not accumulate.
    for (var visit = 0; visit < 2; visit++) {
      await _tapVisibleText(tester, _signupLinkText);

      expect(find.byType(SignupScreen), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      await _tapVisibleText(tester, _loginLinkText);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SignupScreen), findsNothing);

      final loginContext = tester.element(find.byType(LoginScreen));

      // Login must remain the first screen in the navigation stack.
      expect(Navigator.of(loginContext).canPop(), isFalse);
    }
  });

  testWidgets('App bar back button returns from Sign Up to Login', (
    tester,
  ) async {
    await tester.pumpWidget(const MachAlertApp());
    await tester.pumpAndSettle();

    await _tapVisibleText(tester, _signupLinkText);

    expect(find.byType(SignupScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);

    final loginContext = tester.element(find.byType(LoginScreen));

    expect(Navigator.of(loginContext).canPop(), isFalse);
  });

  testWidgets('Day 4 Login has no Home shortcut and submission is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(const MachAlertApp());
    await tester.pumpAndSettle();

    // The temporary Day 3 preview entry point was deliberately removed.
    expect(find.text('Preview Home (no login)'), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Authentication submission will be connected in Day 5.
    final loginButtonFinder = find.widgetWithText(ElevatedButton, 'Login');

    expect(loginButtonFinder, findsOneWidget);

    final loginButton = tester.widget<ElevatedButton>(loginButtonFinder);

    expect(loginButton.onPressed, isNull);
    expect(loginButton.onLongPress, isNull);
  });
}
