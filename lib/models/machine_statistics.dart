import 'machine_model.dart';

/// Aggregated industrial machine operational statistics.
///
/// Ensures factory-wide reconciliation between total machine count
/// and individual operational status categories (Running, Maintenance, Breakdown, Other).
class MachineStatistics {
  final int total;
  final int running;
  final int maintenance;
  final int breakdown;
  final int other;

  const MachineStatistics({
    required this.total,
    required this.running,
    required this.maintenance,
    required this.breakdown,
    this.other = 0,
  });

  static const MachineStatistics empty = MachineStatistics(
    total: 0,
    running: 0,
    maintenance: 0,
    breakdown: 0,
    other: 0,
  );

  /// Alias for unrecognized or unclassified machine statuses.
  int get unknown => other;

  /// Alias for warning or other unclassified machine statuses.
  int get warning => other;

  /// Fraction of total machines that are currently running (0.0 to 1.0).
  double get runningRatio => total > 0 ? running / total : 0.0;

  /// Fraction of total machines currently under maintenance (0.0 to 1.0).
  double get maintenanceRatio => total > 0 ? maintenance / total : 0.0;

  /// Fraction of total machines currently broken down / critical (0.0 to 1.0).
  double get breakdownRatio => total > 0 ? breakdown / total : 0.0;

  /// Fraction of total machines with warning, other, or unrecognized status (0.0 to 1.0).
  double get otherRatio => total > 0 ? other / total : 0.0;
  double get unknownRatio => otherRatio;
  double get warningRatio => otherRatio;

  /// Percentage of total machines running (0 to 100).
  int get runningPercentage =>
      total > 0 ? ((running / total) * 100).round() : 0;

  /// Percentage of total machines under maintenance (0 to 100).
  int get maintenancePercentage =>
      total > 0 ? ((maintenance / total) * 100).round() : 0;

  /// Percentage of total machines broken down (0 to 100).
  int get breakdownPercentage =>
      total > 0 ? ((breakdown / total) * 100).round() : 0;

  /// Percentage of total machines with unrecognized or invalid status (0 to 100).
  int get otherPercentage => total > 0 ? ((other / total) * 100).round() : 0;
  int get unknownPercentage => otherPercentage;

  /// Calculates reconciled machine statistics from an authoritative machine inventory.
  ///
  /// Every machine in the inventory is mapped to exactly one operational category:
  /// - Operational / Running -> [running]
  /// - Under Maintenance / In Maintenance -> [maintenance]
  /// - Critical / Breakdown / Broken -> [breakdown]
  /// - Warning -> [other] (Other / Warning)
  /// - Unknown or unclassified statuses -> [other] (Other / Unknown)
  ///
  /// Guarantees the factory reconciliation invariant:
  /// `Running + In Maintenance + Breakdown + Other == Total Machines`.
  factory MachineStatistics.fromMachines(List<MachineModel> machines) {
    int running = 0;
    int maintenance = 0;
    int breakdown = 0;
    int other = 0;

    for (final machine in machines) {
      if (machine.isOperational) {
        running++;
      } else if (machine.isUnderMaintenance) {
        maintenance++;
      } else if (machine.isCritical) {
        breakdown++;
      } else {
        other++;
      }
    }

    return MachineStatistics(
      total: machines.length,
      running: running,
      maintenance: maintenance,
      breakdown: breakdown,
      other: other,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MachineStatistics &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          running == other.running &&
          maintenance == other.maintenance &&
          breakdown == other.breakdown &&
          this.other == other.other;

  @override
  int get hashCode =>
      Object.hash(total, running, maintenance, breakdown, other);

  @override
  String toString() =>
      'MachineStatistics(total: $total, running: $running, maintenance: $maintenance, breakdown: $breakdown, other: $other)';
}
