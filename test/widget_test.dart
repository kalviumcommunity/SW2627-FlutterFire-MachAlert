import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/auth_gate.dart';
import 'package:provider/provider.dart';

void main() {
  group('MachAlertApp Root Configuration Tests', () {
    testWidgets('root app builds with MultiProvider', (tester) async {
      await tester.pumpWidget(const MachAlertApp());

      expect(find.byType(MultiProvider), findsOneWidget);

      expect(find.byType(MaterialApp), findsOneWidget);

      expect(find.byType(AuthGate), findsOneWidget);
    });

    testWidgets('AppStateProvider is available to descendants', (tester) async {
      await tester.pumpWidget(const MachAlertApp());

      await tester.pump();

      final authGateContext = tester.element(find.byType(AuthGate));

      final appStateProvider = Provider.of<AppStateProvider>(
        authGateContext,
        listen: false,
      );

      expect(appStateProvider, isNotNull);

      expect(appStateProvider.status, AppStatus.initializing);

      expect(appStateProvider.route, AppRoute.login);

      expect(appStateProvider.user, isNull);
    });

    testWidgets('initial state shows loading indicator', (tester) async {
      await tester.pumpWidget(const MachAlertApp());

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
