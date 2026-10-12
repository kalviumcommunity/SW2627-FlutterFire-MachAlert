import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/auth_gate.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:mach_alert/screens/auth/signup_screen.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';

UserModel createTestUser() {
  return UserModel(
    id: 'test-user',
    name: 'Test Operator',
    email: 'operator@example.com',
    role: 'operator',
  );
}

Future<void> pumpAuthGate(
  WidgetTester tester,
  AppStateProvider appState,
) async {
  // ChangeNotifierProvider.value does not own this test's provider.
  // Unmount the widgets before disposing it.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    appState.dispose();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<AppStateProvider>.value(
      value: appState,
      child: const MaterialApp(home: AuthGate()),
    ),
  );

  await tester.pump();
}

Future<void> openSignup(WidgetTester tester) async {
  final signupLink = find.text("Don't have an account? Sign Up");

  expect(signupLink, findsOneWidget);

  await tester.ensureVisible(signupLink);
  await tester.pumpAndSettle();

  await tester.tap(signupLink);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Initializing state displays a loading indicator', (
    tester,
  ) async {
    final appState = AppStateProvider();

    await pumpAuthGate(tester, appState);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Unauthenticated state displays Login', (tester) async {
    final appState = AppStateProvider()..setUnauthenticated();

    await pumpAuthGate(tester, appState);
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('Authenticated state displays Home', (tester) async {
    final appState = AppStateProvider()..setAuthenticated(createTestUser());

    await pumpAuthGate(tester, appState);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Signup back navigation still returns to Login', (tester) async {
    final appState = AppStateProvider()..setUnauthenticated();

    await pumpAuthGate(tester, appState);
    await tester.pumpAndSettle();

    await openSignup(tester);

    expect(find.byType(SignupScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);

    final loginContext = tester.element(find.byType(LoginScreen));
    expect(Navigator.of(loginContext).canPop(), isFalse);
  });

  testWidgets('Authentication changes clear the old screen history', (
    tester,
  ) async {
    final appState = AppStateProvider()..setUnauthenticated();

    await pumpAuthGate(tester, appState);
    await tester.pumpAndSettle();

    await openSignup(tester);
    expect(find.byType(SignupScreen), findsOneWidget);

    // Simulate the state update that the Firebase listener will provide.
    appState.setAuthenticated(createTestUser());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SignupScreen, skipOffstage: false), findsNothing);
    expect(find.byType(LoginScreen, skipOffstage: false), findsNothing);

    // Simulate a later signed-out state.
    appState.setUnauthenticated();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);

    final loginContext = tester.element(find.byType(LoginScreen));
    expect(Navigator.of(loginContext).canPop(), isFalse);
  });
}
