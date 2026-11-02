import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/machine_model.dart';
import 'package:mach_alert/models/machine_statistics.dart';
import 'package:mach_alert/utils/app_constants.dart';

void main() {
  group('MachineStatistics Model & Reconciliation Tests', () {
    test('Empty machine list returns zeroed statistics and 0.0 ratios', () {
      final stats = MachineStatistics.fromMachines([]);

      expect(stats.total, equals(0));
      expect(stats.running, equals(0));
      expect(stats.maintenance, equals(0));
      expect(stats.breakdown, equals(0));
      expect(stats.other, equals(0));
      expect(stats.unknown, equals(0));

      expect(stats.runningRatio, equals(0.0));
      expect(stats.maintenanceRatio, equals(0.0));
      expect(stats.breakdownRatio, equals(0.0));
      expect(stats.otherRatio, equals(0.0));

      expect(stats.runningPercentage, equals(0));
      expect(stats.maintenancePercentage, equals(0));
      expect(stats.breakdownPercentage, equals(0));
      expect(stats.otherPercentage, equals(0));
    });

    test('Canonical statuses are categorized correctly into Running, Maintenance, and Breakdown', () {
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
          status: 'operational', // lowercase normalized
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
      expect(stats.running, equals(2));
      expect(stats.maintenance, equals(2));
      expect(stats.breakdown, equals(1));
      expect(stats.other, equals(0));

      // Reconciles exactly: 2 + 2 + 1 + 0 = 5
      expect(
        stats.running + stats.maintenance + stats.breakdown + stats.other,
        equals(stats.total),
      );
    });

    test('Unrecognized, invalid, or empty statuses are classified as Other/Unknown and NOT Maintenance', () {
      final machines = [
        MachineModel(
          id: 'm-running',
          name: 'Normal Machine',
          productionLine: 'Line A',
          status: 'Operational',
          healthScore: 90,
        ),
        MachineModel(
          id: 'm-unknown-1',
          name: 'Decommissioned Machine',
          productionLine: 'Line A',
          status: 'Decommissioned',
          healthScore: 0,
        ),
        MachineModel(
          id: 'm-unknown-2',
          name: 'Unknown Status Machine',
          productionLine: 'Line B',
          status: 'Unknown',
          healthScore: 50,
        ),
        MachineModel(
          id: 'm-invalid',
          name: 'Corrupt Status Machine',
          productionLine: 'Line B',
          status: '###INVALID_STATUS###',
          healthScore: 40,
        ),
        MachineModel(
          id: 'm-empty',
          name: 'Empty Status Machine',
          productionLine: 'Line C',
          status: '',
          healthScore: 50,
        ),
      ];

      final stats = MachineStatistics.fromMachines(machines);

      // Verify Running = 1
      expect(stats.running, equals(1));

      // CRITICAL: Maintenance must NOT be inflated with invalid/unknown statuses
      expect(stats.maintenance, equals(0));

      // Breakdown = 0
      expect(stats.breakdown, equals(0));

      // Other / Unknown = 4 (Decommissioned, Unknown, ###INVALID_STATUS###, '')
      expect(stats.other, equals(4));
      expect(stats.unknown, equals(4));
      expect(stats.total, equals(5));

      // Guaranteed invariant: Running + Maintenance + Breakdown + Other == Total
      expect(
        stats.running + stats.maintenance + stats.breakdown + stats.other,
        equals(stats.total),
      );

      // Percentages: 1/5 = 20%, 4/5 = 80%
      expect(stats.runningPercentage, equals(20));
      expect(stats.maintenancePercentage, equals(0));
      expect(stats.breakdownPercentage, equals(0));
      expect(stats.otherPercentage, equals(80));
    });

    test('Mixed dataset with valid and invalid statuses reconciles 100%', () {
      final machines = [
        MachineModel(
          id: 'm1',
          name: 'Running 1',
          productionLine: 'Line A',
          status: 'Operational',
          healthScore: 95,
        ),
        MachineModel(
          id: 'm2',
          name: 'Maintenance 1',
          productionLine: 'Line A',
          status: 'Under Maintenance',
          healthScore: 60,
        ),
        MachineModel(
          id: 'm3',
          name: 'Breakdown 1',
          productionLine: 'Line B',
          status: 'Critical',
          healthScore: 30,
        ),
        MachineModel(
          id: 'm4',
          name: 'Retired 1',
          productionLine: 'Line B',
          status: 'Retired',
          healthScore: 0,
        ),
      ];

      final stats = MachineStatistics.fromMachines(machines);

      expect(stats.total, equals(4));
      expect(stats.running, equals(1));
      expect(stats.maintenance, equals(1));
      expect(stats.breakdown, equals(1));
      expect(stats.other, equals(1));

      expect(
        stats.running + stats.maintenance + stats.breakdown + stats.other,
        equals(stats.total),
      );

      expect(stats.runningRatio, closeTo(0.25, 0.001));
      expect(stats.maintenanceRatio, closeTo(0.25, 0.001));
      expect(stats.breakdownRatio, closeTo(0.25, 0.001));
      expect(stats.otherRatio, closeTo(0.25, 0.001));
    });
  });
}
