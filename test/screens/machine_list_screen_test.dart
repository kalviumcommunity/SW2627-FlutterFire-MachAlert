import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/machines/machine_details_screen.dart';
import 'package:mach_alert/screens/machines/machine_form_screen.dart';
import 'package:mach_alert/screens/machines/machine_list_screen.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

MachineModel machine({
  required String id,
  required String name,
  required String status,
  String line = 'Assembly Line',
}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: line,
    status: status,
    healthScore: 100,
  );
}

void main() {
  testWidgets('MachineListScreen displays machine list', (tester) async {
    final machines = [
      machine(id: 'M-01', name: 'CNC Machine', status: 'Operational'),
      machine(id: 'M-02', name: 'Hydraulic Press', status: 'Operational'),
      machine(
        id: 'M-03',
        name: 'Assembly Machine',
        status: 'Under Maintenance',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MachineListScreen(machines: machines)),
    );

    expect(find.text('Machines'), findsOneWidget);

    expect(find.text('M-01'), findsOneWidget);

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('M-02'), findsOneWidget);

    expect(find.text('Under Maintenance'), findsOneWidget);
  });

  testWidgets('MachineListScreen filters machines by search', (tester) async {
    final machines = [
      machine(id: 'M-01', name: 'CNC Machine', status: 'Operational'),
      machine(id: 'M-02', name: 'Hydraulic Press', status: 'Operational'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MachineListScreen(machines: machines)),
    );

    await tester.enterText(find.byType(TextField), 'CNC');

    await tester.pump();

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('Hydraulic Press'), findsNothing);
  });

  testWidgets('MachineListScreen shows empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MachineListScreen()));

    expect(find.text('No machines available'), findsOneWidget);
  });

  testWidgets('MachineListScreen shows no results after unmatched search', (
    tester,
  ) async {
    final machines = [
      machine(id: 'M-01', name: 'CNC Machine', status: 'Operational'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MachineListScreen(machines: machines)),
    );

    await tester.enterText(find.byType(TextField), 'does-not-exist');

    await tester.pump();

    expect(find.text('No machines found'), findsOneWidget);
  });

  testWidgets('tapping machine opens MachineDetailsScreen', (tester) async {
    final machines = [
      machine(id: 'M-01', name: 'CNC Machine', status: 'Operational'),
    ];

    await tester.pumpWidget(
      MaterialApp(home: MachineListScreen(machines: machines)),
    );

    await tester.tap(find.text('M-01'));

    await tester.pumpAndSettle();

    expect(find.byType(MachineDetailsScreen), findsOneWidget);

    expect(find.text('CNC Machine'), findsOneWidget);
  });

  group('MachineListScreen with MachineProvider and Roles', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MachineService machineService;
    late MachineProvider machineProvider;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      machineService = MachineService(firestore: fakeFirestore);
      machineProvider = MachineProvider(
        machineService: machineService,
        autoSubscribe: false,
      );
    });

    tearDown(() {
      machineProvider.dispose();
    });

    testWidgets('loads and displays machines from MachineProvider', (
      tester,
    ) async {
      machineProvider.setMachines([
        machine(id: 'P-01', name: 'Provider CNC', status: 'Operational'),
        machine(id: 'P-02', name: 'Provider Press', status: 'Warning'),
      ]);

      await tester.pumpWidget(
        ChangeNotifierProvider<MachineProvider>.value(
          value: machineProvider,
          child: const MaterialApp(home: MachineListScreen()),
        ),
      );

      await tester.pump();

      expect(find.text('Provider CNC'), findsOneWidget);
      expect(find.text('Provider Press'), findsOneWidget);
    });

    testWidgets('shows loading indicator when provider is loading', (
      tester,
    ) async {
      final streamController = StreamController<List<MachineModel>>();
      machineProvider.subscribeToMachineStream(streamController.stream);

      await tester.pumpWidget(
        ChangeNotifierProvider<MachineProvider>.value(
          value: machineProvider,
          child: const MaterialApp(home: MachineListScreen()),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await streamController.close();
    });

    testWidgets('shows error state with retry button when provider has error', (
      tester,
    ) async {
      final streamController = StreamController<List<MachineModel>>();
      machineProvider.subscribeToMachineStream(streamController.stream);
      streamController.addError(
        MachineServiceException(
          code: 'unavailable',
          message: 'Network offline',
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<MachineProvider>.value(
          value: machineProvider,
          child: const MaterialApp(home: MachineListScreen()),
        ),
      );

      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text('Network offline'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await streamController.close();
    });

    testWidgets('hides Add Machine FAB for operator or technician role', (
      tester,
    ) async {
      final appState = AppStateProvider()
        ..setAuthenticated(
          UserModel(
            id: 'u-op',
            name: 'Operator Joe',
            email: 'joe@plant.com',
            role: AppConstants.roleOperator,
          ),
        );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<MachineProvider>.value(
              value: machineProvider,
            ),
          ],
          child: const MaterialApp(home: MachineListScreen()),
        ),
      );

      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Add Machine'), findsNothing);

      appState.dispose();
    });

    testWidgets(
      'shows Add Machine FAB for manager role and navigates to form',
      (tester) async {
        final appState = AppStateProvider()
          ..setAuthenticated(
            UserModel(
              id: 'u-mgr',
              name: 'Manager Mary',
              email: 'mary@plant.com',
              role: AppConstants.roleManager,
            ),
          );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(value: appState),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: const MaterialApp(home: MachineListScreen()),
          ),
        );

        await tester.pump();

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Add Machine'), findsOneWidget);

        await tester.tap(find.text('Add Machine'));
        await tester.pumpAndSettle();

        expect(find.byType(MachineFormScreen), findsOneWidget);

        appState.dispose();
      },
    );

    testWidgets('filters machines in real time when searching with provider', (
      tester,
    ) async {
      machineProvider.setMachines([
        machine(id: 'S-01', name: 'Alpha Machine', status: 'Operational'),
        machine(id: 'S-02', name: 'Beta Press', status: 'Warning'),
      ]);

      await tester.pumpWidget(
        ChangeNotifierProvider<MachineProvider>.value(
          value: machineProvider,
          child: const MaterialApp(home: MachineListScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Alpha Machine'), findsOneWidget);
      expect(find.text('Beta Press'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pump();

      expect(find.text('Alpha Machine'), findsOneWidget);
      expect(find.text('Beta Press'), findsNothing);
    });

    testWidgets('tapping machine tile navigates to MachineDetailsScreen', (
      tester,
    ) async {
      final m = machine(
        id: 'NAV-01',
        name: 'Navigation Mill',
        status: 'Operational',
      );
      machineProvider.setMachines([m]);

      await tester.pumpWidget(
        ChangeNotifierProvider<MachineProvider>.value(
          value: machineProvider,
          child: const MaterialApp(home: MachineListScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Navigation Mill'), findsOneWidget);

      await tester.tap(find.text('Navigation Mill'));
      await tester.pumpAndSettle();

      expect(find.byType(MachineDetailsScreen), findsOneWidget);
      expect(find.text('NAV-01'), findsWidgets);
    });

    testWidgets(
      'canManage: true combined with unauthenticated app state hides Add Machine FAB',
      (tester) async {
        final unauthAppState = AppStateProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppStateProvider>.value(
                value: unauthAppState,
              ),
              ChangeNotifierProvider<MachineProvider>.value(
                value: machineProvider,
              ),
            ],
            child: const MaterialApp(home: MachineListScreen(canManage: true)),
          ),
        );

        await tester.pump();
        expect(find.byType(FloatingActionButton), findsNothing);

        unauthAppState.dispose();
      },
    );

    testWidgets(
      'canManage: true without AppStateProvider hides Add Machine FAB',
      (tester) async {
        await tester.pumpWidget(
          ChangeNotifierProvider<MachineProvider>.value(
            value: machineProvider,
            child: const MaterialApp(home: MachineListScreen(canManage: true)),
          ),
        );

        await tester.pump();
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );
  });
}
