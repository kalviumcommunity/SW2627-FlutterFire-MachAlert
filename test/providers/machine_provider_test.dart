import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/providers/machine_provider.dart';
import 'package:mach_alert/services/machine_service.dart';
import 'package:mach_alert/utils/app_constants.dart';

MachineModel testMachine({
  required String id,
  required String name,
  required String line,
  required String status,
  double healthScore = 90.0,
}) {
  return MachineModel(
    id: id,
    name: name,
    productionLine: line,
    status: status,
    healthScore: healthScore,
  );
}

void main() {
  group('MachineProvider Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late MachineService machineService;
    late MachineProvider provider;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      machineService = MachineService(firestore: fakeFirestore);
      provider = MachineProvider(
        machineService: machineService,
        autoSubscribe: false,
      );
    });

    tearDown(() {
      if (!provider.isDisposed) {
        provider.dispose();
      }
    });

    test('has correct initial state', () {
      expect(provider.machines, isEmpty);
      expect(provider.filteredMachines, isEmpty);
      expect(provider.selectedMachine, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.hasError, isFalse);
      expect(provider.isEmpty, isTrue);
      expect(provider.selectedLine, isNull);
      expect(provider.selectedStatus, isNull);
      expect(provider.searchQuery, isEmpty);
      expect(provider.hasActiveSubscription, isFalse);
      expect(provider.isDisposed, isFalse);
    });

    test(
      'setMachines sets machine inventory directly and resets loading/error',
      () {
        final machines = [
          testMachine(
            id: 'M1',
            name: 'CNC Lathe',
            line: 'Line 1',
            status: 'Operational',
          ),
          testMachine(
            id: 'M2',
            name: 'Press 1',
            line: 'Line 2',
            status: 'Warning',
          ),
        ];

        int notifyCount = 0;
        provider.addListener(() => notifyCount++);

        provider.setMachines(machines);

        expect(provider.machines.length, 2);
        expect(provider.filteredMachines.length, 2);
        expect(provider.isEmpty, isFalse);
        expect(notifyCount, 1);
      },
    );

    test('selectMachine, selectMachineById, and clearSelectedMachine manage selected machine', () {
      final m1 = testMachine(
        id: 'M1',
        name: 'CNC Lathe',
        line: 'Line 1',
        status: 'Operational',
      );
      final m2 = testMachine(
        id: 'M2',
        name: 'Press 1',
        line: 'Line 2',
        status: 'Warning',
      );
      provider.setMachines([m1, m2]);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // Select by object
      provider.selectMachine(m1);
      expect(provider.selectedMachine, m1);
      expect(notifyCount, 1);

      // Select same object should NOT trigger redundant notification
      provider.selectMachine(m1);
      expect(notifyCount, 1);

      // Select by ID
      provider.selectMachineById('M2');
      expect(provider.selectedMachine, m2);
      expect(notifyCount, 2);

      // Select non-existent ID does nothing
      provider.selectMachineById('NON-EXISTENT');
      expect(provider.selectedMachine, m2);
      expect(notifyCount, 2);

      // Clear selection
      provider.clearSelectedMachine();
      expect(provider.selectedMachine, isNull);
      expect(notifyCount, 3);

      // Clearing again should NOT notify
      provider.clearSelectedMachine();
      expect(notifyCount, 3);
    });

    group('Filtering logic', () {
      setUp(() {
        provider.setMachines([
          testMachine(
            id: 'M1',
            name: 'CNC Milling 01',
            line: 'Line 1',
            status: 'Operational',
          ),
          testMachine(
            id: 'M2',
            name: 'CNC Lathe 02',
            line: 'Line 1',
            status: 'Warning',
          ),
          testMachine(
            id: 'M3',
            name: 'Hydraulic Press',
            line: 'Line 2',
            status: 'Critical',
          ),
          testMachine(
            id: 'M4',
            name: 'Assembly Conveyor',
            line: 'Line 3',
            status: 'Under Maintenance',
          ),
        ]);
      });

      test('filters by production line without mutating base inventory', () {
        provider.setProductionLineFilter('Line 1');

        expect(provider.selectedLine, 'Line 1');
        expect(provider.machines.length, 4); // Underlying full list preserved
        expect(provider.filteredMachines.length, 2);
        expect(
          provider.filteredMachines.every((m) => m.productionLine == 'Line 1'),
          isTrue,
        );
      });

      test('filters by operational status', () {
        provider.setStatusFilter('Critical');

        expect(provider.selectedStatus, 'Critical');
        expect(provider.filteredMachines.length, 1);
        expect(provider.filteredMachines.first.id, 'M3');
      });

      test(
        'filters by text search query across id, name, line, and status',
        () {
          provider.setSearchQuery('CNC');
          expect(provider.filteredMachines.length, 2);

          provider.setSearchQuery('Press');
          expect(provider.filteredMachines.length, 1);
          expect(provider.filteredMachines.first.id, 'M3');

          provider.setSearchQuery('M4');
          expect(provider.filteredMachines.length, 1);
          expect(provider.filteredMachines.first.name, 'Assembly Conveyor');
        },
      );

      test('combines line, status, and search filters accurately', () {
        provider.setProductionLineFilter('Line 1');
        provider.setStatusFilter('Warning');
        provider.setSearchQuery('Lathe');

        expect(provider.filteredMachines.length, 1);
        expect(provider.filteredMachines.first.id, 'M2');
      });

      test('clearFilters resets all filter dimensions', () {
        provider.setProductionLineFilter('Line 1');
        provider.setStatusFilter('Warning');
        provider.setSearchQuery('Lathe');
        expect(provider.filteredMachines.length, 1);

        provider.clearFilters();

        expect(provider.selectedLine, isNull);
        expect(provider.selectedStatus, isNull);
        expect(provider.searchQuery, isEmpty);
        expect(provider.filteredMachines.length, 4);
      });
    });

    group('fetchMachines one-shot query', () {
      test('successfully fetches machines from Firestore', () async {
        await fakeFirestore.collection('machines').doc('MCH-1').set({
          'id': 'MCH-1',
          'name': 'Robot Arm',
          'productionLine': 'Line 1',
          'status': 'Operational',
          'healthScore': 95.0,
        });

        await provider.fetchMachines();

        expect(provider.isLoading, isFalse);
        expect(provider.hasError, isFalse);
        expect(provider.machines.length, 1);
        expect(provider.machines.first.name, 'Robot Arm');
      });

      test('surfaces error when service fails during fetch', () async {
        // Calling with invalid status triggers MachineService validation exception
        await expectLater(
          provider.fetchMachines(status: 'invalid_status_value'),
          throwsA(isA<MachineServiceException>()),
        );

        expect(provider.isLoading, isFalse);
        expect(provider.hasError, isTrue);
        expect(provider.errorMessage, isNotNull);
      });
    });

    group('Real-time Stream Integration', () {
      test('subscribes to stream and receives updates in real time', () async {
        provider.subscribeToMachines();
        expect(provider.hasActiveSubscription, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(provider.machines, isEmpty);
        expect(provider.isEmpty, isTrue);

        // Add a machine to Firestore
        await machineService.addMachine(
          testMachine(
            id: 'STR-1',
            name: 'Laser Welder',
            line: 'Line 2',
            status: 'Operational',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 15));
        expect(provider.machines.length, 1);
        expect(provider.machines.first.id, 'STR-1');
        expect(provider.isEmpty, isFalse);
      });

      test(
        'reconciles selected machine when stream receives updated data',
        () async {
          await machineService.addMachine(
            testMachine(
              id: 'REC-1',
              name: 'Saw',
              line: 'Line 1',
              status: 'Operational',
            ),
          );

          provider.subscribeToMachines();
          await Future<void>.delayed(const Duration(milliseconds: 15));

          provider.selectMachineById('REC-1');
          expect(provider.selectedMachine!.status, 'Operational');

          // External update to the same machine
          await machineService.updateMachineStatus(
            'REC-1',
            AppConstants.machineStatusWarning,
          );

          await Future<void>.delayed(const Duration(milliseconds: 15));
          expect(
            provider.selectedMachine!.status,
            AppConstants.machineStatusWarning,
          );
        },
      );

      test(
        'avoids duplicate subscriptions when called with same parameters',
        () {
          provider.subscribeToMachines(productionLine: 'Line 1');

          int notifyCount = 0;
          provider.addListener(() => notifyCount++);

          // Same parameters should be a no-op
          provider.subscribeToMachines(productionLine: 'Line 1');
          expect(notifyCount, 0);
        },
      );

      test(
        'handles stream errors gracefully via subscribeToMachineStream',
        () async {
          final streamController = StreamController<List<MachineModel>>();
          provider.subscribeToMachineStream(streamController.stream);

          expect(provider.isLoading, isTrue);

          // Emit an error
          streamController.addError(
            MachineServiceException(
              code: 'permission-denied',
              message: 'Stream denied',
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 10));

          expect(provider.isLoading, isFalse);
          expect(provider.hasError, isTrue);
          expect(provider.errorMessage, 'Stream denied');

          await streamController.close();
        },
      );
    });

    group('updateMachineStatus operation', () {
      setUp(() async {
        await fakeFirestore.collection('machines').doc('UPD-01').set({
          'id': 'UPD-01',
          'name': 'Furnace',
          'productionLine': 'Line 3',
          'status': 'Operational',
          'healthScore': 99.0,
        });
        await provider.fetchMachines();
        provider.selectMachineById('UPD-01');
      });

      test(
        'successfully updates machine status and reconciles local state',
        () async {
          expect(provider.selectedMachine!.status, 'Operational');

          await provider.updateMachineStatus(
            'UPD-01',
            AppConstants.machineStatusUnderMaintenance,
          );

          expect(
            provider.selectedMachine!.status,
            AppConstants.machineStatusUnderMaintenance,
          );
          expect(
            provider.machines.first.status,
            AppConstants.machineStatusUnderMaintenance,
          );

          // Verify in Firestore
          final doc = await fakeFirestore
              .collection('machines')
              .doc('UPD-01')
              .get();
          expect(
            doc.data()!['status'],
            AppConstants.machineStatusUnderMaintenance,
          );
        },
      );

      test(
        'handles failure and preserves error message on invalid status update',
        () async {
          await expectLater(
            provider.updateMachineStatus('UPD-01', 'bad_status'),
            throwsA(isA<MachineServiceException>()),
          );

          expect(provider.hasError, isTrue);
          expect(provider.errorMessage, contains('invalid'));
        },
      );
    });

    test('clearError clears error message and notifies listeners', () async {
      final streamController = StreamController<List<MachineModel>>();
      provider.subscribeToMachineStream(streamController.stream);
      streamController.addError(
        MachineServiceException(code: 'unknown', message: 'An error'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.errorMessage, isNotNull);

      provider.clearError();
      expect(provider.errorMessage, isNull);
      expect(provider.hasError, isFalse);

      await streamController.close();
    });

    test('addMachine persists machine and updates local list', () async {
      final newMachine = testMachine(
        id: 'ADD-01',
        name: 'New Stamping Press',
        line: 'Line 3',
        status: 'Operational',
      );

      await provider.addMachine(newMachine);

      expect(provider.machines.length, 1);
      expect(provider.machines.first.id, 'ADD-01');

      final doc = await fakeFirestore
          .collection('machines')
          .doc('ADD-01')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['name'], 'New Stamping Press');
    });

    test(
      'updateMachine updates mutable fields and reconciles selectedMachine',
      () async {
        final m1 = testMachine(
          id: 'EDIT-01',
          name: 'Original Lathe',
          line: 'Line 1',
          status: 'Operational',
        );
        await provider.addMachine(m1);
        provider.selectMachine(m1);

        final updated = m1.copyWith(
          name: 'Refurbished Lathe',
          status: 'Warning',
          healthScore: 75.0,
        );

        await provider.updateMachine(updated);

        expect(provider.machines.first.name, 'Refurbished Lathe');
        expect(provider.machines.first.status, 'Warning');
        expect(provider.selectedMachine?.name, 'Refurbished Lathe');

        final doc = await fakeFirestore
            .collection('machines')
            .doc('EDIT-01')
            .get();
        expect(doc.data()!['name'], 'Refurbished Lathe');
      },
    );

    test('deleteMachine removes machine from Firestore and reconciles selectedMachine', () async {
      final m1 = testMachine(
        id: 'DEL-01',
        name: 'Scrap Machine',
        line: 'Line 1',
        status: 'Critical',
      );
      await provider.addMachine(m1);
      provider.selectMachine(m1);

      expect(provider.machines.length, 1);
      expect(provider.selectedMachine, isNotNull);

      await provider.deleteMachine('DEL-01');

      expect(provider.machines, isEmpty);
      expect(provider.selectedMachine, isNull);

      final doc = await fakeFirestore
          .collection('machines')
          .doc('DEL-01')
          .get();
      expect(doc.exists, isFalse);
    });

    test('getMachineById finds machine in memory or returns null', () {
      final m1 = testMachine(
        id: 'FIND-01',
        name: 'M1',
        line: 'L1',
        status: 'Operational',
      );
      provider.setMachines([m1]);

      expect(provider.getMachineById('FIND-01')?.name, 'M1');
      expect(provider.getMachineById('NON-EXISTENT'), isNull);
    });

    test(
      'dispose cancels active subscriptions and silences future notifications',
      () async {
        provider.subscribeToMachines();
        expect(provider.hasActiveSubscription, isTrue);

        provider.dispose();
        expect(provider.isDisposed, isTrue);
        expect(provider.hasActiveSubscription, isFalse);

        // Subsequent notifications should not throw
        provider.notifyListeners();
      },
    );
  });
}
