import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/widgets/app_state_view.dart';

void main() {
  testWidgets('loading state displays progress indicator and message', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppStateView.loading(
            title: 'Loading machines...',
            message: 'Fetching data.',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(find.text('Loading machines...'), findsOneWidget);

    expect(find.text('Fetching data.'), findsOneWidget);
  });

  testWidgets('empty state displays title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppStateView.empty(
            title: 'No machines available',
            message: 'Machines will appear here.',
          ),
        ),
      ),
    );

    expect(find.text('No machines available'), findsOneWidget);

    expect(find.text('Machines will appear here.'), findsOneWidget);
  });

  testWidgets('error state invokes retry action', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppStateView.error(
            title: 'Unable to load data',
            message: 'Try again.',
            onAction: () {
              retryCount++;
            },
          ),
        ),
      ),
    );

    expect(find.text('Unable to load data'), findsOneWidget);

    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));

    expect(retryCount, equals(1));
  });

  testWidgets('info state displays informational content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppStateView.info(
            title: 'Live fault monitoring',
            message: 'Waiting for connection.',
          ),
        ),
      ),
    );

    expect(find.text('Live fault monitoring'), findsOneWidget);

    expect(find.text('Waiting for connection.'), findsOneWidget);
  });
}
