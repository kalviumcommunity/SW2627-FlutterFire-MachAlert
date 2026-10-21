import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/machines/machine_details_screen.dart';
import 'package:mach_alert/screens/machines/machine_form_screen.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

MachineModel createMachine({String status = 'Operational'}) {
  return MachineModel(
    id: 'M-01',
    name: 'CNC Machine',
    productionLine: 'Assembly Line A',
    modelNumber: 'CNC-X100',
    status: status,
    healthScore: 92,
    temperature: 64.5,
    vibration: 12.3,
    lastInspection: DateTime(2026, 10, 10, 10, 30),
  );
}

void main() {
  testWidgets('MachineDetailsScreen displays machine information', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    expect(find.text('M-01'), findsWidgets);

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('Assembly Line A'), findsOneWidget);

    expect(find.text('Running'), findsOneWidget);

    expect(find.text('92%'), findsOneWidget);

    expect(find.text('64.5°C'), findsOneWidget);

    expect(find.text('12.3'), findsOneWidget);
  });

  testWidgets('MachineDetailsScreen displays overview tab initially', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    expect(find.text('Total Inspections'), findsOneWidget);

    expect(find.text('Total Breakdowns'), findsOneWidget);

    expect(find.text('Last Inspection'), findsOneWidget);

    expect(find.text('Recent Logs'), findsOneWidget);
  });

  testWidgets('MachineDetailsScreen switches to Logs tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    await tester.tap(find.text('Logs'));

    await tester.pump();

    expect(find.text('Machine Logs'), findsOneWidget);

    expect(
      find.textContaining('Inspection and breakdown logs'),
      findsOneWidget,
    );
  });

  testWidgets('MachineDetailsScreen switches to Trend tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
    );

    await tester.tap(find.text('Trend'));

    await tester.pump();

    expect(find.text('Machine Trend'), findsOneWidget);
  });

  testWidgets('Breakdown status displays correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MachineDetailsScreen(machine: createMachine(status: 'Breakdown')),
      ),
    );

    expect(find.text('Breakdown'), findsOneWidget);
  });

  group('MachineDetailsScreen CRUD and Role Actions', () {
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

    testWidgets('shows popup menu for manager role', (tester) async {
      final appState = AppStateProvider()
        ..setAuthenticated(
          UserModel(
            id: 'mgr',
            name: 'Manager',
            email: 'mgr@plant.com',
            role: AppConstants.roleManager,
          ),
        );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
          ],
          child: MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);

      appState.dispose();
    });

    testWidgets('hides popup menu for operator or technician role', (tester) async {
      final appState = AppStateProvider()
        ..setAuthenticated(
          UserModel(
            id: 'op',
            name: 'Operator',
            email: 'op@plant.com',
            role: AppConstants.roleOperator,
          ),
        );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
          ],
          child: MaterialApp(home: MachineDetailsScreen(machine: createMachine())),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsNothing);

      appState.dispose();
    });

    AppStateProvider createManagerAppState() {
      return AppStateProvider()
        ..setAuthenticated(
          UserModel(
            id: 'mgr-01',
            name: 'Manager Mary',
            email: 'mary@plant.com',
            role: AppConstants.roleManager,
          ),
        );
    }

    testWidgets('cancelling delete dialog does not delete machine', (tester) async {
      final m = createMachine();
      await machineService.addMachine(m);
      machineProvider.setMachines([m]);
      final appState = createManagerAppState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
          ],
          child: MaterialApp(
            home: MachineDetailsScreen(machine: m, canManage: true),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Machine'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Machine?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Machine?'), findsNothing);
      expect(await machineService.machineExists(m.id), isTrue);

      appState.dispose();
    });

    testWidgets('confirming delete dialog deletes machine and navigates back', (tester) async {
      final m = createMachine();
      await machineService.addMachine(m);
      machineProvider.setMachines([m]);
      final appState = createManagerAppState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
          ],
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => MachineDetailsScreen(machine: m, canManage: true),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Machine'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await machineService.machineExists(m.id), isFalse);
      expect(machineProvider.machines, isEmpty);

      appState.dispose();
    });

    testWidgets('selecting Edit Machine opens MachineFormScreen', (tester) async {
      final m = createMachine();
      final appState = createManagerAppState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
          ],
          child: MaterialApp(
            home: MachineDetailsScreen(machine: m, canManage: true),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Machine'));
      await tester.pumpAndSettle();

      expect(find.byType(MachineFormScreen), findsOneWidget);
      expect(find.text('Edit Machine'), findsWidgets);

      appState.dispose();
    });

    testWidgets('shows error message when delete fails', (tester) async {
      final m = createMachine();
      final appState = createManagerAppState();
      final failingService = FailingMachineService(firestore: fakeFirestore);
      final failingProvider = MachineProvider(
        machineService: failingService,
        autoSubscribe: false,
      );
      failingProvider.setMachines([m]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
            ChangeNotifierProvider<MachineProvider>.value(value: failingProvider),
          ],
          child: MaterialApp(
            home: MachineDetailsScreen(machine: m, canManage: true),
          ),
        ),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Machine'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Failed to delete machine: Database offline'), findsOneWidget);

      failingProvider.dispose();
      appState.dispose();
    });

    testWidgets('canManage: true combined with unauthenticated app state hides popup menu and blocks actions', (tester) async {
      final m = createMachine();
      final unauthAppState = AppStateProvider(); // unauthenticated (user is null)

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppStateProvider>.value(value: unauthAppState),
            ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
          ],
          child: MaterialApp(
            home: MachineDetailsScreen(machine: m, canManage: true),
          ),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsNothing);
      unauthAppState.dispose();
    });

    testWidgets('canManage: true without AppStateProvider hides popup menu', (tester) async {
      final m = createMachine();

      await tester.pumpWidget(
        ChangeNotifierProvider<MachineProvider>.value(
          value: machineProvider,
          child: MaterialApp(
            home: MachineDetailsScreen(machine: m, canManage: true),
          ),
        ),
      );

      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });
  });
}

class FailingMachineService extends MachineService {
  FailingMachineService({super.firestore});

  @override
  Future<void> deleteMachine(String id) async {
    throw MachineServiceException(
      code: 'unavailable',
      message: 'Database offline',
    );
  }
}
