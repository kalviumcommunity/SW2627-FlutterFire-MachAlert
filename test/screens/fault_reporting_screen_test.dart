import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/screens/faults/fault_reporting_screen.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

class FakeFaultService extends Fake implements FaultService {
  int addFaultCallCount = 0;
  FaultModel? lastSubmittedFault;
  String docIdToReturn = 'fault-mock-123';
  Exception? exceptionToThrow;
  Completer<String>? submitCompleter;

  @override
  Future<String> addFault(FaultModel fault) async {
    addFaultCallCount++;
    lastSubmittedFault = fault;

    if (submitCompleter != null) {
      return submitCompleter!.future;
    }

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return docIdToReturn;
  }
}

MachineModel createMachine({String id = 'M-01', String name = 'CNC Machine'}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: 'Line 1',
    status: 'Operational',
    healthScore: 95,
  );
}

Future<void> pumpFaultScreen(
  WidgetTester tester, {
  List<MachineModel> machines = const [],
  MachineModel? initialMachine,
  FaultService? faultService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FaultReportingScreen(
        machines: machines,
        initialMachine: initialMachine,
        faultService: faultService ?? FakeFaultService(),
      ),
    ),
  );
}

Future<void> selectFaultType(WidgetTester tester, String faultType) async {
  final dropdown = find.byType(DropdownButtonFormField<String>).at(1);

  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(dropdown);
  await tester.pumpAndSettle();

  await tester.tap(find.text(faultType).last);

  await tester.pumpAndSettle();
}

Future<void> selectSeverity(WidgetTester tester, String severity) async {
  final chip = find.widgetWithText(ChoiceChip, severity);

  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();

  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> enterDescription(WidgetTester tester, String text) async {
  final desc = find.byType(TextFormField);

  await tester.ensureVisible(desc);
  await tester.pumpAndSettle();

  await tester.enterText(desc, text);

  await tester.pumpAndSettle();
}

Future<void> tapSubmit(WidgetTester tester) async {
  final submitButton = find.widgetWithText(FilledButton, 'Submit Fault Report');

  await tester.ensureVisible(submitButton);

  await tester.pumpAndSettle();

  await tester.tap(submitButton);
}

void main() {
  testWidgets('FaultReportingScreen displays Day 16 fault form fields', (
    tester,
  ) async {
    await pumpFaultScreen(tester, machines: [createMachine()]);

    expect(find.text('Report Machine Fault'), findsOneWidget);

    expect(find.text('Machine'), findsOneWidget);

    expect(find.text('Fault Type'), findsOneWidget);

    expect(find.text('Severity'), findsOneWidget);

    expect(find.text('Low'), findsOneWidget);

    expect(find.text('Medium'), findsOneWidget);

    expect(find.text('High'), findsOneWidget);

    expect(find.text('Critical'), findsOneWidget);

    expect(find.text('Fault Description'), findsOneWidget);

    expect(find.text('Add Photo'), findsOneWidget);

    expect(find.text('Add a fault photo'), findsOneWidget);

    expect(find.text('Camera or Gallery'), findsOneWidget);

    expect(find.text('Submit Fault Report'), findsOneWidget);
  });

  testWidgets('initial machine remains selected', (tester) async {
    final machine = createMachine();

    await pumpFaultScreen(tester, machines: [machine], initialMachine: machine);

    expect(find.text('M-01 - CNC Machine'), findsOneWidget);

    expect(find.text('CNC Machine'), findsOneWidget);

    expect(find.text('Line 1'), findsOneWidget);
  });

  testWidgets('empty fault form shows required validation', (tester) async {
    await pumpFaultScreen(tester, machines: [createMachine()]);

    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Please select a fault type.'), findsOneWidget);

    expect(find.text('Please select a severity.'), findsOneWidget);

    expect(find.text('Please describe the fault.'), findsOneWidget);
  });

  testWidgets('user can select critical severity', (tester) async {
    await pumpFaultScreen(tester, machines: [createMachine()]);

    await selectSeverity(tester, 'Critical');

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Critical'),
    );

    expect(chip.selected, isTrue);
  });

  testWidgets('submit asks for machine when none exists', (tester) async {
    await pumpFaultScreen(tester);

    await tapSubmit(tester);
    await tester.pump();

    expect(find.text('Please select a machine first.'), findsOneWidget);
  });

  testWidgets(
    'FaultReportingScreen can be instantiated with default faultService',
    (tester) async {
      const screen = FaultReportingScreen();

      expect(screen.faultService, isNull);
    },
  );

  testWidgets(
    'successful submission invokes the service once with the correct machine, type, severity and trimmed description',
    (tester) async {
      final fakeService = FakeFaultService();

      final machine = createMachine(id: 'M-01', name: 'CNC Machine');

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: fakeService,
      );

      await selectFaultType(tester, 'Mechanical');

      await selectSeverity(tester, 'Critical');

      await enterDescription(
        tester,
        '   Motor overheating with unusual vibration.   ',
      );

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(fakeService.addFaultCallCount, equals(1));

      final submitted = fakeService.lastSubmittedFault;

      expect(submitted, isNotNull);

      expect(submitted!.machineId, equals('M-01'));

      expect(submitted.machineName, equals('CNC Machine'));

      expect(submitted.type, equals('Mechanical'));

      expect(submitted.severity, equals('Critical'));

      expect(
        submitted.description,
        equals('Motor overheating with unusual vibration.'),
      );

      expect(submitted.status, equals(AppConstants.faultStatusOpen));

      expect(submitted.id, isEmpty);

      expect(submitted.reportedBy, isEmpty);

      expect(submitted.createdAt, isNull);

      expect(submitted.imageUrl, isNull);

      expect(find.text('Fault report submitted successfully.'), findsOneWidget);
    },
  );

  testWidgets(
    'missing machine, type, severity, or short description does not invoke the service',
    (tester) async {
      final fakeService = FakeFaultService();

      final machine = createMachine();

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: fakeService,
      );

      await tapSubmit(tester);
      await tester.pump();

      expect(fakeService.addFaultCallCount, equals(0));

      expect(find.text('Please select a fault type.'), findsOneWidget);

      expect(find.text('Please select a severity.'), findsOneWidget);

      expect(find.text('Please describe the fault.'), findsOneWidget);

      await selectFaultType(tester, 'Electrical');

      await selectSeverity(tester, 'High');

      await enterDescription(tester, '   Short   ');

      await tapSubmit(tester);
      await tester.pump();

      expect(fakeService.addFaultCallCount, equals(0));

      expect(find.text('Add Photo'), findsOneWidget);

      expect(find.text('Add a fault photo'), findsOneWidget);
    },
  );

  testWidgets(
    'service-level unauthenticated error displays a suitable message and does not crash',
    (tester) async {
      final fakeService = FakeFaultService();

      fakeService.exceptionToThrow = FaultServiceException(
        code: 'unauthenticated',
        message: 'User is not authenticated. Please log in.',
      );

      final machine = createMachine();

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: fakeService,
      );

      await selectFaultType(tester, 'Mechanical');

      await selectSeverity(tester, 'Medium');

      await enterDescription(tester, 'Conveyor belt slipping intermittently.');

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(fakeService.addFaultCallCount, equals(1));

      expect(
        find.text('User is not authenticated. Please log in.'),
        findsOneWidget,
      );

      expect(find.text('Submit Fault Report'), findsOneWidget);
    },
  );

  testWidgets(
    'service failure displays an error and retains entered description',
    (tester) async {
      final fakeService = FakeFaultService();

      fakeService.exceptionToThrow = FaultServiceException(
        code: 'unavailable',
        message: 'Firestore is currently unavailable. Please check your network connection.',
      );

      const enteredDescription =
          'Sensor reading fluctuating wildly under load.';

      final machine = createMachine();

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: fakeService,
      );

      await selectFaultType(tester, 'Thermal');

      await selectSeverity(tester, 'High');

      await enterDescription(tester, enteredDescription);

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(fakeService.addFaultCallCount, equals(1));

      expect(
        find.text(
          'Firestore is currently unavailable. Please check your network connection.',
        ),
        findsOneWidget,
      );

      final descFinder = find.byType(TextFormField);

      final textField = tester.widget<TextFormField>(descFinder);

      expect(textField.controller?.text, equals(enteredDescription));

      expect(find.text(enteredDescription), findsOneWidget);
    },
  );

  testWidgets(
    'generic unexpected failure displays safe error and retains description',
    (tester) async {
      final fakeService = FakeFaultService();

      fakeService.exceptionToThrow = Exception(
        'Internal server error with sensitive details',
      );

      const enteredDescription = 'Hydraulic pressure drop on main actuator.';

      final machine = createMachine();

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: fakeService,
      );

      await selectFaultType(tester, 'Hydraulic');

      await selectSeverity(tester, 'Low');

      await enterDescription(tester, enteredDescription);

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(fakeService.addFaultCallCount, equals(1));

      expect(
        find.text('Failed to submit fault report. Please try again.'),
        findsOneWidget,
      );

      expect(find.textContaining('sensitive details'), findsNothing);

      expect(find.text(enteredDescription), findsOneWidget);
    },
  );

  testWidgets(
    'submitting state prevents duplicate submission and disables relevant controls',
    (tester) async {
      final fakeService = FakeFaultService();

      final completer = Completer<String>();

      fakeService.submitCompleter = completer;

      final machine = createMachine();

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: fakeService,
      );

      await selectFaultType(tester, 'Pneumatic');

      await selectSeverity(tester, 'Critical');

      await enterDescription(
        tester,
        'Emergency stop button does not reset properly.',
      );

      await tapSubmit(tester);
      await tester.pump();

      expect(find.text('Submitting...'), findsOneWidget);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final submittingButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submitting...'),
      );

      expect(submittingButton.onPressed, isNull);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Submitting...'),
        warnIfMissed: false,
      );

      await tester.pump();

      expect(fakeService.addFaultCallCount, equals(1));

      final descField = tester.widget<TextFormField>(
        find.byType(TextFormField),
      );

      expect(descField.enabled, isFalse);

      final lowChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Low'),
      );

      expect(lowChip.onSelected, isNull);

      completer.complete('fault-doc-complete-1');

      await tester.pumpAndSettle();

      expect(find.text('Fault report submitted successfully.'), findsOneWidget);
    },
  );

  testWidgets(
    'successful submission pops with created document ID when navigation stack allows popping',
    (tester) async {
      final fakeService = FakeFaultService();

      fakeService.docIdToReturn = 'doc-nav-pop-456';

      dynamic popResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popResult = await Navigator.of(context).push<dynamic>(
                    MaterialPageRoute<dynamic>(
                      builder: (_) => FaultReportingScreen(
                        machines: [createMachine()],
                        initialMachine: createMachine(),
                        faultService: fakeService,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));

      await tester.pumpAndSettle();

      await selectFaultType(tester, 'Mechanical');

      await selectSeverity(tester, 'High');

      await enterDescription(
        tester,
        'Spindle bearing noise detected during warmup.',
      );

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(popResult, equals('doc-nav-pop-456'));

      expect(find.text('Fault report submitted successfully.'), findsOneWidget);
    },
  );
}
