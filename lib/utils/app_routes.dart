import 'package:flutter/material.dart';

import '../models/machine_model.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/home_screen.dart';
import '../screens/machines/machine_details_screen.dart';
import '../screens/machines/machine_form_screen.dart';
import '../screens/machines/machine_list_screen.dart';
import '../screens/faults/fault_reporting_screen.dart';

class AppRoutes {
  AppRoutes._();

  static Route<void> signup() {
    return MaterialPageRoute<void>(builder: (_) => const SignupScreen());
  }

  static Route<void> homePreview() {
    return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
  }

  static Route<void> machines({
    List<MachineModel> machines = const [],
    bool canManage = false,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) =>
          MachineListScreen(machines: machines, canManage: canManage),
    );
  }

  static Route<void> machineDetails(
    MachineModel machine, {
    bool canManage = false,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) =>
          MachineDetailsScreen(machine: machine, canManage: canManage),
    );
  }

  static Route<void> addMachine({MachineSaveCallback? onSave}) {
    return MaterialPageRoute<void>(
      builder: (_) => MachineFormScreen(onSave: onSave),
    );
  }

  static Route<void> editMachine(
    MachineModel machine, {
    MachineSaveCallback? onSave,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => MachineFormScreen(machine: machine, onSave: onSave),
    );
  }
  static Route<void> reportFault({
  List<MachineModel> machines = const [],
  MachineModel? initialMachine,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => FaultReportingScreen(
      machines: machines,
      initialMachine: initialMachine,
    ),
  );
}
}
