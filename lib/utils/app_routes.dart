import 'dart:async';

import 'package:flutter/material.dart';

import '../models/fault_model.dart';
import '../models/machine_model.dart';
import '../models/user_model.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/home_screen.dart';
import '../screens/faults/fault_history_screen.dart';
import '../screens/faults/fault_reporting_screen.dart';
import '../screens/faults/realtime_faults_screen.dart';
import '../screens/machines/machine_details_screen.dart';
import '../screens/machines/machine_form_screen.dart';
import '../screens/machines/machine_list_screen.dart';
import '../screens/maintenance/maintenance_list_screen.dart';
import '../screens/maintenance/maintenance_task_form_screen.dart';
import '../services/fault_service.dart';
import '../services/machine_service.dart';
import '../services/maintenance_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';

class AppRoutes {
  AppRoutes._();

  static const String signupName = '/signup';
  static const String homeName = '/home';
  static const String machinesName = '/machines';
  static const String machineDetailsName = '/machines/details';
  static const String addMachineName = '/machines/add';
  static const String editMachineName = '/machines/edit';
  static const String reportFaultName = '/faults/report';
  static const String faultHistoryName = '/faults/history';
  static const String realtimeFaultsName = '/faults/live';
  static const String maintenanceName = '/maintenance';
  static const String createMaintenanceTaskName = '/maintenance/create';

  static Route<T> _route<T>({
    required String name,
    required WidgetBuilder builder,
  }) {
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: name),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return builder(context);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curvedAnimation);

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }

  static Route<void> signup() {
    return _route<void>(name: signupName, builder: (_) => const SignupScreen());
  }

  static Route<void> homePreview() {
    return _route<void>(name: homeName, builder: (_) => const HomeScreen());
  }

  static Route<void> machines({
    List<MachineModel> machines = const [],
    bool canManage = false,
  }) {
    return _route<void>(
      name: machinesName,
      builder: (_) =>
          MachineListScreen(machines: machines, canManage: canManage),
    );
  }

  static Route<void> machineDetails(
    MachineModel machine, {
    bool canManage = false,
  }) {
    return _route<void>(
      name: machineDetailsName,
      builder: (_) =>
          MachineDetailsScreen(machine: machine, canManage: canManage),
    );
  }

  static Route<void> addMachine({MachineSaveCallback? onSave}) {
    return _route<void>(
      name: addMachineName,
      builder: (_) => MachineFormScreen(onSave: onSave),
    );
  }

  static Route<void> editMachine(
    MachineModel machine, {
    MachineSaveCallback? onSave,
  }) {
    return _route<void>(
      name: editMachineName,
      builder: (_) => MachineFormScreen(machine: machine, onSave: onSave),
    );
  }

  static Route<void> reportFault({
    List<MachineModel> machines = const [],
    MachineModel? initialMachine,
    FaultService? faultService,
    StorageService? storageService,
  }) {
    return _route<void>(
      name: reportFaultName,
      builder: (_) => FaultReportingScreen(
        machines: machines,
        initialMachine: initialMachine,
        faultService: faultService,
        storageService: storageService,
      ),
    );
  }

  static Route<void> faultHistory({
    FaultService? faultService,
    String? machineId,
  }) {
    return _route<void>(
      name: faultHistoryName,
      builder: (_) =>
          FaultHistoryScreen(faultService: faultService, machineId: machineId),
    );
  }

  static Route<void> realtimeFaults({
    Stream<List<FaultModel>>? faultStream,
    FaultService? faultService,
  }) {
    return _route<void>(
      name: realtimeFaultsName,
      builder: (_) => RealtimeFaultsScreen(
        faultStream: faultStream,
        faultService: faultService,
      ),
    );
  }

  static Route<void> maintenance({
    bool assignedOnly = false,
    MaintenanceService? maintenanceService,
  }) {
    return _route<void>(
      name: maintenanceName,
      builder: (_) => MaintenanceListScreen(
        assignedOnly: assignedOnly,
        maintenanceService: maintenanceService,
      ),
    );
  }

  static Route<void> createMaintenanceTask({
    MaintenanceService? maintenanceService,
    UserService? userService,
    MachineService? machineService,
    List<MachineModel>? initialMachines,
    List<UserModel>? initialTechnicians,
  }) {
    return _route<void>(
      name: createMaintenanceTaskName,
      builder: (_) => MaintenanceTaskFormScreen(
        maintenanceService: maintenanceService,
        userService: userService,
        machineService: machineService,
        initialMachines: initialMachines,
        initialTechnicians: initialTechnicians,
      ),
    );
  }
}
