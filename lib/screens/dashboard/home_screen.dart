import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fault_model.dart';
import '../../models/machine_model.dart';
import '../../models/maintenance_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/machine_provider.dart';
import '../../services/auth_service.dart';
import '../../services/fault_service.dart';
import '../../services/maintenance_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../../widgets/app_button.dart';
import '../../widgets/dashboard_action_card.dart';
import '../../widgets/dashboard_stat_card.dart';
import '../../widgets/mach_alert_logo.dart';
import '../../widgets/main_bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  final FaultService? faultService;
  final MachineProvider? machineProvider;
  final MaintenanceService? maintenanceService;

  const HomeScreen({
    super.key,
    this.faultService,
    this.machineProvider,
    this.maintenanceService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSigningOut = false;

  Stream<List<FaultModel>>? _managerFaultStream;
  Stream<List<FaultModel>>? _technicianFaultStream;
  Stream<List<MaintenanceModel>>? _technicianAssignedTasksStream;

  @override
  void initState() {
    super.initState();

    widget.machineProvider?.addListener(_onMachineProviderChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _checkAndInitRoleServices();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.machineProvider != oldWidget.machineProvider) {
      oldWidget.machineProvider?.removeListener(_onMachineProviderChanged);

      widget.machineProvider?.addListener(_onMachineProviderChanged);
    }

    if (widget.faultService != oldWidget.faultService) {
      _managerFaultStream = null;
      _technicianFaultStream = null;

      _initManagerFaultStream();
      _initTechnicianStreams();
    }

    if (widget.maintenanceService != oldWidget.maintenanceService) {
      _technicianAssignedTasksStream = null;

      _initTechnicianStreams();
    }
  }

  @override
  void dispose() {
    widget.machineProvider?.removeListener(_onMachineProviderChanged);

    super.dispose();
  }

  void _onMachineProviderChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  FaultService? _resolveFaultService() {
    if (widget.faultService != null) {
      return widget.faultService;
    }

    try {
      return context.read<FaultService>();
    } catch (_) {
      return null;
    }
  }

  MachineProvider? _resolveMachineProvider() {
    if (widget.machineProvider != null) {
      return widget.machineProvider;
    }

    try {
      return context.read<MachineProvider>();
    } catch (_) {
      return null;
    }
  }

  MaintenanceService? _resolveMaintenanceService() {
    if (widget.maintenanceService != null) {
      return widget.maintenanceService;
    }

    try {
      return context.read<MaintenanceService>();
    } catch (_) {
      return null;
    }
  }

  void _checkAndInitRoleServices() {
    try {
      final role = context
          .read<AppStateProvider>()
          .user
          ?.role
          .trim()
          .toLowerCase();

      if (role == AppConstants.roleManager) {
        _initManagerFaultStream();

        _scheduleMachineSubscription();
      } else if (role == AppConstants.roleTechnician) {
        _initTechnicianStreams();

        _scheduleMachineSubscription();
      }
    } catch (_) {}
  }

  void _initManagerFaultStream() {
    if (_managerFaultStream != null) {
      return;
    }

    try {
      final role = context
          .read<AppStateProvider>()
          .user
          ?.role
          .trim()
          .toLowerCase();

      if (role != AppConstants.roleManager) {
        return;
      }

      final faultService = _resolveFaultService();

      if (faultService != null) {
        _managerFaultStream = faultService.streamFaults();
      }
    } catch (_) {
      _managerFaultStream = null;
    }
  }

  void _initTechnicianStreams() {
    try {
      final role = context
          .read<AppStateProvider>()
          .user
          ?.role
          .trim()
          .toLowerCase();

      if (role != null &&
          role.isNotEmpty &&
          role != AppConstants.roleTechnician) {
        return;
      }
    } catch (_) {}

    if (_technicianFaultStream == null) {
      final faultService = _resolveFaultService();
      if (faultService != null) {
        _technicianFaultStream = faultService.streamFaults();
      }
    }

    if (_technicianAssignedTasksStream == null) {
      final maintenanceService = _resolveMaintenanceService();
      if (maintenanceService != null) {
        try {
          _technicianAssignedTasksStream =
              maintenanceService.streamAssignedMaintenanceTasks();
        } catch (_) {
          _technicianAssignedTasksStream = null;
        }
      }
    }
  }

  void _scheduleMachineSubscription() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      try {
        final currentRole = context
            .read<AppStateProvider>()
            .user
            ?.role
            .trim()
            .toLowerCase();

        if (currentRole == AppConstants.roleManager ||
            currentRole == AppConstants.roleTechnician) {
          final provider = _resolveMachineProvider();

          if (provider != null && !provider.hasActiveSubscription) {
            provider.subscribeToMachines();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await context.read<AuthService>().signOut();
    } on AuthServiceException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
      machines = _resolveMachineProvider()?.machines ?? const [];
    } catch (_) {}

    Navigator.of(context).push<void>(AppRoutes.reportFault(machines: machines));
  }

  void _openFaultHistory() {
    Navigator.of(
      context,
    ).push<void>(AppRoutes.faultHistory(faultService: _resolveFaultService()));
  }

  void _openRealtimeFaults() {
    Navigator.of(context).push<void>(
      AppRoutes.realtimeFaults(faultService: _resolveFaultService()),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature will be available soon.')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    final user = appState.user;

    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'MachAlert User';

    final role = user?.role.trim().toLowerCase() ?? '';

    if (role != AppConstants.roleManager && _managerFaultStream != null) {
      _managerFaultStream = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const MachAlertLogo(compact: true),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              _showComingSoon('Notifications');
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 0),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
          children: [
            Text(
              'Hi, ${_firstName(name)}',
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Here's today's overview",
              style: TextStyle(color: Color(0xFF778896), fontSize: 13),
            ),

            const SizedBox(height: 8),

            Text(
              _roleLabel(role),
              style: const TextStyle(
                color: AppTheme.green,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 24),

            _buildDashboardForRole(role),

            const SizedBox(height: 26),

            _buildRecentActivity(),

            const SizedBox(height: 26),

            AppButton(
              text: 'Logout',
              isLoading: _isSigningOut,
              onPressed: _isSigningOut ? null : _handleLogout,
            ),
          ],
        ),
      ),
    );
  }

  String _firstName(String name) {
    final pieces = name.trim().split(RegExp(r'\s+'));

    return pieces.isEmpty ? name : pieces.first;
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
    _initManagerFaultStream();
    _scheduleMachineSubscription();

    MachineProvider? provider = widget.machineProvider;

    if (provider == null) {
      try {
        provider = context.watch<MachineProvider>();
      } catch (_) {}
    }

    final isReady =
        provider != null &&
        provider.hasActiveSubscription &&
        !provider.isLoading &&
        !provider.hasError;

    final stats = isReady ? provider.statistics : null;

    final machineCount = stats != null ? stats.total.toString() : '--';
    final runningCount = stats != null ? stats.running.toString() : '--';
    final maintenanceCount = stats != null
        ? stats.maintenance.toString()
        : '--';
    final breakdownCount = stats != null ? stats.breakdown.toString() : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Factory Overview',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                label: 'Machines',
                value: machineCount,
                icon: Icons.precision_manufacturing,
                accentColor: AppTheme.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardStatCard(
                label: 'Running',
                value: runningCount,
                icon: Icons.play_circle_outline,
                accentColor: AppTheme.green,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                label: 'In Maintenance',
                value: maintenanceCount,
                icon: Icons.build_circle_outlined,
                accentColor: AppTheme.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DashboardStatCard(
                label: 'Breakdown',
                value: breakdownCount,
                icon: Icons.warning_amber_rounded,
                accentColor: AppTheme.danger,
              ),
            ),
          ],
        ),

        if (stats != null && stats.other > 0) ...[
          const SizedBox(height: 10),
          DashboardStatCard(
            label: 'Other / Unknown',
            value: stats.other.toString(),
            icon: Icons.help_outline,
            accentColor: const Color(0xFF788896),
          ),
        ],

        const SizedBox(height: 10),

        StreamBuilder<List<FaultModel>>(
          stream: _managerFaultStream,
          builder: (context, snapshot) {
            String count = '--';

            if (_managerFaultStream != null &&
                !snapshot.hasError &&
                snapshot.connectionState != ConnectionState.waiting &&
                snapshot.hasData) {
              final faults = snapshot.data ?? const [];

              count = faults
                  .where((fault) {
                    final status = fault.status.trim().toLowerCase();

                    return status ==
                            AppConstants.faultStatusOpen.toLowerCase() ||
                        status ==
                            AppConstants.faultStatusInProgress.toLowerCase();
                  })
                  .length
                  .toString();
            }

            return DashboardStatCard(
              label: 'Active Faults',
              value: count,
              icon: Icons.report_problem_outlined,
              accentColor: AppTheme.danger,
            );
          },
        ),

        const SizedBox(height: 22),

        _actionsHeading(),

        const SizedBox(height: 10),

        DashboardActionCard(
          title: 'Machines',
          subtitle: 'View production machines',
          icon: Icons.precision_manufacturing,
          accentColor: AppTheme.blue,
          onTap: _openMachines,
        ),

        DashboardActionCard(
          title: 'Fault History',
          subtitle: 'View history of reported faults',
          icon: Icons.history,
          accentColor: AppTheme.warning,
          onTap: _openFaultHistory,
        ),

        DashboardActionCard(
          title: 'Faults',
          subtitle: 'Monitor active machine faults',
          icon: Icons.warning,
          accentColor: AppTheme.danger,
          onTap: _openRealtimeFaults,
        ),

        DashboardActionCard(
          title: 'Maintenance',
          subtitle: 'Track maintenance activity',
          icon: Icons.build,
          accentColor: AppTheme.green,
          onTap: () {
            Navigator.of(context).push<void>(AppRoutes.maintenance());
          },
        ),
      ],
    );
  }

  Widget _buildTechnicianDashboard() {
    _initTechnicianStreams();
    _scheduleMachineSubscription();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Maintenance Overview',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: StreamBuilder<List<MaintenanceModel>>(
                stream: _technicianAssignedTasksStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const DashboardStatCard(
                      label: 'Assigned Tasks',
                      value: 'Error',
                      hasError: true,
                      icon: Icons.assignment_outlined,
                      accentColor: AppTheme.blue,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const DashboardStatCard(
                      label: 'Assigned Tasks',
                      value: '',
                      isLoading: true,
                      icon: Icons.assignment_outlined,
                      accentColor: AppTheme.blue,
                    );
                  }

                  final tasks = snapshot.data ?? const [];
                  final activeTasksCount = tasks.where((task) {
                    final status = task.status.trim().toLowerCase();
                    return status ==
                            AppConstants.maintenanceStatusPending
                                .toLowerCase() ||
                        status ==
                            AppConstants.maintenanceStatusInProgress
                                .toLowerCase();
                  }).length;

                  return DashboardStatCard(
                    label: 'Assigned Tasks',
                    value: activeTasksCount.toString(),
                    icon: Icons.assignment_outlined,
                    accentColor: AppTheme.blue,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StreamBuilder<List<FaultModel>>(
                stream: _technicianFaultStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const DashboardStatCard(
                      label: 'Active Faults',
                      value: 'Error',
                      hasError: true,
                      icon: Icons.warning_amber,
                      accentColor: AppTheme.danger,
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const DashboardStatCard(
                      label: 'Active Faults',
                      value: '',
                      isLoading: true,
                      icon: Icons.warning_amber,
                      accentColor: AppTheme.danger,
                    );
                  }

                  final faults = snapshot.data ?? const [];
                  final activeFaultsCount = faults.where((fault) {
                    final status = fault.status.trim().toLowerCase();
                    return status ==
                            AppConstants.faultStatusOpen.toLowerCase() ||
                        status ==
                            AppConstants.faultStatusInProgress.toLowerCase();
                  }).length;

                  return DashboardStatCard(
                    label: 'Active Faults',
                    value: activeFaultsCount.toString(),
                    icon: Icons.warning_amber,
                    accentColor: AppTheme.danger,
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        _actionsHeading(),

        const SizedBox(height: 10),

        DashboardActionCard(
          title: 'Assigned Maintenance',
          subtitle: 'View your maintenance tasks',
          icon: Icons.assignment_turned_in,
          accentColor: AppTheme.green,
          onTap: () {
            Navigator.of(context)
                .push<void>(AppRoutes.maintenance(assignedOnly: true));
          },
        ),

        DashboardActionCard(
          title: 'Active Faults',
          subtitle: 'Inspect reported machine faults',
          icon: Icons.warning,
          accentColor: AppTheme.danger,
          onTap: _openRealtimeFaults,
        ),

        DashboardActionCard(
          title: 'Fault History',
          subtitle: 'View history of reported faults',
          icon: Icons.history,
          accentColor: AppTheme.warning,
          onTap: _openFaultHistory,
        ),

        DashboardActionCard(
          title: 'Machines',
          subtitle: 'View machine information',
          icon: Icons.precision_manufacturing,
          accentColor: AppTheme.blue,
          onTap: _openMachines,
        ),
      ],
    );
  }

  Widget _buildOperatorDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Machine Operations',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 12),

        DashboardActionCard(
          title: 'Machines',
          subtitle: 'View machines on your production line',
          icon: Icons.precision_manufacturing,
          accentColor: AppTheme.blue,
          onTap: _openMachines,
        ),

        DashboardActionCard(
          title: 'Report Fault',
          subtitle: 'Report a machine problem immediately',
          icon: Icons.report_problem,
          accentColor: AppTheme.danger,
          onTap: _openFaultReporting,
        ),

        DashboardActionCard(
          title: 'Fault History',
          subtitle: 'View history of reported faults',
          icon: Icons.history,
          accentColor: AppTheme.warning,
          onTap: _openFaultHistory,
        ),

        DashboardActionCard(
          title: 'My Reports',
          subtitle: 'Review faults you have reported',
          icon: Icons.bar_chart_outlined,
          accentColor: AppTheme.green,
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

  Widget _actionsHeading() {
    return const Text(
      'Quick Actions',
      style: TextStyle(
        color: AppTheme.navy,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildRecentActivity() {
    List<MachineModel> machines = const [];

    try {
      machines = _resolveMachineProvider()?.machines ?? const [];
    } catch (_) {}

    final recent = machines.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Activity',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(onPressed: _openMachines, child: const Text('See All')),
          ],
        ),

        const SizedBox(height: 6),

        Card(
          child: recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(Icons.history_toggle_off, color: Color(0xFF8B9AA7)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Machine activity will appear here as data becomes available.',
                          style: TextStyle(
                            color: Color(0xFF718292),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: List.generate(recent.length, (index) {
                    final machine = recent[index];

                    final color = _machineStatusColor(machine.status);

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Machine ${machine.id}',
                                      style: const TextStyle(
                                        color: AppTheme.navy,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      machine.name,
                                      style: const TextStyle(
                                        color: Color(0xFF7B8B98),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                machine.status,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index != recent.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Color _machineStatusColor(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'operational' || normalized == 'running') {
      return AppTheme.green;
    }

    if (normalized.contains('maintenance') || normalized == 'warning') {
      return AppTheme.warning;
    }

    if (normalized == 'critical' || normalized == 'breakdown') {
      return AppTheme.danger;
    }

    return const Color(0xFF8B9AA7);
  }
}
