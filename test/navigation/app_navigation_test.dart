import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';

void main() {
  testWidgets('App starts on the Login placeholder', (tester) async {
    // Build the app widget directly.
    // This does not call the application's main() function.
    await tester.pumpWidget(const MachAlertApp());

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('MachAlert'), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Sign Up opens and returns without duplicating Login', (
    tester,
  ) async {
    await tester.pumpWidget(const MachAlertApp());

    // Repeat the journey to check that back navigation remains correct.
    for (var visit = 0; visit < 2; visit++) {
      await tester.tap(find.text('Open Sign Up'));
      await tester.pumpAndSettle();

      expect(find.byType(SignupScreen), findsOneWidget);

      await tester.tap(find.text('Back to Login'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SignupScreen), findsNothing);

      final loginContext = tester.element(find.byType(LoginScreen));

      // Login should still be the first screen in the navigation stack.
      expect(Navigator.of(loginContext).canPop(), isFalse);
    }
  });

  testWidgets('App bar back button returns from Sign Up to Login', (
    tester,
  ) async {
    await tester.pumpWidget(const MachAlertApp());

    await tester.tap(find.text('Open Sign Up'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });

  testWidgets('Debug Home preview opens and returns to Login', (tester) async {
    await tester.pumpWidget(const MachAlertApp());

    await tester.tap(find.text('Preview Home (no login)'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
