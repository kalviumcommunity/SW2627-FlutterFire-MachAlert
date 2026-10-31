import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/theme/app_theme.dart';

void main() {
  test('MachAlert light theme uses Material 3', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);

    expect(theme.colorScheme.brightness, Brightness.light);
  });

  testWidgets('MachAlert theme applies to application widgets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(
            child: FilledButton(onPressed: null, child: Text('Continue')),
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(Scaffold));

    expect(Theme.of(context).useMaterial3, isTrue);

    expect(find.text('Continue'), findsOneWidget);
  });
}
