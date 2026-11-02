import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/machine_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/machine_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_constants.dart';
import '../utils/app_routes.dart';

class MainBottomNavigation extends StatelessWidget {
  final int currentIndex;

  const MainBottomNavigation({super.key, required this.currentIndex});

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) {
      return;
    }

    final role =
        context.read<AppStateProvider>().user?.role.trim().toLowerCase() ?? '';

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
    const items = [
      _NavItem(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _NavItem(
        label: 'Machines',
        icon: Icons.precision_manufacturing_outlined,
        selectedIcon: Icons.precision_manufacturing,
      ),
      _NavItem(
        label: 'Log Event',
        icon: Icons.add_box_outlined,
        selectedIcon: Icons.add_box,
      ),
      _NavItem(
        label: 'Reports',
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart_rounded,
      ),
      _NavItem(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];

    return BottomAppBar(
      height: 72,
      padding: EdgeInsets.zero,
      color: Colors.white,
      elevation: 8,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE7EDF2))),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;

            final color = selected ? AppTheme.green : const Color(0xFF8494A3);

            return Expanded(
              child: InkWell(
                onTap: () {
                  _navigate(context, index);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? item.selectedIcon : item.icon,
                      color: color,
                      size: 23,
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        text: item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
