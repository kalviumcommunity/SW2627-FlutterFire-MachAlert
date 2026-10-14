import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/widgets/dashboard_action_card.dart';
import 'package:mach_alert/widgets/dashboard_stat_card.dart';

void main() {
  testWidgets('DashboardActionCard displays content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardActionCard(
            title: 'Machines',
            subtitle: 'View production machines',
            icon: Icons.precision_manufacturing,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Machines'), findsOneWidget);

    expect(find.text('View production machines'), findsOneWidget);

    expect(find.byIcon(Icons.precision_manufacturing), findsOneWidget);
  });

  testWidgets('DashboardActionCard responds to tap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardActionCard(
            title: 'Machines',
            subtitle: 'View machines',
            icon: Icons.precision_manufacturing,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Machines'));

    expect(tapped, isTrue);
  });

  testWidgets('DashboardStatCard displays label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DashboardStatCard(
            label: 'Active Faults',
            value: '5',
            icon: Icons.warning,
          ),
        ),
      ),
    );

    expect(find.text('Active Faults'), findsOneWidget);

    expect(find.text('5'), findsOneWidget);
  });
}
