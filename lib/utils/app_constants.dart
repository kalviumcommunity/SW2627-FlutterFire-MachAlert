class AppConstants {
  AppConstants._();

  // Application Details
  static const String appName = 'MachAlert';
  static const String appVersion = '1.0.0';

  // Firestore Collection Names
  static const String usersCollection = 'users';
  static const String machinesCollection = 'machines';
  static const String faultsCollection = 'faults';
  static const String maintenanceCollection = 'maintenance';
  static const String alertsCollection = 'alerts';

  // User Roles
  static const String roleOperator = 'operator';
  static const String roleTechnician = 'technician';
  static const String roleManager = 'manager';

  static const List<String> userRoles = [
    roleOperator,
    roleTechnician,
    roleManager,
  ];

  // Machine Statuses
  static const String machineStatusOperational = 'Operational';
  static const String machineStatusWarning = 'Warning';
  static const String machineStatusCritical = 'Critical';
  static const String machineStatusUnderMaintenance = 'Under Maintenance';

  static const List<String> machineStatuses = [
    machineStatusOperational,
    machineStatusWarning,
    machineStatusCritical,
    machineStatusUnderMaintenance,
  ];

  // Common Severities (Faults & Alerts)
  static const String severityLow = 'Low';
  static const String severityMedium = 'Medium';
  static const String severityHigh = 'High';
  static const String severityCritical = 'Critical';

  static const List<String> severities = [
    severityLow,
    severityMedium,
    severityHigh,
    severityCritical,
  ];

  // Fault Statuses
  static const String faultStatusOpen = 'Open';
  static const String faultStatusInProgress = 'In Progress';
  static const String faultStatusResolved = 'Resolved';

  static const List<String> faultStatuses = [
    faultStatusOpen,
    faultStatusInProgress,
    faultStatusResolved,
  ];

  // Maintenance Statuses
  static const String maintenanceStatusPending = 'Pending';
  static const String maintenanceStatusInProgress = 'In Progress';
  static const String maintenanceStatusResolved = 'Resolved';

  static const List<String> maintenanceStatuses = [
    maintenanceStatusPending,
    maintenanceStatusInProgress,
    maintenanceStatusResolved,
  ];

  // Fault Categories / Types
  static const String faultTypeMechanical = 'Mechanical';
  static const String faultTypeElectrical = 'Electrical';
  static const String faultTypeHydraulic = 'Hydraulic';
  static const String faultTypeThermal = 'Thermal';
  static const String faultTypePneumatic = 'Pneumatic';
  static const String faultTypeOther = 'Other';

  static const List<String> faultTypes = [
    faultTypeMechanical,
    faultTypeElectrical,
    faultTypeHydraulic,
    faultTypeThermal,
    faultTypePneumatic,
    faultTypeOther,
  ];
}
