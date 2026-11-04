import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/machine_statistics.dart';
import 'package:mach_alert/utils/app_constants.dart';

void main() {
  MachineModel createMachine(String id, String status) {
    return MachineModel(
      id: id,
      name: 'Machine $id',
      productionLine: 'Line A',
      status: status,
      healthScore: 85.0,
    );
  }

  group('MachineStatistics Model & Reconciliation Tests', () {
    test('Empty machine list returns zeroed statistics and 0.0 ratios', () {
      final stats = MachineStatistics.fromMachines([]);

      expect(stats.total, equals(0));
      expect(stats.running, equals(0));
      expect(stats.maintenance, equals(0));
      expect(stats.breakdown, equals(0));
      expect(stats.other, equals(0));
      expect(stats.unknown, equals(0));
      expect(stats.warning, equals(0));

      expect(stats.runningRatio, equals(0.0));
      expect(stats.maintenanceRatio, equals(0.0));
      expect(stats.breakdownRatio, equals(0.0));
      expect(stats.otherRatio, equals(0.0));
      expect(stats.warningRatio, equals(0.0));
      expect(stats.unknownRatio, equals(0.0));

      expect(stats.runningPercentage, equals(0));
      expect(stats.maintenancePercentage, equals(0));
      expect(stats.breakdownPercentage, equals(0));
      expect(stats.otherPercentage, equals(0));
      expect(stats.unknownPercentage, equals(0));

      // Invariant: 0 + 0 + 0 + 0 == 0
      expect(
        stats.running + stats.maintenance + stats.breakdown + stats.other,
        equals(stats.total),
      );
    });

    group('Status Mapping Tests for Every Mapping Rule', () {
      test('Mapping 1: Operational / Running -> Running', () {
        final operationalVariants = [
          'Operational',
          'operational',
          'OPERATIONAL',
          ' Running ',
          'running',
          'RUNNING',
        ];

        for (final status in operationalVariants) {
          final stats = MachineStatistics.fromMachines([
            createMachine('test-running', status),
          ]);

          expect(
            stats.running,
            equals(1),
            reason: 'Status "$status" must map to Running',
          );
          expect(stats.maintenance, equals(0));
          expect(stats.breakdown, equals(0));
          expect(stats.other, equals(0));
          expect(stats.total, equals(1));
          expect(
            stats.running + stats.maintenance + stats.breakdown + stats.other,
            equals(stats.total),
          );
        }
      });

      test('Mapping 2: Under Maintenance / In Maintenance -> In Maintenance', () {
        final maintenanceVariants = [
          'Under Maintenance',
          'under maintenance',
          'UNDER MAINTENANCE',
          'In Maintenance',
          'in maintenance',
          'IN MAINTENANCE',
          'Maintenance',
          'maintenance',
          ' MAINTENANCE ',
        ];

        for (final status in maintenanceVariants) {
          final stats = MachineStatistics.fromMachines([
            createMachine('test-maintenance', status),
          ]);

          expect(stats.running, equals(0));
          expect(
            stats.maintenance,
            equals(1),
            reason: 'Status "$status" must map to In Maintenance',
          );
          expect(stats.breakdown, equals(0));
          expect(stats.other, equals(0));
          expect(stats.total, equals(1));
          expect(
            stats.running + stats.maintenance + stats.breakdown + stats.other,
            equals(stats.total),
          );
        }
      });

      test('Mapping 3: Critical / Breakdown / Broken -> Breakdown', () {
        final breakdownVariants = [
          'Critical',
          'critical',
          'CRITICAL',
          'Breakdown',
          'breakdown',
          'BREAKDOWN',
          'Broken',
          'broken',
          ' BROKEN ',
        ];

        for (final status in breakdownVariants) {
          final stats = MachineStatistics.fromMachines([
            createMachine('test-breakdown', status),
          ]);

          expect(stats.running, equals(0));
          expect(stats.maintenance, equals(0));
          expect(
            stats.breakdown,
            equals(1),
            reason: 'Status "$status" must map to Breakdown',
          );
          expect(stats.other, equals(0));
          expect(stats.total, equals(1));
          expect(
            stats.running + stats.maintenance + stats.breakdown + stats.other,
            equals(stats.total),
          );
        }
      });

      test('Mapping 4: Warning -> Other / Warning (NOT active maintenance)', () {
        final warningVariants = [
          'Warning',
          'warning',
          'WARNING',
          'Warn',
          'warn',
          ' WARN ',
        ];

        for (final status in warningVariants) {
          final stats = MachineStatistics.fromMachines([
            createMachine('test-warning', status),
          ]);

          expect(stats.running, equals(0));
          // Explicit requirement: Warning must NOT be counted as active maintenance
          expect(
            stats.maintenance,
            equals(0),
            reason: 'Status "$status" must NOT be mapped to Maintenance',
          );
          expect(stats.breakdown, equals(0));
          expect(
            stats.other,
            equals(1),
            reason: 'Status "$status" must map to Other / Warning',
          );
          expect(stats.warning, equals(1));
          expect(stats.total, equals(1));
          expect(
            stats.running + stats.maintenance + stats.breakdown + stats.other,
            equals(stats.total),
          );
        }
      });

      test('Mapping 5: Unknown statuses -> Other / Unknown', () {
        final unknownVariants = [
          'Unknown',
          'unknown',
          'UNKNOWN',
          'Decommissioned',
          'Standby',
          'Idle',
          'Offline',
          'Retired',
          '###INVALID_STATUS###',
          '',
          '   ',
        ];

        for (final status in unknownVariants) {
          final stats = MachineStatistics.fromMachines([
            createMachine('test-unknown', status),
          ]);

          expect(stats.running, equals(0));
          expect(
            stats.maintenance,
            equals(0),
            reason: 'Unknown status "$status" must NOT be mapped to Maintenance',
          );
          expect(stats.breakdown, equals(0));
          expect(
            stats.other,
            equals(1),
            reason: 'Unknown status "$status" must map to Other / Unknown',
          );
          expect(stats.unknown, equals(1));
          expect(stats.total, equals(1));
          expect(
            stats.running + stats.maintenance + stats.breakdown + stats.other,
            equals(stats.total),
          );
        }
      });
    });

    test('Canonical statuses are categorized correctly and reconcile 100%', () {
      final machines = [
        MachineModel(
          id: 'm1',
          name: 'Running 1',
          productionLine: 'Line A',
          status: AppConstants.machineStatusOperational,
          healthScore: 90,
        ),
        MachineModel(
          id: 'm2',
          name: 'Running 2',
          productionLine: 'Line A',
          status: 'running',
          healthScore: 95,
        ),
        MachineModel(
          id: 'm3',
          name: 'Under Maintenance',
          productionLine: 'Line B',
          status: AppConstants.machineStatusUnderMaintenance,
          healthScore: 60,
        ),
        MachineModel(
          id: 'm4',
          name: 'Warning',
          productionLine: 'Line B',
          status: AppConstants.machineStatusWarning,
          healthScore: 70,
        ),
        MachineModel(
          id: 'm5',
          name: 'Breakdown Critical',
          productionLine: 'Line C',
          status: AppConstants.machineStatusCritical,
          healthScore: 25,
        ),
      ];

      final stats = MachineStatistics.fromMachines(machines);

      expect(stats.total, equals(5));
      expect(stats.running, equals(2)); // m1, m2
      expect(stats.maintenance, equals(1)); // m3
      expect(stats.breakdown, equals(1)); // m5
      expect(stats.other, equals(1)); // m4 (Warning mapped to Other / Warning)
      expect(stats.warning, equals(1));

      // Guarantees reconciliation invariant: Running + In Maintenance + Breakdown + Other == Total Machines
      expect(
        stats.running + stats.maintenance + stats.breakdown + stats.other,
        equals(stats.total),
      );
    });

    test('Mixed dataset with valid and invalid statuses reconciles 100%', () {
      final machines = [
        createMachine('m-running', 'Operational'),
        createMachine('m-maintenance', 'Under Maintenance'),
        createMachine('m-breakdown', 'Critical'),
        createMachine('m-warning', 'Warning'),
        createMachine('m-unknown-1', 'Decommissioned'),
        createMachine('m-unknown-2', 'Unknown'),
        createMachine('m-invalid', '###INVALID_STATUS###'),
        createMachine('m-empty', ''),
      ];

      final stats = MachineStatistics.fromMachines(machines);

      expect(stats.total, equals(8));
      expect(stats.running, equals(1));
      expect(stats.maintenance, equals(1));
      expect(stats.breakdown, equals(1));
      // Other contains: Warning (1) + Decommissioned (1) + Unknown (1) + Invalid (1) + Empty (1) = 5
      expect(stats.other, equals(5));
      expect(stats.unknown, equals(5));

      // Guarantees reconciliation invariant: Running + In Maintenance + Breakdown + Other == Total Machines
      expect(
        stats.running + stats.maintenance + stats.breakdown + stats.other,
        equals(stats.total),
      );

      // Verify ratios & percentages
      expect(stats.runningRatio, closeTo(1 / 8, 0.001));
      expect(stats.maintenanceRatio, closeTo(1 / 8, 0.001));
      expect(stats.breakdownRatio, closeTo(1 / 8, 0.001));
      expect(stats.otherRatio, closeTo(5 / 8, 0.001));

      expect(stats.runningPercentage, equals(13)); // 1/8 = 12.5% -> round 13
      expect(stats.maintenancePercentage, equals(13));
      expect(stats.breakdownPercentage, equals(13));
      expect(stats.otherPercentage, equals(63)); // 5/8 = 62.5% -> round 63
    });

    test('Equality and toString work correctly', () {
      const stats1 = MachineStatistics(
        total: 10,
        running: 5,
        maintenance: 2,
        breakdown: 2,
        other: 1,
      );

      const stats2 = MachineStatistics(
        total: 10,
        running: 5,
        maintenance: 2,
        breakdown: 2,
        other: 1,
      );

      const stats3 = MachineStatistics(
        total: 10,
        running: 4,
        maintenance: 3,
        breakdown: 2,
        other: 1,
      );

      expect(stats1, equals(stats2));
      expect(stats1.hashCode, equals(stats2.hashCode));
      expect(stats1, isNot(equals(stats3)));
      expect(
        stats1.toString(),
        equals('MachineStatistics(total: 10, running: 5, maintenance: 2, breakdown: 2, other: 1)'),
      );
    });
  });
}
