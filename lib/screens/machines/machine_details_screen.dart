import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/machine_activity_log_model.dart';
import '../../models/machine_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/machine_provider.dart';
import '../../services/fault_service.dart';
import '../../services/machine_activity_service.dart';
import '../../services/machine_service.dart';
import '../../services/maintenance_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../../widgets/app_state_view.dart';
import '../../widgets/main_bottom_navigation.dart';

class MachineDetailsScreen extends StatefulWidget {
  final MachineModel machine;
  final bool canManage;
  final MachineActivityService? activityService;
  final FaultService? faultService;
  final MaintenanceService? maintenanceService;
  final UserService? userService;

  const MachineDetailsScreen({
    super.key,
    required this.machine,
    this.canManage = false,
    this.activityService,
    this.faultService,
    this.maintenanceService,
    this.userService,
  });

  @override
  State<MachineDetailsScreen> createState() => _MachineDetailsScreenState();
}

class _MachineDetailsScreenState extends State<MachineDetailsScreen> {
  int _selectedTab = 0;
  MachineModel? _localMachine;
  Key _logsStreamKey = UniqueKey();

  MachineActivityService get _activityService {
    if (widget.activityService != null) return widget.activityService!;
    try {
      return Provider.of<MachineActivityService>(context, listen: false);
    } catch (_) {
      return MachineActivityService(
        faultService: widget.faultService,
        maintenanceService: widget.maintenanceService,
        userService: widget.userService,
      );
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _logsStreamKey = UniqueKey();
    });
    try {
      final provider = Provider.of<MachineProvider>(context, listen: false);
      await provider.fetchMachines();
    } catch (_) {}
  }

  MachineModel get machine {
    try {
      final provider = Provider.of<MachineProvider>(context, listen: false);

      if (provider.selectedMachine?.id == widget.machine.id) {
        return provider.selectedMachine!;
      }

      final match = provider.getMachineById(widget.machine.id);

      if (match != null) {
        return match;
      }
    } catch (_) {}

    return _localMachine ?? widget.machine;
  }

  bool _resolveCanManage(BuildContext context) {
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);

      final role = appState.user?.role.trim().toLowerCase();

      return role == AppConstants.roleManager;
    } catch (_) {
      return false;
    }
  }

  void _handleManagementAction(String action, bool canManage) {
    if (!canManage || !_resolveCanManage(context)) {
      return;
    }

    switch (action) {
      case 'edit':
        _openEditMachine(canManage);
        break;

      case 'delete':
        _showDeleteConfirmation(canManage);
        break;
    }
  }

  Future<void> _openEditMachine(bool canManage) async {
    if (!canManage || !_resolveCanManage(context)) {
      return;
    }

    await Navigator.of(context).push<void>(AppRoutes.editMachine(machine));

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showDeleteConfirmation(bool canManage) async {
    if (!canManage || !_resolveCanManage(context)) {
      return;
    }

    final currentMachine = machine;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Machine?'),
          content: Text(
            'Are you sure you want to delete '
            '${currentMachine.id} - ${currentMachine.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      MachineProvider? provider;

      try {
        provider = Provider.of<MachineProvider>(context, listen: false);
      } catch (_) {}

      if (provider != null) {
        await provider.deleteMachine(currentMachine.id);
      } else {
        MachineService? service;

        try {
          service = Provider.of<MachineService>(context, listen: false);
        } catch (_) {}

        service ??= MachineService();

        await service.deleteMachine(currentMachine.id);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Machine ${currentMachine.id} deleted successfully.'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is MachineServiceException
          ? error.message
          : error.toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete machine: $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _resolveCanManage(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Machine Details'),
        actions: [
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Manage machine',
              onSelected: (action) {
                _handleManagementAction(action, canManage);
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 12),
                        Text('Edit Machine'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppTheme.danger),
                        SizedBox(width: 12),
                        Text('Delete Machine'),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMachineHeader(),

                const SizedBox(height: 18),

                _buildTabs(),

                const SizedBox(height: 18),

                _buildSelectedTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineHeader() {
    final status = _statusStyle(machine.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5ECF1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.precision_manufacturing,
              size: 38,
              color: AppTheme.navy,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.id,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  machine.name,
                  style: const TextStyle(
                    color: Color(0xFF526575),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (machine.productionLine.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    machine.productionLine,
                    style: const TextStyle(
                      color: Color(0xFF8A99A6),
                      fontSize: 11,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: status.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const labels = ['Overview', 'Logs', 'Trend'];

    return Container(
      height: 43,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _selectedTab == index;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTab) {
      case 1:
        return _buildLogsTab();

      case 2:
        return _buildTrendTab();

      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total Inspections',
                value: '--',
                icon: Icons.fact_check_outlined,
                color: AppTheme.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Total Breakdowns',
                value: '--',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.danger,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Health Score',
                value: '${machine.healthScore.toStringAsFixed(0)}%',
                icon: Icons.favorite_outline,
                color: AppTheme.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Temperature',
                value: machine.temperature == null
                    ? '--'
                    : '${machine.temperature!.toStringAsFixed(1)}°C',
                icon: Icons.thermostat,
                color: AppTheme.warning,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _MetricCard(
          label: 'Vibration',
          value: machine.vibration == null
              ? '--'
              : machine.vibration!.toStringAsFixed(1),
          icon: Icons.vibration,
          color: AppTheme.blue,
        ),

        const SizedBox(height: 24),

        const _SectionHeading(title: 'Inspection Information'),

        const SizedBox(height: 10),

        _InformationTile(
          icon: Icons.event_available,
          title: 'Last Inspection',
          value: _formatDateTime(machine.lastInspection),
        ),

        const SizedBox(height: 8),

        _InformationTile(
          icon: Icons.confirmation_number_outlined,
          title: 'Model Number',
          value: machine.modelNumber?.isNotEmpty == true
              ? machine.modelNumber!
              : '--',
        ),

        const SizedBox(height: 22),

        _buildRecentLogsPreview(),

        const SizedBox(height: 22),

        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                AppRoutes.reportFault(
                  machines: [machine],
                  initialMachine: machine,
                ),
              );
            },
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report Fault'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentLogsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeading(title: 'Recent Logs')),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedTab = 1;
                });
              },
              child: const Text('See All'),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history,
                    size: 20,
                    color: AppTheme.green,
                  ),
                ),

                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    'Machine activity logs will appear here once available.',
                    style: TextStyle(
                      color: Color(0xFF6F8190),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(title: 'Machine Logs'),
        const SizedBox(height: 12),

        StreamBuilder<List<MachineActivityLogModel>>(
          key: _logsStreamKey,
          stream: _activityService.streamMachineActivity(machine.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: AppStateView.loading(
                  title: 'Loading Activity Logs...',
                  message: 'Streaming real-time machine history from Firestore.',
                ),
              );
            }

            if (snapshot.hasError) {
              final message = snapshot.error is MachineServiceException
                  ? (snapshot.error as MachineServiceException).message
                  : 'Failed to retrieve machine activity events. Please try again.';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppStateView.error(
                  title: 'Unable to Load Logs',
                  message: message,
                  actionLabel: 'Retry',
                  onAction: () {
                    setState(() {
                      _logsStreamKey = UniqueKey();
                    });
                  },
                ),
              );
            }

            final events = snapshot.data ?? const [];
            if (events.isEmpty) {
              return const _EmptyPanel(
                icon: Icons.receipt_long_outlined,
                title: 'No logs yet',
                description:
                    'Inspection and breakdown logs will appear here once connected to Firestore.',
              );
            }

            return _buildActivityTimeline(events);
          },
        ),
      ],
    );
  }

  Widget _buildActivityTimeline(List<MachineActivityLogModel> events) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final event = events[index];
        final isFirst = index == 0;
        final isLast = index == events.length - 1;
        return _buildTimelineItem(event, isFirst: isFirst, isLast: isLast);
      },
    );
  }

  Widget _buildTimelineItem(
    MachineActivityLogModel event, {
    required bool isFirst,
    required bool isLast,
  }) {
    final themeData = _resolveEventTheme(event);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Vertical timeline line & icon node
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 12,
                  color: isFirst ? Colors.transparent : const Color(0xFFDCE5EC),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: themeData.nodeBgColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: themeData.nodeBorderColor,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    themeData.icon,
                    size: 15,
                    color: themeData.nodeIconColor,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : const Color(0xFFDCE5EC),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Right: Event Details Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5ECF1)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Event Title + Status Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(event.status),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Timestamp
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 12,
                          color: Color(0xFF718292),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.formattedDateTime,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF718292),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Actor (Reporter / Technician)
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 12,
                          color: Color(0xFF718292),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${event.actorRole}: ${event.actorName}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF718292),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Severity & Type Chips (if applicable)
                    if (event.severity != null || event.faultType != null) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (event.faultType != null)
                            _buildInfoChip(
                              label: event.faultType!,
                              icon: Icons.category_outlined,
                              color: const Color(0xFF526575),
                            ),
                          if (event.severity != null)
                            _buildSeverityChip(event.severity!),
                        ],
                      ),
                    ],

                    // Description / Notes
                    if (event.description != null &&
                        event.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        event.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ],

                    // Proof Image Attachment Indicator
                    if (event.hasProofImage) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 14,
                              color: AppTheme.navy,
                            ),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Photo proof attached',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.navy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final s = status.trim().toLowerCase();
    final Color bg;
    final Color text;
    final Color border;

    if (s == 'resolved' || s == 'completed' || s == 'operational') {
      bg = const Color(0xFFE8F6F3);
      text = const Color(0xFF2E7D6F);
      border = const Color(0xFFBBE5DD);
    } else if (s == 'in progress') {
      bg = const Color(0xFFFFF7ED);
      text = const Color(0xFFC2410C);
      border = const Color(0xFFFED7AA);
    } else if (s == 'pending' || s == 'assigned') {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF1D4ED8);
      border = const Color(0xFFBFDBFE);
    } else {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
      border = const Color(0xFFFECACA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String severity) {
    final s = severity.trim().toLowerCase();
    final Color color;
    if (s == 'critical' || s == 'high') {
      color = AppTheme.danger;
    } else if (s == 'medium') {
      color = AppTheme.warning;
    } else {
      color = AppTheme.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              severity,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  _TimelineEventTheme _resolveEventTheme(MachineActivityLogModel event) {
    switch (event.type) {
      case MachineActivityType.faultReported:
        return const _TimelineEventTheme(
          icon: Icons.warning_amber_rounded,
          nodeBgColor: Color(0xFFFEF2F2),
          nodeBorderColor: Color(0xFFFECACA),
          nodeIconColor: AppTheme.danger,
        );
      case MachineActivityType.faultStatusChanged:
        return const _TimelineEventTheme(
          icon: Icons.update_rounded,
          nodeBgColor: Color(0xFFEFF6FF),
          nodeBorderColor: Color(0xFFBFDBFE),
          nodeIconColor: AppTheme.blue,
        );
      case MachineActivityType.maintenanceAssigned:
        return const _TimelineEventTheme(
          icon: Icons.assignment_ind_outlined,
          nodeBgColor: Color(0xFFF0F5F7),
          nodeBorderColor: Color(0xFFDCE5EC),
          nodeIconColor: AppTheme.navy,
        );
      case MachineActivityType.maintenanceInProgress:
        return const _TimelineEventTheme(
          icon: Icons.engineering_outlined,
          nodeBgColor: Color(0xFFFFF7ED),
          nodeBorderColor: Color(0xFFFED7AA),
          nodeIconColor: Color(0xFFEA580C),
        );
      case MachineActivityType.maintenanceResolved:
        return const _TimelineEventTheme(
          icon: Icons.check_circle_outline_rounded,
          nodeBgColor: Color(0xFFE8F6F3),
          nodeBorderColor: Color(0xFFBBE5DD),
          nodeIconColor: AppTheme.green,
        );
      case MachineActivityType.maintenanceNote:
        return const _TimelineEventTheme(
          icon: Icons.note_alt_outlined,
          nodeBgColor: Color(0xFFF1F5F9),
          nodeBorderColor: Color(0xFFCBD5E1),
          nodeIconColor: AppTheme.navy,
        );
    }
  }

  Widget _buildTrendTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(title: 'Machine Trend'),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: AppTheme.green, label: 'Health'),
                    SizedBox(width: 18),
                    _LegendDot(color: AppTheme.blue, label: 'Vibration'),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 170,
                  child: CustomPaint(painter: _MachineTrendPainter()),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Machine health and sensor trends will appear here in a later analytics task.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF7A8B98),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '--';
    }

    final local = value.toLocal();

    final day = local.day.toString().padLeft(2, '0');

    final month = local.month.toString().padLeft(2, '0');

    final year = local.year;

    final hour = local.hour.toString().padLeft(2, '0');

    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  _MachineStatusStyle _statusStyle(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'operational' || normalized == 'running') {
      return const _MachineStatusStyle(label: 'Running', color: AppTheme.green);
    }

    if (normalized.contains('maintenance') || normalized == 'warning') {
      return const _MachineStatusStyle(
        label: 'Under Maintenance',
        color: AppTheme.warning,
      );
    }

    if (normalized == 'critical' || normalized == 'breakdown') {
      return const _MachineStatusStyle(
        label: 'Breakdown',
        color: AppTheme.danger,
      );
    }

    return const _MachineStatusStyle(
      label: 'Unknown',
      color: Color(0xFF8A98A4),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF7B8A97),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InformationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InformationTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: AppTheme.navy),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF7B8A97),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;

  const _SectionHeading({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.navy,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F7),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: AppTheme.navy),
            ),

            const SizedBox(height: 14),

            Text(
              title,
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7A8B98),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF647684), fontSize: 10),
        ),
      ],
    );
  }
}

class _MachineTrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE8EEF2)
      ..strokeWidth = 1;

    for (var i = 1; i < 5; i++) {
      final y = size.height / 5 * i;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final healthPaint = Paint()
      ..color = AppTheme.green
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final vibrationPaint = Paint()
      ..color = AppTheme.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final healthPath = Path()
      ..moveTo(0, size.height * .65)
      ..lineTo(size.width * .14, size.height * .54)
      ..lineTo(size.width * .28, size.height * .48)
      ..lineTo(size.width * .42, size.height * .36)
      ..lineTo(size.width * .57, size.height * .43)
      ..lineTo(size.width * .72, size.height * .28)
      ..lineTo(size.width * .86, size.height * .34)
      ..lineTo(size.width, size.height * .24);

    final vibrationPath = Path()
      ..moveTo(0, size.height * .77)
      ..lineTo(size.width * .14, size.height * .7)
      ..lineTo(size.width * .28, size.height * .74)
      ..lineTo(size.width * .42, size.height * .62)
      ..lineTo(size.width * .57, size.height * .66)
      ..lineTo(size.width * .72, size.height * .58)
      ..lineTo(size.width * .86, size.height * .61)
      ..lineTo(size.width, size.height * .52);

    canvas.drawPath(healthPath, healthPaint);

    canvas.drawPath(vibrationPath, vibrationPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _MachineStatusStyle {
  final String label;
  final Color color;

  const _MachineStatusStyle({required this.label, required this.color});
}

class _TimelineEventTheme {
  final IconData icon;
  final Color nodeBgColor;
  final Color nodeBorderColor;
  final Color nodeIconColor;

  const _TimelineEventTheme({
    required this.icon,
    required this.nodeBgColor,
    required this.nodeBorderColor,
    required this.nodeIconColor,
  });
}
