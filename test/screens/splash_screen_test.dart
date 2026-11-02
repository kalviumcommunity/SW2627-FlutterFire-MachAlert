import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/screens/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen displays MachAlert branding', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/branding/machalert_logo.png',
      ),
      findsOneWidget,
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFF8FAFC));
  });

  testWidgets('SplashScreen displays loading state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(find.text('Checking your session...'), findsOneWidget);
  });
}
