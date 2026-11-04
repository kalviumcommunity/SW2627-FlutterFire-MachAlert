import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/screens/faults/fault_history_screen.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/user_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

class FakeUserService extends Fake implements UserService {
  final Map<String, UserModel> users = {};
  int getUserProfileCallCount = 0;

  @override
  Future<UserModel?> getUserProfile(
    String uid, {
    Source source = Source.server,
  }) async {
    getUserProfileCallCount++;
    return users[uid];
  }
}

class FakeFaultService extends Fake implements FaultService {
  int getFaultsCallCount = 0;

  String? lastMachineIdFilter;
  String? lastStatusFilter;
  String? lastSeverityFilter;

  List<FaultModel> faultsToReturn = [];

  Exception? exceptionToThrow;

  Completer<List<FaultModel>>? completer;

  @override
  Future<List<FaultModel>> getFaults({
    String? machineId,
    String? status,
    String? severity,
    String? reportedBy,
  }) async {
    getFaultsCallCount++;

    lastMachineIdFilter = machineId;
    lastStatusFilter = status;
    lastSeverityFilter = severity;

    if (completer != null) {
      return completer!.future;
    }

    if (exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return faultsToReturn;
  }
}

FaultModel createFault({
  String id = 'F-001',
  String machineId = 'M-01',
  String? machineName = 'CNC Machine',
  String type = AppConstants.faultTypeMechanical,
  String severity = AppConstants.severityHigh,
  String description = 'Grinding noise in spindle bearing during operation.',
  String reportedBy = 'user-123',
  String? reportedByName = 'Alex Operator',
  String status = AppConstants.faultStatusOpen,
  String? imageUrl,
  DateTime? createdAt,
}) {
  return FaultModel(
    id: id,
    machineId: machineId,
    machineName: machineName,
    type: type,
    severity: severity,
    description: description,
    reportedBy: reportedBy,
    reportedByName: reportedByName,
    status: status,
    imageUrl: imageUrl,
    createdAt: createdAt ?? DateTime(2026, 10, 23, 14, 30),
  );
}

Future<void> pumpFaultHistoryScreen(
  WidgetTester tester, {
  FaultService? faultService,
  UserService? userService,
  String? machineId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FaultHistoryScreen(
        faultService: faultService,
        userService: userService,
        machineId: machineId,
      ),
    ),
  );
}

void main() {
  group('FaultHistoryScreen', () {
    late FakeFaultService fakeFaultService;

    setUp(() {
      fakeFaultService = FakeFaultService();
    });

    testWidgets('displays AppBar titled Fault History', (tester) async {
      await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

      await tester.pumpAndSettle();

      expect(find.text('Fault History'), findsOneWidget);

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('displays loading state while fetching faults', (tester) async {
      fakeFaultService.completer = Completer<List<FaultModel>>();

      await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      expect(find.text('Loading fault history...'), findsOneWidget);

      expect(find.text('Retrieving reported machine faults.'), findsOneWidget);

      fakeFaultService.completer!.complete([createFault()]);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(find.text('Loading fault history...'), findsNothing);

      expect(find.text('CNC Machine'), findsOneWidget);
    });

    testWidgets('displays populated list of fault cards with all data', (
      tester,
    ) async {
      final sampleFault = createFault(
        id: 'F-101',
        machineId: 'M-01',
        machineName: 'CNC Milling Machine',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityHigh,
        description: 'Vibration observed at axis 3 during rapid traverse.',
        reportedBy: 'UID-456',
        reportedByName: 'Jane Doe',
        status: AppConstants.faultStatusOpen,
        imageUrl: 'https://example.com/photo.jpg',
        createdAt: DateTime(2026, 10, 23, 9, 15),
      );

      fakeFaultService.faultsToReturn = [sampleFault];

      await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

      await tester.pumpAndSettle();

      expect(find.text('CNC Milling Machine'), findsOneWidget);

      expect(find.text('Machine ID: M-01'), findsOneWidget);

      expect(find.text(AppConstants.faultTypeMechanical), findsOneWidget);

      expect(find.text(AppConstants.severityHigh), findsOneWidget);

      expect(
        find.text('Vibration observed at axis 3 during rapid traverse.'),
        findsOneWidget,
      );

      expect(find.text(AppConstants.faultStatusOpen), findsOneWidget);

      expect(find.text('By Jane Doe'), findsOneWidget);

      expect(find.text('23/10/2026 • 09:15'), findsOneWidget);

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('displays empty state when no faults exist', (tester) async {
      fakeFaultService.faultsToReturn = [];

      await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

      await tester.pumpAndSettle();

      expect(find.text('No faults found'), findsOneWidget);

      expect(
        find.text('No fault reports have been recorded yet.'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.assignment_turned_in_outlined), findsOneWidget);
    });

    testWidgets('displays error state and retries successfully', (
      tester,
    ) async {
      fakeFaultService.exceptionToThrow = FaultServiceException(
        code: 'unavailable',
        message: 'Firestore is currently unavailable. Please check your network connection.',
      );

      await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

      await tester.pumpAndSettle();

      expect(find.text('Unable to load fault history'), findsOneWidget);

      expect(
        find.text(
          'Firestore is currently unavailable. Please check your network connection.',
        ),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

      fakeFaultService.exceptionToThrow = null;

      fakeFaultService.faultsToReturn = [
        createFault(machineName: 'Recovered CNC'),
      ];

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));

      await tester.pumpAndSettle();

      expect(fakeFaultService.getFaultsCallCount, 2);

      expect(find.text('Recovered CNC'), findsOneWidget);

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets(
      'displays fallback error message for non-FaultServiceException',
      (tester) async {
        fakeFaultService.exceptionToThrow = Exception('Network socket closed');

        await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

        await tester.pumpAndSettle();

        expect(find.text('Unable to load fault history'), findsOneWidget);

        expect(find.text('Unable to retrieve fault history.'), findsOneWidget);

        expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets('supports pull-to-refresh on populated list', (tester) async {
      fakeFaultService.faultsToReturn = [createFault(id: 'F-1')];

      await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

      await tester.pumpAndSettle();

      expect(fakeFaultService.getFaultsCallCount, 1);

      expect(find.byType(Card), findsOneWidget);

      fakeFaultService.faultsToReturn = [
        createFault(id: 'F-1'),
        createFault(id: 'F-2', machineName: 'Drill Press'),
      ];

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);

      await tester.pump();

      await tester.pump(const Duration(seconds: 1));

      await tester.pumpAndSettle();

      expect(fakeFaultService.getFaultsCallCount, 2);

      expect(find.text('Drill Press'), findsOneWidget);
    });

    testWidgets('handles missing optional values safely without crashing', (
      tester,
    ) async {
      final minimalFault = FaultModel(
        id: 'F-MIN',
        machineId: 'M-99',
        machineName: null,
        type: '',
        severity: '',
        description: '',
        reportedBy: 'UID-99',
        reportedByName: null,
        status: '',
        imageUrl: null,
        createdAt: null,
      );

      fakeFaultService.faultsToReturn = [minimalFault];

      await pumpFaultHistoryScreen(tester, faultService: fakeFaultService);

      await tester.pumpAndSettle();

      expect(find.text('M-99'), findsOneWidget);

      expect(find.text('Other'), findsOneWidget);

      expect(find.text('Unknown'), findsOneWidget);

      expect(find.text('Open'), findsOneWidget);

      expect(find.text('No description provided'), findsOneWidget);

      expect(find.text('Date unavailable'), findsOneWidget);

      // Raw UID must NEVER be displayed; unresolved profiles display 'Unknown Reporter'
      expect(find.text('By Unknown Reporter'), findsOneWidget);
      expect(find.textContaining('UID-99'), findsNothing);

      expect(find.byIcon(Icons.image_outlined), findsNothing);
    });

    testWidgets('passes machineId filter to FaultService when provided', (
      tester,
    ) async {
      fakeFaultService.faultsToReturn = [createFault(machineId: 'M-TARGET')];

      await pumpFaultHistoryScreen(
        tester,
        faultService: fakeFaultService,
        machineId: 'M-TARGET',
      );

      await tester.pumpAndSettle();

      expect(fakeFaultService.lastMachineIdFilter, 'M-TARGET');

      expect(fakeFaultService.getFaultsCallCount, 1);
    });

    group('Reporter Name Resolution & Safety Tests', () {
      late FakeUserService fakeUserService;

      setUp(() {
        fakeUserService = FakeUserService();
      });

      testWidgets(
        '2. Existing fault with reportedByName displays saved name',
        (tester) async {
          fakeFaultService.faultsToReturn = [
            createFault(
              id: 'F-NAME-1',
              reportedBy: 'user-xyz-uid',
              reportedByName: 'Jatin Kashyap',
            ),
          ];

          await pumpFaultHistoryScreen(
            tester,
            faultService: fakeFaultService,
            userService: fakeUserService,
          );
          await tester.pumpAndSettle();

          expect(find.text('By Jatin Kashyap'), findsOneWidget);
          expect(find.textContaining('user-xyz-uid'), findsNothing);
          expect(fakeUserService.getUserProfileCallCount, equals(0));
        },
      );

      testWidgets(
        '3. Historical fault with null reportedByName resolves from users collection',
        (tester) async {
          const reporterUid = 'JO5v92NOnFQC1gvKPigwBfAnSut2';
          fakeUserService.users[reporterUid] = UserModel(
            id: reporterUid,
            name: 'Jatin Kashyap',
            email: 'jatin@machalert.com',
            role: 'operator',
          );

          fakeFaultService.faultsToReturn = [
            createFault(
              id: 'F-HIST-1',
              reportedBy: reporterUid,
              reportedByName: null,
            ),
          ];

          await pumpFaultHistoryScreen(
            tester,
            faultService: fakeFaultService,
            userService: fakeUserService,
          );
          await tester.pumpAndSettle();

          expect(find.text('By Jatin Kashyap'), findsOneWidget);
          expect(find.textContaining(reporterUid), findsNothing);
          expect(fakeUserService.getUserProfileCallCount, equals(1));
        },
      );

      testWidgets(
        '4. Missing user profile displays Unknown Reporter rather than raw UID',
        (tester) async {
          const missingUid = 'NON_EXISTENT_UID_99999';
          fakeFaultService.faultsToReturn = [
            createFault(
              id: 'F-HIST-2',
              reportedBy: missingUid,
              reportedByName: null,
            ),
          ];

          await pumpFaultHistoryScreen(
            tester,
            faultService: fakeFaultService,
            userService: fakeUserService,
          );
          await tester.pumpAndSettle();

          expect(find.text('By Unknown Reporter'), findsOneWidget);
          expect(find.textContaining(missingUid), findsNothing);
        },
      );

      testWidgets(
        '5. Missing displayName falls back to name field from users collection',
        (tester) async {
          const userUid = 'operator-user-77';
          // Simulate user profile with displayName empty/missing and name populated
          fakeUserService.users[userUid] = UserModel(
            id: userUid,
            name: 'Rahul Sharma',
            email: 'rahul@factory.com',
            role: 'operator',
          );

          fakeFaultService.faultsToReturn = [
            createFault(
              id: 'F-HIST-3',
              reportedBy: userUid,
              reportedByName: null,
            ),
          ];

          await pumpFaultHistoryScreen(
            tester,
            faultService: fakeFaultService,
            userService: fakeUserService,
          );
          await tester.pumpAndSettle();

          expect(find.text('By Rahul Sharma'), findsOneWidget);
          expect(find.textContaining(userUid), findsNothing);
        },
      );

      testWidgets(
        '6. Long reporter names do not overflow the card',
        (tester) async {
          // Set a compact mobile viewport (320x568 - iPhone SE size)
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          fakeFaultService.faultsToReturn = [
            createFault(
              id: 'F-LONG-1',
              reportedBy: 'uid-long-1',
              reportedByName:
                  'MachAlert Test Senior Operations Plant Quality and Safety Compliance Director John Alexander Doe III',
              createdAt: DateTime(2026, 11, 3, 14, 45),
            ),
          ];

          await pumpFaultHistoryScreen(
            tester,
            faultService: fakeFaultService,
            userService: fakeUserService,
          );
          await tester.pumpAndSettle();

          // Assert no flutter overflow error was thrown
          expect(tester.takeException(), isNull);
          // Verify name widget exists
          expect(find.textContaining('MachAlert Test Senior'), findsOneWidget);
        },
      );

      testWidgets(
        '7. Firebase UID is never displayed in Fault History',
        (tester) async {
          const rawUid = 'JO5v92NOnFQC1gvKPigwBfAnSut2';
          fakeFaultService.faultsToReturn = [
            createFault(
              id: 'F-UID-CHECK',
              reportedBy: rawUid,
              reportedByName: rawUid, // Even if legacy DB had UID in reportedByName
            ),
          ];

          fakeUserService.users[rawUid] = UserModel(
            id: rawUid,
            name: 'Jatin Kashyap',
            email: 'jatin@machalert.com',
            role: 'manager',
          );

          await pumpFaultHistoryScreen(
            tester,
            faultService: fakeFaultService,
            userService: fakeUserService,
          );
          await tester.pumpAndSettle();

          // Raw UID must NEVER be present anywhere in the card
          expect(find.textContaining(rawUid), findsNothing);
          expect(find.text('By Jatin Kashyap'), findsOneWidget);
        },
      );

      testWidgets(
        'Multiple cards with the same reporter reuse cached profile without duplicate lookups',
        (tester) async {
          const sharedUid = 'SHARED_TECH_UID_100';
          fakeUserService.users[sharedUid] = UserModel(
            id: sharedUid,
            name: 'Technician Alex',
            email: 'alex@factory.com',
            role: 'technician',
          );

          fakeFaultService.faultsToReturn = [
            createFault(id: 'F-1', reportedBy: sharedUid, reportedByName: null),
            createFault(id: 'F-2', reportedBy: sharedUid, reportedByName: null),
            createFault(id: 'F-3', reportedBy: sharedUid, reportedByName: null),
          ];

          await pumpFaultHistoryScreen(
            tester,
            faultService: fakeFaultService,
            userService: fakeUserService,
          );
          await tester.pumpAndSettle();

          expect(find.text('By Technician Alex'), findsNWidgets(3));
          // Exactly 1 lookup was made despite 3 cards needing resolution
          expect(fakeUserService.getUserProfileCallCount, equals(1));
        },
      );
    });
  });
}
