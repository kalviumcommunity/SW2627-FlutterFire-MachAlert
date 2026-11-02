import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/theme/app_theme.dart';

void main() {
  test('MachAlert approved color palette values match brand specification', () {
    expect(AppTheme.navy, const Color(0xFF344C6B));
    expect(AppTheme.sageTeal, const Color(0xFF78B5A8));
    expect(AppTheme.green, const Color(0xFF78B5A8));
    expect(AppTheme.teal, const Color(0xFF78B5A8));
    expect(AppTheme.background, const Color(0xFFF8FAFC));
  });

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
