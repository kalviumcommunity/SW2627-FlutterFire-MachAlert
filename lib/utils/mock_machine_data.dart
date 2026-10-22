import '../models/machine_model.dart';
import 'app_constants.dart';

/// Predefined mock industrial machines for development, manual testing,
/// and automated test fixtures.
class MockMachineData {
  MockMachineData._();

  /// Canonical list of 5 realistic mock machines across multiple production lines
  /// with diverse operational statuses and telemetry values.
  static List<MachineModel> get sampleMachines => [
    MachineModel(
      id: 'mock-cnc-01',
      name: 'CNC Milling Machine 01',
      productionLine: 'Line A',
      modelNumber: 'VMC-850',
      status: AppConstants.machineStatusOperational,
      healthScore: 94.5,
      temperature: 42.0,
      vibration: 0.12,
      lastInspection: DateTime.utc(2026, 10, 15, 8, 30),
      createdAt: DateTime.utc(2026, 1, 15, 0, 0),
      updatedAt: DateTime.utc(2026, 10, 15, 8, 30),
    ),
    MachineModel(
      id: 'mock-press-02',
      name: 'Hydraulic Press 02',
      productionLine: 'Line A',
      modelNumber: 'HP-200T',
      status: AppConstants.machineStatusWarning,
      healthScore: 68.0,
      temperature: 65.5,
      vibration: 0.48,
      lastInspection: DateTime.utc(2026, 10, 18, 14, 0),
      createdAt: DateTime.utc(2026, 2, 10, 0, 0),
      updatedAt: DateTime.utc(2026, 10, 18, 14, 0),
    ),
    MachineModel(
      id: 'mock-conveyor-03',
      name: 'Conveyor Belt 03',
      productionLine: 'Line B',
      modelNumber: 'CB-500-HD',
      status: AppConstants.machineStatusOperational,
      healthScore: 88.0,
      temperature: 35.0,
      vibration: 0.15,
      lastInspection: DateTime.utc(2026, 10, 12, 10, 15),
      createdAt: DateTime.utc(2026, 3, 5, 0, 0),
      updatedAt: DateTime.utc(2026, 10, 12, 10, 15),
    ),
    MachineModel(
      id: 'mock-molding-04',
      name: 'Injection Molding Machine 04',
      productionLine: 'Line B',
      modelNumber: 'IMM-350X',
      status: AppConstants.machineStatusUnderMaintenance,
      healthScore: 55.0,
      temperature: 28.0,
      vibration: 0.05,
      lastInspection: DateTime.utc(2026, 10, 20, 16, 45),
      createdAt: DateTime.utc(2026, 4, 1, 0, 0),
      updatedAt: DateTime.utc(2026, 10, 20, 16, 45),
    ),
    MachineModel(
      id: 'mock-compressor-05',
      name: 'Industrial Compressor 05',
      productionLine: 'Line C',
      modelNumber: 'AC-1200',
      status: AppConstants.machineStatusCritical,
      healthScore: 32.0,
      temperature: 88.2,
      vibration: 0.85,
      lastInspection: DateTime.utc(2026, 10, 21, 9, 0),
      createdAt: DateTime.utc(2026, 5, 20, 0, 0),
      updatedAt: DateTime.utc(2026, 10, 21, 9, 0),
    ),
  ];
}
