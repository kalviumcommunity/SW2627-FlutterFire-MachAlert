import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('MachAlertApp Root Configuration Tests', () {
    testWidgets('MachAlertApp smoke test', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const MachAlertApp());

      // Verify that 'MachAlert' text is displayed.
      expect(find.text('MachAlert'), findsOneWidget);
    });

    testWidgets('root application builds with MultiProvider configuration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MachAlertApp());
      await tester.pumpAndSettle();

      expect(find.byType(MultiProvider), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
      'AppStateProvider is available to descendant widgets through provider tree',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MachAlertApp());
        await tester.pumpAndSettle();

        final BuildContext loginContext = tester.element(
          find.byType(LoginScreen),
        );
        final appStateProvider = Provider.of<AppStateProvider>(
          loginContext,
          listen: false,
        );

        expect(appStateProvider, isNotNull);
        expect(appStateProvider.status, AppStatus.initializing);
        expect(appStateProvider.route, AppRoute.login);
        expect(appStateProvider.user, isNull);
      },
    );
  });
}
