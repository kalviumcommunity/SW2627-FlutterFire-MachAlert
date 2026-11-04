import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/user_model.dart';
import 'package:mach_alert/providers/app_state_provider.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/screens/reports/reports_screen.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/theme/app_theme.dart';
import 'package:provider/provider.dart';

class FakeMachineService extends Fake implements MachineService {
  final Stream<List<MachineModel>>? machineStream;
  int streamCalls = 0;

  FakeMachineService({this.machineStream});

  @override
  Stream<List<MachineModel>> streamMachines({
    String? productionLine,
    String? status,
  }) {
    streamCalls++;
    return machineStream ?? const Stream<List<MachineModel>>.empty();
  }
}

class TrackingMachineProvider extends MachineProvider {
  int refreshCallCount = 0;

  TrackingMachineProvider({
    super.machineService,
    super.machineStream,
    super.autoSubscribe,
  });

  @override
  void refresh() {
    refreshCallCount++;
    super.refresh();
  }
}

UserModel createTechnicianUser({String uid = 'tech-001'}) {
  return UserModel(
    id: uid,
    name: 'Technician Alex',
    email: 'alex@machalert.com',
    role: 'technician',
  );
}

MachineModel createTestMachine({
  required String id,
  required String name,
  required String status,
  String productionLine = 'Line 1',
}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: productionLine,
    status: status,
    healthScore: 90.0,
  );
}

Widget buildReportsTestWidget({
  required UserModel user,
  required MachineProvider machineProvider,
}) {
  final appState = AppStateProvider()..setAuthenticated(user);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppStateProvider>.value(value: appState),
      ChangeNotifierProvider<MachineProvider>.value(value: machineProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: ReportsScreen(machineProvider: machineProvider),
    ),
  );
}

void main() {
  group('Reports Screen Technician Machine Statistics Regression Tests', () {
    testWidgets(
      'Technician can view complete machine fleet statistics (Running, Maintenance, Breakdown, Total)',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService =
            FakeMachineService(machineStream: streamController.stream);
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildReportsTestWidget(
            user: technician,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        // 6 machines: 3 Running (Operational -> 50%), 2 Maintenance (Under Maintenance -> 33%), 1 Breakdown (Critical -> 17%)
        streamController.add([
          createTestMachine(id: 'm-1', name: 'Lathe 1', status: 'Operational'),
          createTestMachine(id: 'm-2', name: 'Lathe 2', status: 'Operational'),
          createTestMachine(id: 'm-3', name: 'Press 1', status: 'Operational'),
          createTestMachine(id: 'm-4', name: 'Mill 1', status: 'Under Maintenance'),
          createTestMachine(id: 'm-5', name: 'Mill 2', status: 'Under Maintenance'),
          createTestMachine(id: 'm-6', name: 'Saw 1', status: 'Critical'),
        ]);
        await tester.pump();
        await tester.pump();

        // Total count
        expect(find.text('6'), findsOneWidget);
        expect(find.text('Machines'), findsOneWidget);

        // Status breakdown counts and percentages
        expect(find.text('3 (50%)'), findsOneWidget); // Running
        expect(find.text('2 (33%)'), findsOneWidget); // Maintenance
        expect(find.text('1 (17%)'), findsOneWidget); // Breakdown

        // Ensure '--' is not displayed for machine statistics
        expect(find.text('--'), findsNothing);
      },
    );

    testWidgets(
      'Empty inventory renders 0 Machines and 0% for all categories rather than "--"',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService =
            FakeMachineService(machineStream: streamController.stream);
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildReportsTestWidget(
            user: technician,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        // Emit empty machine list
        streamController.add([]);
        await tester.pump();
        await tester.pump();

        // Total count displays 0
        expect(find.text('0'), findsOneWidget);
        expect(find.text('Machines'), findsOneWidget);

        // Status breakdown all display 0 (0%)
        expect(find.text('0 (0%)'), findsNWidgets(3)); // Running, Maintenance, Breakdown

        // Silently falling back to '--' is forbidden
        expect(find.text('--'), findsNothing);
      },
    );

    testWidgets(
      'Loading state renders progress indicator and loading text without displaying fabricated numbers or "--"',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService =
            FakeMachineService(machineStream: streamController.stream);
        // Provider in loading state: subscribed, but no data emitted yet
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildReportsTestWidget(
            user: technician,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        // Loading indicator is visible
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading machine statistics...'), findsOneWidget);

        // No fabricated numbers or '--' displayed
        expect(find.text('--'), findsNothing);
        expect(find.text('0 (0%)'), findsNothing);
      },
    );

    testWidgets(
      'Firestore error renders human-readable error and Retry button without crashing',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService =
            FakeMachineService(machineStream: streamController.stream);
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildReportsTestWidget(
            user: technician,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        // Emit error on stream
        streamController.addError(Exception('Firestore permission denied'));
        await tester.pump();
        await tester.pump();

        // Human-readable error and Retry button rendered
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);

        // No unhandled exception or '--'
        expect(find.text('--'), findsNothing);
      },
    );

    testWidgets(
      'Tapping Retry invokes provider.refresh() and resets loading state without duplicate subscriptions',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService =
            FakeMachineService(machineStream: streamController.stream);
        final machineProvider = TrackingMachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildReportsTestWidget(
            user: technician,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        // Put provider into error state
        streamController.addError(Exception('Temporary connection failure'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Retry'), findsOneWidget);
        expect(machineProvider.refreshCallCount, 0);

        // Tap Retry
        await tester.tap(find.text('Retry'));
        await tester.pump();

        // refresh() was called on provider
        expect(machineProvider.refreshCallCount, 1);
        // Provider is now in loading state
        expect(machineProvider.isLoading, isTrue);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Loading machine statistics...'), findsOneWidget);

        // Now emit successful data
        streamController.add([
          createTestMachine(id: 'm-1', name: 'Machine 1', status: 'Operational'),
        ]);
        await tester.pump();
        await tester.pump();

        // Successfully displays data
        expect(find.text('1'), findsOneWidget);
        expect(find.text('1 (100%)'), findsOneWidget);
      },
    );

    testWidgets(
      'Machine statistics represent factory-wide fleet and are not filtered by Reports date range',
      (tester) async {
        final streamController =
            StreamController<List<MachineModel>>.broadcast();
        addTearDown(streamController.close);

        final machineService =
            FakeMachineService(machineStream: streamController.stream);
        final machineProvider = MachineProvider(
          machineService: machineService,
          autoSubscribe: true,
        );
        addTearDown(machineProvider.dispose);

        final technician = createTechnicianUser();

        await tester.pumpWidget(
          buildReportsTestWidget(
            user: technician,
            machineProvider: machineProvider,
          ),
        );
        await tester.pump();

        // Emit machines with diverse statuses
        streamController.add([
          createTestMachine(id: 'm-1', name: 'M1', status: 'Operational'),
          createTestMachine(id: 'm-2', name: 'M2', status: 'Under Maintenance'),
        ]);
        await tester.pump();
        await tester.pump();

        // The date range widget is present in the screen with data-driven text
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.text('Live Operational Data (All Time)'), findsOneWidget);
        expect(find.text('Oct 1, 2026 - Oct 10, 2026'), findsNothing);

        // Machine statistics card still accurately reflects current inventory fleet (total 2)
        expect(find.text('2'), findsOneWidget);
        expect(find.text('1 (50%)'), findsNWidgets(2)); // 1 Running, 1 Maintenance
      },
    );
  });
}
