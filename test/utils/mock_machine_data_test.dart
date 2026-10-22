import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:mach_alert/utils/mock_machine_data.dart';
import 'package:mach_alert/utils/mock_machine_seeder.dart';

void main() {
  group('MockMachineData Fixture Tests', () {
    test('fixture contains exactly 5 mock machines', () {
      final machines = MockMachineData.sampleMachines;
      expect(machines.length, 5);
    });

    test('machine identifiers are unique and non-empty', () {
      final machines = MockMachineData.sampleMachines;
      final ids = machines.map((m) => m.id).toList();

      expect(ids.toSet().length, machines.length,
          reason: 'All machine IDs must be strictly unique.');

      for (final id in ids) {
        expect(id.trim(), isNotEmpty);
        expect(id, startsWith('mock-'));
      }
    });

    test('every machine has valid required fields and recognized status', () {
      final machines = MockMachineData.sampleMachines;

      for (final machine in machines) {
        expect(machine.id.trim(), isNotEmpty);
        expect(machine.name.trim(), isNotEmpty);
        expect(machine.productionLine.trim(), isNotEmpty);
        expect(machine.status.trim(), isNotEmpty);

        expect(
          machine.hasRecognizedStatus,
          isTrue,
          reason: 'Machine "${machine.name}" has invalid status: "${machine.status}"',
        );

        expect(
          AppConstants.machineStatuses,
          contains(machine.status),
        );

        expect(
          machine.healthScore,
          greaterThanOrEqualTo(0.0),
        );
        expect(
          machine.healthScore,
          lessThanOrEqualTo(100.0),
        );

        if (machine.temperature != null) {
          expect(machine.temperature!, greaterThan(0.0));
        }
        if (machine.vibration != null) {
          expect(machine.vibration!, greaterThanOrEqualTo(0.0));
        }
      }
    });

    test('covers required realistic machine types, lines, and statuses', () {
      final machines = MockMachineData.sampleMachines;

      final names = machines.map((m) => m.name).toList();
      expect(names, contains('CNC Milling Machine 01'));
      expect(names, contains('Hydraulic Press 02'));
      expect(names, contains('Conveyor Belt 03'));
      expect(names, contains('Injection Molding Machine 04'));
      expect(names, contains('Industrial Compressor 05'));

      final lines = machines.map((m) => m.productionLine).toSet();
      expect(lines, containsAll(['Line A', 'Line B', 'Line C']));

      final statuses = machines.map((m) => m.status).toSet();
      expect(statuses, contains(AppConstants.machineStatusOperational));
      expect(statuses, contains(AppConstants.machineStatusWarning));
      expect(statuses, contains(AppConstants.machineStatusUnderMaintenance));
      expect(statuses, contains(AppConstants.machineStatusCritical));
    });
  });

  group('MockMachineSeeder - Firestore Seeding Tests', () {
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
    });

    test('seeds 5 machines into Firestore on initial execution', () async {
      final count = await MockMachineSeeder.seedFirestore(
        fakeFirestore,
        isDevelopmentOnly: true,
      );

      expect(count, 5);

      final snapshot = await fakeFirestore
          .collection(AppConstants.machinesCollection)
          .get();

      expect(snapshot.docs.length, 5);

      final seededIds = snapshot.docs.map((d) => d.id).toSet();
      expect(seededIds, {
        'mock-cnc-01',
        'mock-press-02',
        'mock-conveyor-03',
        'mock-molding-04',
        'mock-compressor-05',
      });
    });

    test('is idempotent: running seed again without overwrite skips duplicates', () async {
      final firstRunCount = await MockMachineSeeder.seedFirestore(
        fakeFirestore,
        isDevelopmentOnly: true,
      );
      expect(firstRunCount, 5);

      final secondRunCount = await MockMachineSeeder.seedFirestore(
        fakeFirestore,
        overwrite: false,
        isDevelopmentOnly: true,
      );
      expect(secondRunCount, 0);

      final snapshot = await fakeFirestore
          .collection(AppConstants.machinesCollection)
          .get();
      expect(snapshot.docs.length, 5);
    });

    test('overwrites existing documents when overwrite is true', () async {
      await MockMachineSeeder.seedFirestore(
        fakeFirestore,
        isDevelopmentOnly: true,
      );

      final count = await MockMachineSeeder.seedFirestore(
        fakeFirestore,
        overwrite: true,
        isDevelopmentOnly: true,
      );

      expect(count, 5);
    });

    test('rejects seeding if isDevelopmentOnly is false', () async {
      expect(
        () => MockMachineSeeder.seedFirestore(
          fakeFirestore,
          isDevelopmentOnly: false,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('strictly prohibited in production'),
          ),
        ),
      );
    });
  });

  group('MockMachineSeeder - Emulator Safety and REST Seeding Tests', () {
    test('seedEmulator refuses non-local host for safety', () async {
      expect(
        () => MockMachineSeeder.seedEmulator(host: 'firestore.googleapis.com'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('strictly restricted to local hosts'),
          ),
        ),
      );
    });

    test('seedEmulator runs safely against local emulator when reachable', () async {
      final isRunning = await MockMachineSeeder.isEmulatorRunning();
      if (!isRunning) {
        return; // Emulator not running, tested via socket mock / unit tests
      }

      final count = await MockMachineSeeder.seedEmulator(
        overwrite: true,
      );
      expect(count, 5);

      final secondCount = await MockMachineSeeder.seedEmulator(
        overwrite: false,
      );
      expect(secondCount, 0);
    });
  });
}
