import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/widgets/app_button.dart';
import 'package:mach_alert/widgets/app_loading_indicator.dart';
import 'package:mach_alert/widgets/app_text_field.dart';

// Provides the Material app environment needed by these UI widgets.
// This does not launch main.dart or initialize Firebase.
Widget testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  testWidgets('AppButton displays its label and responds to taps', (
    tester,
  ) async {
    var wasPressed = false;

    await tester.pumpWidget(
      testApp(
        AppButton(
          text: 'Continue',
          onPressed: () {
            wasPressed = true;
          },
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(wasPressed, isTrue);
  });

  testWidgets('AppButton shows a spinner and is disabled while loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(AppButton(text: 'Continue', isLoading: true, onPressed: () {})),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    expect(button.onPressed, isNull);
  });

  testWidgets('AppButton is disabled when no callback is provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(const AppButton(text: 'Continue', onPressed: null)),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));

    expect(find.text('Continue'), findsOneWidget);
    expect(button.onPressed, isNull);
  });

  testWidgets('AppTextField displays its label and accepts input', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const AppTextField(
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
      ),
    );

    expect(find.text('Email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'operator@example.com');
    await tester.pump();

    expect(find.text('operator@example.com'), findsOneWidget);
  });

  testWidgets('AppLoadingIndicator displays a spinner', (tester) async {
    await tester.pumpWidget(testApp(const AppLoadingIndicator()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
