import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';

void main() {
  testWidgets('Login screen displays email and password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Login password visibility toggles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    TextField field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.obscureText, isTrue);

    await tester.tap(find.text('Show Password'));
    await tester.pump();

    field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.obscureText, isFalse);
  });

  testWidgets('Signup screen displays all fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  testWidgets('Signup submit button is disabled', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignupScreen()));

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    expect(button.onPressed, isNull);
  });
}
