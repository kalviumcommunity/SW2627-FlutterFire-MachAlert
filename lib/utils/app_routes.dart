import 'package:flutter/material.dart';

import '../screens/auth/signup_screen.dart';
import '../screens/dashboard/home_screen.dart';
import '../models/machine_model.dart';
import '../screens/machines/machine_list_screen.dart';
import '../screens/machines/machine_details_screen.dart';

class AppRoutes {
  AppRoutes._();

  static Route<void> signup() {
    return MaterialPageRoute<void>(builder: (_) => const SignupScreen());
  }

  static Route<void> homePreview() {
    return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
  }

  static Route<void> machines({List<MachineModel> machines = const []}) {
    return MaterialPageRoute<void>(
      builder: (_) => MachineListScreen(machines: machines),
    );
  }

  static Route<void> machineDetails(MachineModel machine) {
    return MaterialPageRoute<void>(
      builder: (_) => MachineDetailsScreen(machine: machine),
    );
  }
}
