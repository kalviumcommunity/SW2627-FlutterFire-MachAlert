import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/screens/splash/splash_screen.dart';
import 'package:mach_alert/widgets/mach_alert_logo.dart';

void main() {
  testWidgets('SplashScreen displays MachAlert branding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(MachAlertLogo), findsOneWidget);

    expect(
      find.text('Real-time machine monitoring\nfor a smarter factory'),
      findsOneWidget,
    );

    expect(find.text('Checking your session...'), findsOneWidget);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(find.byIcon(Icons.monitor_heart_outlined), findsNothing);

    final logoFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/branding/machalert_logo.png',
    );
    expect(logoFinder, findsOneWidget);
  });
}
