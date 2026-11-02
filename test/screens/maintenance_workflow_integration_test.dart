// ignore_for_file: subtype_of_sealed_class

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mach_alert/models/maintenance_update_model.dart';
import 'package:mach_alert/screens/maintenance/maintenance_details_screen.dart';
import 'package:mach_alert/screens/maintenance/maintenance_list_screen.dart';
import 'package:mach_alert/services/maintenance_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/widgets/fault_image_attachment_picker.dart';

final kTransparentImage = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class FakeUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  FakeUser({required this.uid, this.email});
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;

  FakeFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  void setCurrentUser(User? user) {
    _currentUser = user;
  }
}

class FakeStorageService extends Fake implements StorageService {
  int uploadCallCount = 0;
  Uint8List? lastUploadedBytes;
  String? lastUploadedFileName;
  String? lastUploadedContentType;
  String? lastUploadedFolder;
  String downloadUrlToReturn =
      'https://firebasestorage.googleapis.com/v0/b/bucket/o/maintenance_proofs%2Fproof.jpg?alt=media';
  Exception? exceptionToThrow;

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    String folder = StorageService.defaultFolder,
  }) async {
    uploadCallCount++;
    lastUploadedBytes = bytes;
    lastUploadedFileName = fileName;
    lastUploadedContentType = contentType;
    lastUploadedFolder = folder;

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return downloadUrlToReturn;
  }
}

Future<void> openStatusSheet(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('update-maintenance-status-button'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> saveStatusSheet(WidgetTester tester) async {
  final saveButton = find.byKey(const ValueKey('save-maintenance-status'));
  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakeFirebaseAuth fakeAuth;
  late MaintenanceService maintenanceService;
  late FakeStorageService fakeStorageService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    fakeAuth = FakeFirebaseAuth(
      initialUser: FakeUser(uid: 'tech_001', email: 'tech@machalert.com'),
    );
    maintenanceService = MaintenanceService(
      firestore: fakeFirestore,
      firebaseAuth: fakeAuth,
    );
    fakeStorageService = FakeStorageService();
  });

  Future<void> seedTask({
    required String taskId,
    required String status,
    String originalNotes = 'Original assignment note',
  }) async {
    await fakeFirestore
        .collection(AppConstants.maintenanceCollection)
        .doc(taskId)
        .set({
          'id': taskId,
          'machineId': 'CNC-01',
          'machineName': 'CNC Milling Unit 01',
          'technicianId': 'tech_001',
          'technicianName': 'Technician Team',
          'priority': 'High',
          'status': status,
          'notes': originalNotes,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'updateHistory': <String, dynamic>{},
        });
  }

  Widget buildDetailsScreen({
    required String taskId,
    required String status,
    MaintenanceStatusUpdateCallback? onStatusUpdate,
    FaultImagePickCallback? pickImage,
    List<MaintenanceUpdateModel>? initialHistory,
  }) {
    return MaterialApp(
      home: MaintenanceDetailsScreen(
        maintenanceId: taskId,
        title: 'Inspect spindle vibration',
        machineName: 'CNC Milling Unit 01',
        technician: 'Technician Team',
        priority: 'High',
        status: status,
        dueDate: 'Today',
        maintenanceService: maintenanceService,
        storageService: fakeStorageService,
        onStatusUpdate: onStatusUpdate,
        pickImage: pickImage,
        initialHistory: initialHistory,
      ),
    );
  }

  group('Day 18 Member 3: Maintenance Workflow UI Integration', () {
    testWidgets(
      '1. Successful status update from UI to service (Pending -> In Progress)',
      (tester) async {
        await seedTask(taskId: 'task_001', status: 'Pending');

        await tester.pumpWidget(
          buildDetailsScreen(taskId: 'task_001', status: 'Pending'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pending'), findsWidgets);

        await openStatusSheet(tester);

        final inProgressChip = find.widgetWithText(ChoiceChip, 'In Progress');
        await tester.tap(inProgressChip);
        await tester.pump();

        final notesField = find.byKey(
          const ValueKey('maintenance-update-notes'),
        );
        await tester.enterText(notesField, 'Started diagnostics on spindle');
        await tester.pump();

        await saveStatusSheet(tester);

        expect(
          find.text('Maintenance status updated to In Progress.'),
          findsOneWidget,
        );

        // Verify Firestore was updated
        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_001')
            .get();
        expect(doc.data()?['status'], equals('In Progress'));

        // Verify original notes are preserved
        expect(doc.data()?['notes'], equals('Original assignment note'));

        // Verify updateHistory has the entry
        final history = doc.data()?['updateHistory'] as Map<String, dynamic>;
        expect(history.length, equals(1));
        final entry = history.values.first as Map<String, dynamic>;
        expect(entry['previousStatus'], equals('Pending'));
        expect(entry['newStatus'], equals('In Progress'));
        expect(entry['notes'], equals('Started diagnostics on spindle'));
        expect(entry['updatedBy'], equals('tech_001'));
      },
    );

    testWidgets(
      '2. In Progress -> Completed normalizes to canonical Resolved in Firestore',
      (tester) async {
        await seedTask(taskId: 'task_002', status: 'In Progress');

        await tester.pumpWidget(
          buildDetailsScreen(taskId: 'task_002', status: 'In Progress'),
        );
        await tester.pumpAndSettle();

        await openStatusSheet(tester);

        final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
        await tester.tap(completedChip);
        await tester.pump();

        final notesField = find.byKey(
          const ValueKey('maintenance-update-notes'),
        );
        await tester.enterText(notesField, 'Replaced faulty bearing');
        await tester.pump();

        await saveStatusSheet(tester);

        expect(
          find.text('Maintenance status updated to Completed.'),
          findsOneWidget,
        );

        // Verify Firestore stored canonical Resolved
        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_002')
            .get();
        expect(
          doc.data()?['status'],
          equals(AppConstants.maintenanceStatusResolved),
        );

        // Original notes untouched
        expect(doc.data()?['notes'], equals('Original assignment note'));

        final history = doc.data()?['updateHistory'] as Map<String, dynamic>;
        expect(history.length, equals(1));
        final entry = history.values.first as Map<String, dynamic>;
        expect(entry['previousStatus'], equals('In Progress'));
        expect(
          entry['newStatus'],
          equals(AppConstants.maintenanceStatusResolved),
        );
        expect(entry['notes'], equals('Replaced faulty bearing'));
      },
    );

    testWidgets(
      '3. Attaching photo proof uploads to Storage and passes proofImageUrl',
      (tester) async {
        await seedTask(taskId: 'task_003', status: 'In Progress');

        final sampleBytes = kTransparentImage;

        await tester.pumpWidget(
          buildDetailsScreen(
            taskId: 'task_003',
            status: 'In Progress',
            pickImage: (source) async => XFile.fromData(
              sampleBytes,
              name: 'repair_proof.png',
              path: 'repair_proof.png',
            ),
          ),
        );
        await tester.pumpAndSettle();

        await openStatusSheet(tester);

        final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
        await tester.tap(completedChip);
        await tester.pump();

        // Tap attach photo proof button
        final attachButton = find.byKey(
          const ValueKey('attach-maintenance-proof-button'),
        );
        await tester.ensureVisible(attachButton);
        await tester.tap(attachButton);
        await tester.pumpAndSettle();

        // Choose camera or gallery
        final cameraTile = find.byKey(const ValueKey('pick-proof-camera'));
        await tester.tap(cameraTile);
        await tester.pumpAndSettle();

        // Verify photo attachment preview appears
        expect(
          find.byKey(const ValueKey('maintenance-proof-preview')),
          findsOneWidget,
        );
        expect(find.text('Photo Proof Attached'), findsOneWidget);

        await saveStatusSheet(tester);

        // Verify StorageService was called with correct parameters
        expect(fakeStorageService.uploadCallCount, equals(1));
        expect(
          fakeStorageService.lastUploadedFileName,
          equals('repair_proof.png'),
        );
        expect(
          fakeStorageService.lastUploadedFolder,
          equals('maintenance_proofs'),
        );
        expect(fakeStorageService.lastUploadedContentType, equals('image/png'));
        expect(fakeStorageService.lastUploadedBytes, equals(sampleBytes));

        // Verify proofImageUrl was written to Firestore history entry
        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_003')
            .get();
        final history = doc.data()?['updateHistory'] as Map<String, dynamic>;
        final entry = history.values.first as Map<String, dynamic>;
        expect(
          entry['proofImageUrl'],
          equals(fakeStorageService.downloadUrlToReturn),
        );
      },
    );

    testWidgets(
      '4. Removing attached photo proof clears the attachment before saving',
      (tester) async {
        await seedTask(taskId: 'task_004', status: 'In Progress');

        await tester.pumpWidget(
          buildDetailsScreen(
            taskId: 'task_004',
            status: 'In Progress',
            pickImage: (source) async =>
                XFile.fromData(kTransparentImage, name: 'temp_proof.jpg'),
          ),
        );
        await tester.pumpAndSettle();

        await openStatusSheet(tester);

        final attachButton = find.byKey(
          const ValueKey('attach-maintenance-proof-button'),
        );
        await tester.tap(attachButton);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('pick-proof-gallery')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('maintenance-proof-preview')),
          findsOneWidget,
        );

        // Tap remove button
        await tester.tap(
          find.byKey(const ValueKey('remove-maintenance-proof-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('maintenance-proof-preview')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('attach-maintenance-proof-button')),
          findsOneWidget,
        );

        // Enter notes and save
        final notesField = find.byKey(
          const ValueKey('maintenance-update-notes'),
        );
        await tester.enterText(notesField, 'Completed without photo');
        await tester.pump();

        final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
        await tester.tap(completedChip);
        await tester.pump();

        await saveStatusSheet(tester);

        expect(fakeStorageService.uploadCallCount, equals(0));

        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_004')
            .get();
        final history = doc.data()?['updateHistory'] as Map<String, dynamic>;
        final entry = history.values.first as Map<String, dynamic>;
        expect(entry['proofImageUrl'], isNull);
      },
    );

    testWidgets(
      '5. Invalid transition (Pending -> Resolved) is rejected with error feedback and preserves status',
      (tester) async {
        await seedTask(taskId: 'task_005', status: 'Pending');

        await tester.pumpWidget(
          buildDetailsScreen(taskId: 'task_005', status: 'Pending'),
        );
        await tester.pumpAndSettle();

        await openStatusSheet(tester);

        // Attempt jump straight from Pending to Completed
        final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
        await tester.tap(completedChip);
        await tester.pump();

        await saveStatusSheet(tester);

        // Verify safe error message is displayed
        expect(
          find.text(
            'The requested maintenance status transition is not permitted.',
          ),
          findsOneWidget,
        );

        // Verify status in UI was NOT updated
        expect(find.text('Pending'), findsWidgets);

        // Verify Firestore was NOT updated
        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_005')
            .get();
        expect(doc.data()?['status'], equals('Pending'));
        final history = doc.data()?['updateHistory'] as Map<String, dynamic>;
        expect(history.isEmpty, isTrue);
      },
    );

    testWidgets(
      '6. Terminal state: attempting to transition away from Resolved is rejected',
      (tester) async {
        await seedTask(
          taskId: 'task_006',
          status: AppConstants.maintenanceStatusResolved,
        );

        await tester.pumpWidget(
          buildDetailsScreen(taskId: 'task_006', status: 'Completed'),
        );
        await tester.pumpAndSettle();

        await openStatusSheet(tester);

        final inProgressChip = find.widgetWithText(ChoiceChip, 'In Progress');
        await tester.tap(inProgressChip);
        await tester.pump();

        await saveStatusSheet(tester);

        expect(
          find.text(
            'This maintenance task has already been resolved and cannot be modified.',
          ),
          findsOneWidget,
        );

        // Verify Firestore was unchanged
        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_006')
            .get();
        expect(
          doc.data()?['status'],
          equals(AppConstants.maintenanceStatusResolved),
        );
      },
    );

    testWidgets('7. Same-status update without note or proof is rejected', (
      tester,
    ) async {
      await seedTask(taskId: 'task_007', status: 'In Progress');

      await tester.pumpWidget(
        buildDetailsScreen(taskId: 'task_007', status: 'In Progress'),
      );
      await tester.pumpAndSettle();

      await openStatusSheet(tester);

      // Keep In Progress without adding notes or photo
      await saveStatusSheet(tester);

      expect(
        find.text(
          'Status update must include a status change, note, or photo proof.',
        ),
        findsOneWidget,
      );

      final doc = await fakeFirestore
          .collection(AppConstants.maintenanceCollection)
          .doc('task_007')
          .get();
      final history = doc.data()?['updateHistory'] as Map<String, dynamic>;
      expect(history.isEmpty, isTrue);
    });

    testWidgets(
      '8. Same-status update with a repair note succeeds and appends to history',
      (tester) async {
        await seedTask(taskId: 'task_008', status: 'In Progress');

        await tester.pumpWidget(
          buildDetailsScreen(taskId: 'task_008', status: 'In Progress'),
        );
        await tester.pumpAndSettle();

        await openStatusSheet(tester);

        final notesField = find.byKey(
          const ValueKey('maintenance-update-notes'),
        );
        await tester.enterText(
          notesField,
          'Checked pressure valves, working normal',
        );
        await tester.pump();

        await saveStatusSheet(tester);

        expect(
          find.text('Maintenance status updated to In Progress.'),
          findsOneWidget,
        );

        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_008')
            .get();
        final history = doc.data()?['updateHistory'] as Map<String, dynamic>;
        expect(history.length, equals(1));
        final entry = history.values.first as Map<String, dynamic>;
        expect(entry['previousStatus'], equals('In Progress'));
        expect(entry['newStatus'], equals('In Progress'));
        expect(
          entry['notes'],
          equals('Checked pressure valves, working normal'),
        );
      },
    );

    testWidgets(
      '9. Unauthenticated update shows user-safe error and leaves task untouched',
      (tester) async {
        await seedTask(taskId: 'task_009', status: 'Pending');

        // Simulate unauthenticated user
        fakeAuth.setCurrentUser(null);

        await tester.pumpWidget(
          buildDetailsScreen(taskId: 'task_009', status: 'Pending'),
        );
        await tester.pumpAndSettle();

        await openStatusSheet(tester);

        final inProgressChip = find.widgetWithText(ChoiceChip, 'In Progress');
        await tester.tap(inProgressChip);
        await tester.pump();

        await saveStatusSheet(tester);

        expect(
          find.text('User is not authenticated. Please log in.'),
          findsOneWidget,
        );

        final doc = await fakeFirestore
            .collection(AppConstants.maintenanceCollection)
            .doc('task_009')
            .get();
        expect(doc.data()?['status'], equals('Pending'));
      },
    );

    testWidgets(
      '10. Maintenance history is rendered with previous status, new status, notes, updatedBy and timestamp',
      (tester) async {
        final now = DateTime(2026, 10, 31, 14, 30);
        final historyItems = [
          MaintenanceUpdateModel(
            id: 'upd_1',
            taskId: 'task_010',
            previousStatus: 'Pending',
            newStatus: 'In Progress',
            notes: 'Diagnostics initiated',
            updatedBy: 'tech_001',
            updatedAt: now,
          ),
          MaintenanceUpdateModel(
            id: 'upd_2',
            taskId: 'task_010',
            previousStatus: 'In Progress',
            newStatus: 'Resolved',
            notes: 'Spindle calibrated and verified',
            proofImageUrl: 'https://storage.googleapis.com/proof.jpg',
            updatedBy: 'tech_001',
            updatedAt: now.add(const Duration(hours: 2)),
          ),
        ];

        await tester.pumpWidget(
          buildDetailsScreen(
            taskId: 'task_010',
            status: 'Completed',
            initialHistory: historyItems,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('maintenance-history-card')),
          findsOneWidget,
        );
        expect(find.text('Maintenance History'), findsOneWidget);

        // First history entry
        expect(find.text('Pending → In Progress'), findsOneWidget);
        expect(find.text('Diagnostics initiated'), findsOneWidget);
        expect(find.text('Updated by: tech_001'), findsNWidgets(2));
        expect(find.text('2026-10-31 14:30'), findsOneWidget);

        // Second history entry
        expect(find.text('In Progress → Resolved'), findsOneWidget);
        expect(find.text('Spindle calibrated and verified'), findsOneWidget);
        expect(find.text('Photo proof attached'), findsOneWidget);
        expect(find.text('2026-10-31 16:30'), findsOneWidget);
      },
    );

    testWidgets(
      '11. Real-time stream updates refresh UI history and task status without manual page reload',
      (tester) async {
        await seedTask(taskId: 'task_011', status: 'Pending');

        await tester.pumpWidget(
          buildDetailsScreen(taskId: 'task_011', status: 'Pending'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pending'), findsWidgets);
        expect(find.text('No updates recorded yet.'), findsOneWidget);

        // External update to In Progress with history entry
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'task_011',
          status: 'In Progress',
          notes: 'Technician started calibration',
        );

        // Pump frames to let stream emit and widget react
        await tester.pumpAndSettle();

        // Verify history rendered
        expect(find.text('Pending → In Progress'), findsOneWidget);
        expect(find.text('Technician started calibration'), findsOneWidget);

        // Verify UI status chip synchronized to In Progress
        expect(find.text('In Progress'), findsWidgets);
      },
    );

    testWidgets(
      '12. MaintenanceListScreen streams tasks in real-time and reflects status changes',
      (tester) async {
        await seedTask(
          taskId: 'MNT-REAL-1',
          status: 'Pending',
          originalNotes: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceListScreen(maintenanceService: maintenanceService),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Maintenance Task #MNT-REAL-1'), findsOneWidget);
        expect(find.text('Pending'), findsWidgets);

        // Update task via service
        await maintenanceService.updateMaintenanceStatus(
          taskId: 'MNT-REAL-1',
          status: 'In Progress',
          notes: 'Started work on task',
        );

        await tester.pumpAndSettle();

        // Verify list screen updated in real-time
        expect(find.text('In Progress'), findsWidgets);

        // Tap the card to open details
        await tester.tap(find.text('Maintenance Task #MNT-REAL-1'));
        await tester.pumpAndSettle();

        expect(find.byType(MaintenanceDetailsScreen), findsOneWidget);
        expect(find.text('MNT-REAL-1'), findsOneWidget);
      },
    );
  });
}
