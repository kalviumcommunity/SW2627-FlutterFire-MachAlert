import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/machines/machine_form_screen.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:provider/provider.dart';

void main() {
  group('MachineFormScreen Tests', () {
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

    Widget createTestWidget({
      MachineModel? machine,
      MachineSaveCallback? onSave,
      String? role = AppConstants.roleManager,
      bool isAuthenticated = true,
      bool provideAppState = true,
    }) {
      final appState = AppStateProvider();
      if (isAuthenticated && role != null) {
        appState.setAuthenticated(
          UserModel(
            id: 'test-user',
            name: 'Test Manager',
            email: 'mgr@plant.com',
            role: role,
          ),
        );
      }

      final providers = <ChangeNotifierProvider>[
        ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
      ];
      if (provideAppState) {
        providers.insert(
          0,
          ChangeNotifierProvider<AppStateProvider>.value(value: appState),
        );
      }

      return MultiProvider(
        providers: providers,
        child: MaterialApp(
          home: MachineFormScreen(machine: machine, onSave: onSave),
        ),
      );
    }

    testWidgets('renders in Add Machine mode with default fields', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Add Machine'), findsWidgets);
      expect(find.text('Register a new production machine'), findsOneWidget);
      expect(find.text('Machine ID'), findsOneWidget);
      expect(find.text('Machine Name'), findsOneWidget);
      expect(find.text('Production Line'), findsOneWidget);
      expect(find.text('Health Score'), findsOneWidget);
      expect(find.text('Save Changes'), findsNothing);
    });

    testWidgets('renders in Edit Machine mode with pre-populated values and disabled ID', (tester) async {
      final existingMachine = MachineModel(
        id: 'MCH-001',
        name: 'Existing Mill',
        productionLine: 'Line 2',
        modelNumber: 'VF-2',
        status: AppConstants.machineStatusWarning,
        healthScore: 82.0,
        temperature: 75.5,
        vibration: 3.1,
      );

      await tester.pumpWidget(createTestWidget(machine: existingMachine));

      expect(find.text('Edit Machine'), findsWidgets);
      expect(find.text('Update machine information'), findsOneWidget);
      expect(find.text('MCH-001'), findsOneWidget);
      expect(find.text('Existing Mill'), findsOneWidget);
      expect(find.text('Line 2'), findsOneWidget);
      expect(find.text('VF-2'), findsOneWidget);
      expect(find.text('82.0'), findsOneWidget);
      expect(find.text('75.5'), findsOneWidget);
      expect(find.text('3.1'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('validates required fields on submission', (tester) async {
      await tester.pumpWidget(createTestWidget());

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Machine ID is required'), findsOneWidget);
      expect(find.text('Machine name is required'), findsOneWidget);
      expect(find.text('Production line is required'), findsOneWidget);
    });

    testWidgets('validates numeric fields on submission', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Fill in required text
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-99');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Test Mill');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');

      // Clear health score to invalid value
      await tester.enterText(find.widgetWithText(TextFormField, 'Health Score'), 'not-a-number');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('Enter a valid number'), findsOneWidget);
    });

    testWidgets('creates machine successfully and pops back', (tester) async {
      MachineModel? savedMachine;

      await tester.pumpWidget(
        createTestWidget(
          onSave: (m) async {
            savedMachine = m;
          },
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-NEW-01');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'New Laser Cutter');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Model Number'), 'LC-500');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(savedMachine, isNotNull);
      expect(savedMachine!.id, 'M-NEW-01');
      expect(savedMachine!.name, 'New Laser Cutter');
      expect(savedMachine!.productionLine, 'Line 1');
      expect(savedMachine!.modelNumber, 'LC-500');
      expect(find.text('Machine added successfully.'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('persists machine via MachineProvider when onSave is null', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-PROV-01');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Provider Lathe');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 2');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(machineProvider.machines.any((m) => m.id == 'M-PROV-01'), isTrue);
      final doc = await fakeFirestore.collection('machines').doc('M-PROV-01').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'Provider Lathe');
    });

    testWidgets('updates machine via MachineProvider in edit mode', (tester) async {
      final initialMachine = MachineModel(
        id: 'M-EDIT-01',
        name: 'Original Name',
        productionLine: 'Line 1',
        status: AppConstants.machineStatusOperational,
        healthScore: 90.0,
      );
      await machineProvider.addMachine(initialMachine);

      await tester.pumpWidget(createTestWidget(machine: initialMachine));

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Updated Name');

      final saveButton = find.widgetWithText(ElevatedButton, 'Save Changes');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final updated = machineProvider.getMachineById('M-EDIT-01');
      expect(updated?.name, 'Updated Name');
      expect(find.text('Machine updated successfully.'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows service error message when save fails', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          onSave: (m) async {
            throw MachineServiceException(
              code: 'permission-denied',
              message: 'Custom permission denied error',
            );
          },
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-FAIL');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Fail Mill');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Custom permission denied error'), findsOneWidget);
    });

    testWidgets('blocks non-manager role with permission error', (tester) async {
      await tester.pumpWidget(createTestWidget(role: AppConstants.roleOperator));

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-UNAUTH');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Unauthorized Machine');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission to modify machines.'), findsOneWidget);
      expect(machineProvider.machines, isEmpty);
    });

    testWidgets('prevents duplicate submissions while saving', (tester) async {
      int submissionCount = 0;
      final completer = Completer<void>();

      await tester.pumpWidget(
        createTestWidget(
          onSave: (m) async {
            submissionCount++;
            await completer.future;
          },
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-DUP');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Dup Machine');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();

      // First tap
      await tester.tap(submitButton);
      await tester.pump(); // rebuild with isLoading: true

      expect(submissionCount, 1);

      // Attempt second tap while saving (button is disabled or guarded)
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();

      expect(submissionCount, 1);

      // Complete save
      completer.complete();
      await tester.pumpAndSettle();

      expect(submissionCount, 1);
    });

    testWidgets('blocks submission when user is unauthenticated (user is null)', (tester) async {
      await tester.pumpWidget(createTestWidget(isAuthenticated: false));

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-UNAUTH');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Unauth Machine');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission to modify machines.'), findsOneWidget);
      expect(machineProvider.machines, isEmpty);
    });

    testWidgets('blocks submission when role is empty or unknown', (tester) async {
      await tester.pumpWidget(createTestWidget(role: ''));

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-EMPTY');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Empty Role Machine');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission to modify machines.'), findsOneWidget);
      expect(machineProvider.machines, isEmpty);
    });

    testWidgets('blocks submission when AppStateProvider is missing', (tester) async {
      await tester.pumpWidget(createTestWidget(provideAppState: false));

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-NOAPP');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'No App Machine');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 1');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('You do not have permission to modify machines.'), findsOneWidget);
      expect(machineProvider.machines, isEmpty);
    });

    testWidgets('surfaces user-visible duplicate-ID error when adding existing machine', (tester) async {
      final existingMachine = MachineModel(
        id: 'M-EXIST-01',
        name: 'Existing Mill',
        productionLine: 'Line 1',
        status: AppConstants.machineStatusOperational,
        healthScore: 95.0,
      );
      await machineService.addMachine(existingMachine);
      machineProvider.setMachines([existingMachine]);

      await tester.pumpWidget(createTestWidget());

      await tester.enterText(find.widgetWithText(TextFormField, 'Machine ID'), 'M-EXIST-01');
      await tester.enterText(find.widgetWithText(TextFormField, 'Machine Name'), 'Duplicate Mill');
      await tester.enterText(find.widgetWithText(TextFormField, 'Production Line'), 'Line 2');

      final submitButton = find.widgetWithText(ElevatedButton, 'Add Machine');
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Machine with ID "M-EXIST-01" already exists.'), findsOneWidget);

      final stored = await machineService.getMachineById('M-EXIST-01');
      expect(stored?.name, 'Existing Mill');
      expect(stored?.productionLine, 'Line 1');
    });
  });
}
