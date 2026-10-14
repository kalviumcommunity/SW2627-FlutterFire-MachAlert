import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:provider/provider.dart';

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  Future<void> signOut() async {}
}

UserModel createUser({required String role}) {
  return UserModel(
    id: 'user-1',
    name: 'Test User',
    email: 'test@machalert.com',
    role: role,
  );
}

Future<void> pumpDashboard(WidgetTester tester, {required String role}) async {
  final appState = AppStateProvider()..setAuthenticated(createUser(role: role));

  final authService = AuthService(firebaseAuth: FakeFirebaseAuth());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        Provider<AuthService>.value(value: authService),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );

  await tester.pump();
}

void main() {
  testWidgets('Operator sees operator dashboard actions', (tester) async {
    await pumpDashboard(tester, role: 'operator');

    expect(find.text('Operator Dashboard'), findsOneWidget);

    expect(find.text('Report Fault'), findsOneWidget);

    expect(find.text('My Reports'), findsOneWidget);
  });

  testWidgets('Technician sees technician dashboard actions', (tester) async {
    await pumpDashboard(tester, role: 'technician');

    expect(find.text('Technician Dashboard'), findsOneWidget);

    expect(find.text('Assigned Maintenance'), findsOneWidget);

    expect(find.text('Active Faults'), findsWidgets);
  });

  testWidgets('Manager sees manager dashboard actions', (tester) async {
    await pumpDashboard(tester, role: 'manager');

    expect(find.text('Manager Dashboard'), findsOneWidget);

    expect(find.text('Factory Overview'), findsOneWidget);

    expect(find.text('Maintenance'), findsOneWidget);
  });

  testWidgets('Unknown role shows neutral dashboard', (tester) async {
    await pumpDashboard(tester, role: '');

    expect(find.text('Dashboard'), findsOneWidget);

    expect(find.text('Your role is being prepared.'), findsOneWidget);

    expect(find.text('Report Fault'), findsNothing);
  });
}
