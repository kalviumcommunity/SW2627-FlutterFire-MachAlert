import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/dashboard/home_screen.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';
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

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());

    appState.dispose();
  });

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
  group('Role based dashboard UI', () {
    testWidgets('Operator sees operator dashboard actions', (tester) async {
      await pumpDashboard(tester, role: 'operator');

      expect(find.text('Operator Dashboard'), findsOneWidget);

      expect(find.text('Machines'), findsOneWidget);

      expect(find.text('Report Fault'), findsOneWidget);

      expect(find.text('My Reports'), findsOneWidget);
    });

    testWidgets('Technician sees technician dashboard actions', (tester) async {
      await pumpDashboard(tester, role: 'technician');

      expect(find.text('Technician Dashboard'), findsOneWidget);

      expect(find.text('Assigned Maintenance'), findsOneWidget);

      expect(find.text('Active Faults'), findsWidgets);

      expect(find.text('Machines'), findsOneWidget);
    });

    testWidgets('Manager sees manager dashboard actions', (tester) async {
      await pumpDashboard(tester, role: 'manager');

      expect(find.text('Manager Dashboard'), findsOneWidget);

      expect(find.text('Factory Overview'), findsOneWidget);

      expect(find.text('Machines'), findsWidgets);

      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('Unknown role shows neutral dashboard', (tester) async {
      await pumpDashboard(tester, role: '');

      expect(find.text('Dashboard'), findsOneWidget);

      expect(find.text('Your role is being prepared.'), findsOneWidget);

      expect(find.text('Machines'), findsOneWidget);

      expect(find.text('Report Fault'), findsNothing);
    });

    testWidgets('Operator Machines action opens MachineListScreen', (
      tester,
    ) async {
      await pumpDashboard(tester, role: 'operator');

      final machinesButton = find.text('Machines');

      expect(machinesButton, findsOneWidget);

      await tester.ensureVisible(machinesButton);

      await tester.tap(machinesButton);

      await tester.pumpAndSettle();

      expect(find.byType(MachineListScreen), findsOneWidget);

      expect(find.text('No machines available'), findsOneWidget);
    });

    testWidgets('Machine screen back navigation returns to dashboard', (
      tester,
    ) async {
      await pumpDashboard(tester, role: 'operator');

      final machinesButton = find.text('Machines');

      await tester.ensureVisible(machinesButton);

      await tester.tap(machinesButton);

      await tester.pumpAndSettle();

      expect(find.byType(MachineListScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);

      expect(find.text('Operator Dashboard'), findsOneWidget);

      expect(find.byType(MachineListScreen), findsNothing);
    });
  });
}
