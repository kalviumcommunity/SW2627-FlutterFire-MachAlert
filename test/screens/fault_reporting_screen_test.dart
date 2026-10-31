import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mach_alert/main.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/screens/faults/fault_reporting_screen.dart';
import 'package:mach_alert/services/auth_service.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/widgets/fault_image_attachment_picker.dart';
import 'package:provider/provider.dart';

class FakeStorageService extends Fake implements StorageService {
  int uploadCallCount = 0;
  Uint8List? lastUploadedBytes;
  String? lastUploadedFileName;
  String? lastUploadedContentType;
  String downloadUrlToReturn =
      'https://firebasestorage.googleapis.com/v0/b/bucket/o/fault_images%2Fphoto.jpg?alt=media';
  Exception? exceptionToThrow;
  Completer<String>? uploadCompleter;

  @override
  Future<String> uploadFaultImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    uploadCallCount++;
    lastUploadedBytes = bytes;
    lastUploadedFileName = fileName;
    lastUploadedContentType = contentType;

    if (uploadCompleter != null) {
      return uploadCompleter!.future;
    }

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return downloadUrlToReturn;
  }
}

class FakeUser extends Fake implements User {
  @override
  final String uid;

  FakeUser({this.uid = 'test-operator-1'});
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  Stream<User?> authStateChanges() {
    return const Stream<User?>.empty();
  }

  @override
  User? get currentUser => FakeUser();

  @override
  Future<void> signOut() async {}
}

class FakeUserService extends Fake implements UserService {}

Uint8List createSampleImageBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB'
    'CAQAAAC1HAwCAAAAC0lEQVR42mP8/x8A'
    'AusB9Y9ZcNAAAAAASUVORK5CYII=',
  );
}

class ControllableReadXFile extends XFile {
  final Uint8List previewBytes;
  final Completer<Uint8List> secondReadCompleter;
  int readCount = 0;

  ControllableReadXFile(
    this.previewBytes,
    this.secondReadCompleter, {
    String path = 'slow_read.png',
    String name = 'slow_read.png',
  }) : super(path, name: name);

  @override
  Future<Uint8List> readAsBytes() {
    readCount++;
    if (readCount == 1) {
      return Future.value(previewBytes);
    }
    return secondReadCompleter.future;
  }
}

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
  StorageService? storageService,
  FaultImagePickCallback? pickImage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FaultReportingScreen(
        machines: machines,
        initialMachine: initialMachine,
        faultService: faultService ?? FakeFaultService(),
        storageService: storageService ?? FakeStorageService(),
        pickImage: pickImage,
      ),
    ),
  );
}

Future<void> pickTestImageFromGallery(WidgetTester tester) async {
  final pickerFinder = find.byKey(const ValueKey('fault-image-picker'));
  await tester.ensureVisible(pickerFinder);
  await tester.pumpAndSettle();

  await tester.tap(pickerFinder);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Gallery'));
  await tester.pumpAndSettle();
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

  group('Day 16 Fault Image Upload Integration', () {
    testWidgets(
      '1. Selected image uploads successfully and download URL is stored in FaultModel.imageUrl',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeStorageService = FakeStorageService();
        const expectedDownloadUrl =
            'https://firebasestorage.googleapis.com/v0/b/bucket/o/fault_images%2Fspindle.png?alt=media';
        fakeStorageService.downloadUrlToReturn = expectedDownloadUrl;

        final machine = createMachine(id: 'M-01', name: 'CNC Machine');
        final sampleBytes = createSampleImageBytes();

        await pumpFaultScreen(
          tester,
          machines: [machine],
          initialMachine: machine,
          faultService: fakeFaultService,
          storageService: fakeStorageService,
          pickImage: (source) async {
            expect(source, equals(ImageSource.gallery));
            return XFile.fromData(
              sampleBytes,
              path: 'broken_spindle.png',
              name: 'broken_spindle.png',
              mimeType: 'image/png',
            );
          },
        );

        await selectFaultType(tester, 'Mechanical');
        await selectSeverity(tester, 'Critical');
        await enterDescription(
          tester,
          'Spindle shattered during operation, urgent repair.',
        );

        final pickerFinder = find.byKey(const ValueKey('fault-image-picker'));
        await tester.ensureVisible(pickerFinder);
        await tester.pumpAndSettle();

        expect(find.text('Add a fault photo'), findsOneWidget);

        await pickTestImageFromGallery(tester);

        expect(find.text('Add a fault photo'), findsNothing);
        expect(find.text('Photo ready to upload'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('fault-image-preview')),
          findsOneWidget,
        );

        await tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(fakeStorageService.uploadCallCount, equals(1));
        expect(
          fakeStorageService.lastUploadedFileName,
          equals('broken_spindle.png'),
        );
        expect(fakeStorageService.lastUploadedContentType, equals('image/png'));
        expect(fakeStorageService.lastUploadedBytes, equals(sampleBytes));

        expect(fakeFaultService.addFaultCallCount, equals(1));
        final submitted = fakeFaultService.lastSubmittedFault;
        expect(submitted, isNotNull);
        expect(submitted!.imageUrl, equals(expectedDownloadUrl));
        expect(submitted.machineId, equals('M-01'));
        expect(submitted.type, equals('Mechanical'));
        expect(submitted.severity, equals('Critical'));
        expect(
          submitted.description,
          equals('Spindle shattered during operation, urgent repair.'),
        );

        expect(
          find.text('Fault report submitted successfully.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('2. Image content-type is determined correctly for JPEG', (
      tester,
    ) async {
      final fakeFaultService = FakeFaultService();
      final fakeStorageService = FakeStorageService();
      final machine = createMachine();

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: fakeFaultService,
        storageService: fakeStorageService,
        pickImage: (_) async => XFile.fromData(
          createSampleImageBytes(),
          path: 'motor_overheat.jpg',
          name: 'motor_overheat.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      await selectFaultType(tester, 'Thermal');
      await selectSeverity(tester, 'High');
      await enterDescription(tester, 'Motor housing overheating excessively.');
      await pickTestImageFromGallery(tester);

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(fakeStorageService.lastUploadedContentType, equals('image/jpeg'));
      expect(
        fakeStorageService.lastUploadedFileName,
        equals('motor_overheat.jpg'),
      );
    });

    testWidgets('2b. Image content-type is determined correctly for WebP', (
      tester,
    ) async {
      final machine = createMachine();
      final webpStorage = FakeStorageService();
      final webpFault = FakeFaultService();

      await pumpFaultScreen(
        tester,
        machines: [machine],
        initialMachine: machine,
        faultService: webpFault,
        storageService: webpStorage,
        pickImage: (_) async => XFile.fromData(
          createSampleImageBytes(),
          path: 'gear_teeth.webp',
          name: 'gear_teeth.webp',
        ),
      );

      await selectFaultType(tester, 'Mechanical');
      await selectSeverity(tester, 'Medium');
      await enterDescription(tester, 'Gear teeth chipped on secondary drive.');
      await pickTestImageFromGallery(tester);

      await tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(webpStorage.lastUploadedContentType, equals('image/webp'));
      expect(webpStorage.lastUploadedFileName, equals('gear_teeth.webp'));
    });

    testWidgets(
      '3. Submitting without an image skips StorageService and saves null imageUrl',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeStorageService = FakeStorageService();
        final machine = createMachine();

        await pumpFaultScreen(
          tester,
          machines: [machine],
          initialMachine: machine,
          faultService: fakeFaultService,
          storageService: fakeStorageService,
        );

        await selectFaultType(tester, 'Electrical');
        await selectSeverity(tester, 'Low');
        await enterDescription(
          tester,
          'Status indicator LED flickers intermittently.',
        );

        await tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(fakeStorageService.uploadCallCount, equals(0));
        expect(fakeFaultService.addFaultCallCount, equals(1));
        expect(fakeFaultService.lastSubmittedFault?.imageUrl, isNull);
        expect(
          find.text('Fault report submitted successfully.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '4. StorageServiceException displays safe error and does not create fault document',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeStorageService = FakeStorageService();
        fakeStorageService.exceptionToThrow = StorageServiceException(
          code: 'retry-limit-exceeded',
          message: 'The upload timed out or exceeded the retry limit. Please try again.',
        );

        final machine = createMachine();

        await pumpFaultScreen(
          tester,
          machines: [machine],
          initialMachine: machine,
          faultService: fakeFaultService,
          storageService: fakeStorageService,
          pickImage: (_) async => XFile.fromData(
            createSampleImageBytes(),
            path: 'sensor_fault.png',
            name: 'sensor_fault.png',
          ),
        );

        await selectFaultType(tester, 'Mechanical');
        await selectSeverity(tester, 'Critical');
        await enterDescription(
          tester,
          'Conveyor belt torn near feeder entrance.',
        );

        await pickTestImageFromGallery(tester);
        await tapSubmit(tester);
        await tester.pumpAndSettle();

        // Storage was attempted, but fault was NOT created
        expect(fakeStorageService.uploadCallCount, equals(1));
        expect(fakeFaultService.addFaultCallCount, equals(0));

        expect(
          find.text(
            'The upload timed out or exceeded the retry limit. Please try again.',
          ),
          findsOneWidget,
        );

        // Submitting state restored
        expect(find.text('Submit Fault Report'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Storage failure preserves entered form values and selected image for user retry',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeStorageService = FakeStorageService();
        fakeStorageService.exceptionToThrow = StorageServiceException(
          code: 'quota-exceeded',
          message: 'Storage quota exceeded. Please contact your system administrator.',
        );

        const description =
            'Bearing lubrication failure causing intense friction.';
        final machine = createMachine();

        await pumpFaultScreen(
          tester,
          machines: [machine],
          initialMachine: machine,
          faultService: fakeFaultService,
          storageService: fakeStorageService,
          pickImage: (_) async => XFile.fromData(
            createSampleImageBytes(),
            path: 'bearing_friction.png',
            name: 'bearing_friction.png',
          ),
        );

        await selectFaultType(tester, 'Mechanical');
        await selectSeverity(tester, 'High');
        await enterDescription(tester, description);
        await pickTestImageFromGallery(tester);

        await tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(fakeStorageService.uploadCallCount, equals(1));
        expect(fakeFaultService.addFaultCallCount, equals(0));

        // Form values and image preview remain intact
        expect(find.text(description), findsOneWidget);
        expect(find.text('Photo ready to upload'), findsOneWidget);
        expect(find.text('M-01 - CNC Machine'), findsOneWidget);

        // User retries after fixing the error condition
        fakeStorageService.exceptionToThrow = null;
        fakeStorageService.downloadUrlToReturn =
            'https://download.url/bearing.png';

        // Clear error SnackBar so it does not intercept the second submit tap
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold)))
            .clearSnackBars();
        await tester.pumpAndSettle();

        await tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(fakeStorageService.uploadCallCount, equals(2));
        expect(fakeFaultService.addFaultCallCount, equals(1));
        expect(
          fakeFaultService.lastSubmittedFault?.imageUrl,
          equals('https://download.url/bearing.png'),
        );
        expect(
          find.text('Fault report submitted successfully.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '6. Firestore failure after upload displays error without clearing form or photo',
      (tester) async {
        final fakeStorageService = FakeStorageService();
        fakeStorageService.downloadUrlToReturn =
            'https://download.url/photo.jpg';

        final fakeFaultService = FakeFaultService();
        fakeFaultService.exceptionToThrow = FaultServiceException(
          code: 'permission-denied',
          message: 'You do not have permission to log faults.',
        );

        const description =
            'Hydraulic fluid leaking beneath main pressure manifold.';
        final machine = createMachine();

        await pumpFaultScreen(
          tester,
          machines: [machine],
          initialMachine: machine,
          faultService: fakeFaultService,
          storageService: fakeStorageService,
          pickImage: (_) async => XFile.fromData(
            createSampleImageBytes(),
            path: 'leak.jpg',
            name: 'leak.jpg',
          ),
        );

        await selectFaultType(tester, 'Hydraulic');
        await selectSeverity(tester, 'Critical');
        await enterDescription(tester, description);
        await pickTestImageFromGallery(tester);

        await tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(fakeStorageService.uploadCallCount, equals(1));
        expect(fakeFaultService.addFaultCallCount, equals(1));

        expect(
          find.text('You do not have permission to log faults.'),
          findsOneWidget,
        );

        // Form state preserved
        expect(find.text(description), findsOneWidget);
        expect(find.text('Photo ready to upload'), findsOneWidget);
        expect(find.text('Submit Fault Report'), findsOneWidget);
      },
    );

    testWidgets(
      '7. Duplicate submission requests while upload is active are blocked',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeStorageService = FakeStorageService();
        final uploadCompleter = Completer<String>();
        fakeStorageService.uploadCompleter = uploadCompleter;

        final machine = createMachine();

        await pumpFaultScreen(
          tester,
          machines: [machine],
          initialMachine: machine,
          faultService: fakeFaultService,
          storageService: fakeStorageService,
          pickImage: (_) async => XFile.fromData(
            createSampleImageBytes(),
            path: 'valve.png',
            name: 'valve.png',
          ),
        );

        await selectFaultType(tester, 'Pneumatic');
        await selectSeverity(tester, 'High');
        await enterDescription(
          tester,
          'Pneumatic cylinder valve stuck in open position.',
        );
        await pickTestImageFromGallery(tester);

        await tapSubmit(tester);
        await tester.pump();

        expect(find.text('Submitting...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(fakeStorageService.uploadCallCount, equals(1));

        // Attempt duplicate tap while submitting
        await tester.tap(
          find.widgetWithText(FilledButton, 'Submitting...'),
          warnIfMissed: false,
        );
        await tester.pump();

        expect(fakeStorageService.uploadCallCount, equals(1));
        expect(fakeFaultService.addFaultCallCount, equals(0));

        // Complete upload
        uploadCompleter.complete('https://download.url/valve.png');
        await tester.pumpAndSettle();

        expect(fakeFaultService.addFaultCallCount, equals(1));
        expect(
          fakeFaultService.lastSubmittedFault?.imageUrl,
          equals('https://download.url/valve.png'),
        );
        expect(
          find.text('Fault report submitted successfully.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '8. Generic unexpected upload failure displays safe message and does not call addFault',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeStorageService = FakeStorageService();
        fakeStorageService.exceptionToThrow = Exception(
          'Sensitive socket crash details with server IP',
        );

        final machine = createMachine();

        await pumpFaultScreen(
          tester,
          machines: [machine],
          initialMachine: machine,
          faultService: fakeFaultService,
          storageService: fakeStorageService,
          pickImage: (_) async => XFile.fromData(
            createSampleImageBytes(),
            path: 'crash.jpg',
            name: 'crash.jpg',
          ),
        );

        await selectFaultType(tester, 'Mechanical');
        await selectSeverity(tester, 'Medium');
        await enterDescription(
          tester,
          'Coolant pump rattling violently at high RPM.',
        );
        await pickTestImageFromGallery(tester);

        await tapSubmit(tester);
        await tester.pumpAndSettle();

        expect(fakeStorageService.uploadCallCount, equals(1));
        expect(fakeFaultService.addFaultCallCount, equals(0));

        expect(
          find.text('Failed to submit fault report. Please try again.'),
          findsOneWidget,
        );
        expect(find.textContaining('Sensitive socket crash'), findsNothing);
      },
    );

    testWidgets(
      '9. MachAlertApp registers StorageService in application MultiProvider',
      (tester) async {
        final fakeStorageService = FakeStorageService();
        final fakeAuthService = AuthService(firebaseAuth: FakeFirebaseAuth());

        await tester.pumpWidget(
          MachAlertApp(
            storageService: fakeStorageService,
            authService: fakeAuthService,
            userService: FakeUserService(),
          ),
        );

        final materialAppContext = tester.element(find.byType(MaterialApp));
        expect(
          materialAppContext.read<StorageService>(),
          equals(fakeStorageService),
        );
      },
    );

    testWidgets(
      '10. Unmounting during image byte reading does not trigger upload or access deactivated context',
      (tester) async {
        final fakeFaultService = FakeFaultService();
        final fakeStorageService = FakeStorageService();
        final readCompleter = Completer<Uint8List>();
        final delayedImage = ControllableReadXFile(
          createSampleImageBytes(),
          readCompleter,
          path: 'slow_read.png',
          name: 'slow_read.png',
        );

        final machine = createMachine();

        // Omit storageService on FaultReportingScreen so fallback attempts context lookup
        await tester.pumpWidget(
          Provider<StorageService>.value(
            value: fakeStorageService,
            child: MaterialApp(
              home: FaultReportingScreen(
                machines: [machine],
                initialMachine: machine,
                faultService: fakeFaultService,
                pickImage: (_) async => delayedImage,
              ),
            ),
          ),
        );

        await selectFaultType(tester, 'Electrical');
        await selectSeverity(tester, 'High');
        await enterDescription(
          tester,
          'Power surge causing intermittent spindle stoppage.',
        );
        await pickTestImageFromGallery(tester);

        // Submit form: begins _submit(), awaits delayedImage.readAsBytes()
        await tapSubmit(tester);
        await tester.pump();

        expect(delayedImage.readCount, equals(2));
        expect(fakeStorageService.uploadCallCount, equals(0));

        // Unmount the widget while reading image bytes is in flight
        await tester.pumpWidget(const SizedBox());

        // Complete the pending byte-read after unmount
        readCompleter.complete(createSampleImageBytes());
        await tester.pumpAndSettle();

        // Verification:
        // No upload was attempted after unmounting, and context was not looked up on deactivated element
        expect(fakeStorageService.uploadCallCount, equals(0));
        expect(fakeFaultService.addFaultCallCount, equals(0));
      },
    );
  });
}
