import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/machine_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/machine_provider.dart';
import '../../services/auth_service.dart';
import '../../services/fault_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../../widgets/app_button.dart';
import '../../widgets/dashboard_action_card.dart';
import '../../widgets/dashboard_stat_card.dart';

class HomeScreen extends StatefulWidget {
  final FaultService? faultService;

  const HomeScreen({super.key, this.faultService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSigningOut = false;

  Future<void> _handleLogout() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      final authService = context.read<AuthService>();

      await authService.signOut();
    } on AuthServiceException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to logout. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _openMachines() {
    final role = context
        .read<AppStateProvider>()
        .user
        ?.role
        .trim()
        .toLowerCase();

    Navigator.of(context).push<void>(
      AppRoutes.machines(canManage: role == AppConstants.roleManager),
    );
  }

  void _openFaultReporting() {
    List<MachineModel> machines = const [];

    try {
      machines = context.read<MachineProvider>().machines;
    } catch (_) {}

    Navigator.of(context).push<void>(AppRoutes.reportFault(machines: machines));
  }

  void _openFaultHistory() {
    FaultService? faultService = widget.faultService;
    if (faultService == null) {
      try {
        faultService = context.read<FaultService>();
      } catch (_) {}
    }

    Navigator.of(context)
        .push<void>(AppRoutes.faultHistory(faultService: faultService));
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature will be available soon.')));
  }

  void _openRealtimeFaults() {
    FaultService? faultService = widget.faultService;
    if (faultService == null) {
      try {
        faultService = context.read<FaultService>();
      } catch (_) {}
    }

    Navigator.of(context)
        .push<void>(AppRoutes.realtimeFaults(faultService: faultService));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final user = appState.user;

    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'MachAlert User';

    final role = user?.role.trim().toLowerCase() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('MachAlert')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome, $name',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 6),

              Text(
                _roleLabel(role),
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 24),

              _buildDashboardForRole(role),

              const SizedBox(height: 32),

              AppButton(
                text: 'Logout',
                isLoading: _isSigningOut,
                onPressed: _isSigningOut ? null : _handleLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case AppConstants.roleManager:
        return 'Manager Dashboard';

      case AppConstants.roleTechnician:
        return 'Technician Dashboard';

      case AppConstants.roleOperator:
        return 'Operator Dashboard';

      default:
        return 'Dashboard';
    }
  }

  Widget _buildDashboardForRole(String role) {
    switch (role) {
      case AppConstants.roleManager:
        return _buildManagerDashboard();

      case AppConstants.roleTechnician:
        return _buildTechnicianDashboard();

      case AppConstants.roleOperator:
        return _buildOperatorDashboard();

      default:
        return _buildDefaultDashboard();
    }
  }

  Widget _buildManagerDashboard() {
    MachineProvider? machineProvider;

    try {
      machineProvider = context.watch<MachineProvider>();
    } catch (_) {}

    final machineCount = machineProvider != null && !machineProvider.isLoading
        ? machineProvider.machines.length.toString()
        : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Factory Overview', style: Theme.of(context).textTheme.titleLarge),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                label: 'Machines',
                value: machineCount,
                icon: Icons.precision_manufacturing,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: DashboardStatCard(
                label: 'Active Faults',
                value: '--',
                icon: Icons.warning_amber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        DashboardActionCard(
          title: 'Machines',
          subtitle: 'View production machines',
          icon: Icons.precision_manufacturing,
          onTap: _openMachines,
        ),

        DashboardActionCard(
          title: 'Fault History',
          subtitle: 'View history of reported faults',
          icon: Icons.history,
          onTap: _openFaultHistory,
        ),

        DashboardActionCard(
          title: 'Faults',
          subtitle: 'Monitor active machine faults',
          icon: Icons.warning,
          onTap: _openRealtimeFaults,
        ),

        DashboardActionCard(
          title: 'Maintenance',
          subtitle: 'Track maintenance activity',
          icon: Icons.build,
          onTap: () {
            _showComingSoon('Maintenance');
          },
        ),
      ],
    );
  }

  Widget _buildTechnicianDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Maintenance Overview',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 12),

        const Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                label: 'Assigned Tasks',
                value: '--',
                icon: Icons.assignment,
              ),
            ),

            SizedBox(width: 12),

            Expanded(
              child: DashboardStatCard(
                label: 'Active Faults',
                value: '--',
                icon: Icons.warning_amber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        DashboardActionCard(
          title: 'Assigned Maintenance',
          subtitle: 'View your maintenance tasks',
          icon: Icons.assignment_turned_in,
          onTap: () {
            _showComingSoon('Assigned maintenance');
          },
        ),

        DashboardActionCard(
          title: 'Active Faults',
          subtitle: 'Inspect reported machine faults',
          icon: Icons.warning,
          onTap: _openRealtimeFaults,
        ),

        DashboardActionCard(
          title: 'Fault History',
          subtitle: 'View history of reported faults',
          icon: Icons.history,
          onTap: _openFaultHistory,
        ),

        DashboardActionCard(
          title: 'Machines',
          subtitle: 'View machine information',
          icon: Icons.precision_manufacturing,
          onTap: _openMachines,
        ),
      ],
    );
  }

  Widget _buildOperatorDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Machine Operations',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 12),

        DashboardActionCard(
          title: 'Machines',
          subtitle: 'View machines on your production line',
          icon: Icons.precision_manufacturing,
          onTap: _openMachines,
        ),

        DashboardActionCard(
          title: 'Report Fault',
          subtitle: 'Report a machine problem immediately',
          icon: Icons.report_problem,
          onTap: _openFaultReporting,
        ),

        DashboardActionCard(
          title: 'Fault History',
          subtitle: 'View history of reported faults',
          icon: Icons.history,
          onTap: _openFaultHistory,
        ),

        DashboardActionCard(
          title: 'My Reports',
          subtitle: 'Review faults you have reported',
          icon: Icons.history,
          onTap: () {
            _showComingSoon('My reports');
          },
        ),
      ],
    );
  }

  Widget _buildDefaultDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Your role is being prepared.'),

        const SizedBox(height: 16),

        DashboardActionCard(
          title: 'Machines',
          subtitle: 'Machine information will appear here',
          icon: Icons.precision_manufacturing,
          onTap: _openMachines,
        ),
      ],
    );
  }
}
