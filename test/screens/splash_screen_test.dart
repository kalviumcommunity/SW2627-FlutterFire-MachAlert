import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/screens/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen displays MachAlert branding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('MachAlert'), findsOneWidget);

    expect(find.text('Machine Monitoring & Maintenance'), findsOneWidget);

    expect(find.byIcon(Icons.precision_manufacturing), findsOneWidget);
  });

  testWidgets('SplashScreen displays loading state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(find.text('Checking your session...'), findsOneWidget);
  });
}
