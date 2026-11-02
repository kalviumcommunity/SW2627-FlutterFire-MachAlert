import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/machine_provider.dart';
import '../utils/app_constants.dart';
import '../utils/app_routes.dart';

class MainBottomNavigation extends StatelessWidget {
  final int currentIndex;

  const MainBottomNavigation({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) {
      return;
    }

    final appState = context.read<AppStateProvider>();

    final role = appState.user?.role.trim().toLowerCase() ?? '';

    final canManage = role == AppConstants.roleManager;

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(AppRoutes.homePreview());
        break;

      case 1:
        Navigator.of(context)
            .pushReplacement(AppRoutes.machines(canManage: canManage));
        break;

      case 2:
        List<MachineModel> machines = const [];

        try {
          machines = context.read<MachineProvider>().machines;
        } catch (_) {}

        Navigator.of(context)
            .pushReplacement(AppRoutes.reportFault(machines: machines));
        break;

      case 3:
        Navigator.of(context).pushReplacement(AppRoutes.reports());
        break;

      case 4:
        Navigator.of(context).pushReplacement(AppRoutes.profile());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        _navigate(context, index);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.precision_manufacturing_outlined),
          selectedIcon: Icon(Icons.precision_manufacturing),
          label: 'Machines',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_box_outlined),
          selectedIcon: Icon(Icons.add_box),
          label: 'Log Event',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
