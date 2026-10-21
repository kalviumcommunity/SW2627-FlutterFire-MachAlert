import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/machine_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/machine_provider.dart';
import '../../services/machine_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';

class MachineDetailsScreen extends StatefulWidget {
  final MachineModel machine;
  final bool canManage;

  const MachineDetailsScreen({
    super.key,
    required this.machine,
    this.canManage = false,
  });

  @override
  State<MachineDetailsScreen> createState() => _MachineDetailsScreenState();
}

class _MachineDetailsScreenState extends State<MachineDetailsScreen> {
  int _selectedTab = 0;
  MachineModel? _localMachine;

  MachineModel get machine {
    try {
      final provider = Provider.of<MachineProvider>(context, listen: false);
      if (provider.selectedMachine?.id == widget.machine.id) {
        return provider.selectedMachine!;
      }
      final match = provider.getMachineById(widget.machine.id);
      if (match != null) return match;
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
    if (!canManage || !_resolveCanManage(context)) return;

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
    if (!canManage || !_resolveCanManage(context)) return;

    await Navigator.of(context).push<void>(
      AppRoutes.editMachine(machine),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showDeleteConfirmation(bool canManage) async {
    if (!canManage || !_resolveCanManage(context)) return;

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
        SnackBar(
          content: Text('Failed to delete machine: $message'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _resolveCanManage(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          machine.id,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Manage machine',
              onSelected: (action) => _handleManagementAction(action, canManage),
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
                        Icon(Icons.delete_outline),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMachineHeader(),

              const SizedBox(height: 24),

              _buildTabs(),

              const SizedBox(height: 20),

              _buildSelectedTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMachineHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            Icons.precision_manufacturing,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),

        const SizedBox(width: 18),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                machine.id,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 4),

              Text(machine.name, style: Theme.of(context).textTheme.bodyLarge),

              if (machine.productionLine.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  machine.productionLine,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],

              const SizedBox(height: 10),

              _buildStatusChip(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    final style = _statusStyle(machine.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: style.color,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 6),

          Text(
            style.label,
            style: TextStyle(color: style.color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const labels = ['Overview', 'Logs', 'Trend'];

    return Row(
      children: List.generate(labels.length, (index) {
        final selected = _selectedTab == index;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedTab = index;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
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
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _MetricCard(
                label: 'Total Breakdowns',
                value: '--',
                icon: Icons.warning_amber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Health Score',
                value: '${machine.healthScore.toStringAsFixed(0)}%',
                icon: Icons.favorite_outline,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _MetricCard(
                label: 'Temperature',
                value: machine.temperature == null
                    ? '--'
                    : '${machine.temperature!.toStringAsFixed(1)}°C',
                icon: Icons.thermostat,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _MetricCard(
          label: 'Vibration',
          value: machine.vibration == null
              ? '--'
              : machine.vibration!.toStringAsFixed(1),
          icon: Icons.vibration,
        ),

        const SizedBox(height: 24),

        Text(
          'Inspection Information',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        _InformationTile(
          icon: Icons.event_available,
          title: 'Last Inspection',
          value: _formatDateTime(machine.lastInspection),
        ),

        _InformationTile(
          icon: Icons.tag,
          title: 'Model Number',
          value: machine.modelNumber?.isNotEmpty == true
              ? machine.modelNumber!
              : '--',
        ),

        const SizedBox(height: 24),

        _buildRecentLogsPreview(),
      ],
    );
  }

  Widget _buildRecentLogsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Logs',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

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
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Text(
                    'Machine activity logs will appear here once available.',
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
    return const _PlaceholderSection(
      icon: Icons.receipt_long_outlined,
      title: 'Machine Logs',
      description: 'Inspection and breakdown logs will appear here once connected to Firestore.',
    );
  }

  Widget _buildTrendTab() {
    return const _PlaceholderSection(
      icon: Icons.show_chart,
      title: 'Machine Trend',
      description: 'Machine health and sensor trends will appear here in a later analytics task.',
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
      return const _MachineStatusStyle(label: 'Running', color: Colors.green);
    }

    if (normalized.contains('maintenance') || normalized == 'warning') {
      return const _MachineStatusStyle(
        label: 'Under Maintenance',
        color: Colors.orange,
      );
    }

    if (normalized == 'critical' || normalized == 'breakdown') {
      return const _MachineStatusStyle(label: 'Breakdown', color: Colors.red);
    }

    return const _MachineStatusStyle(label: 'Unknown', color: Colors.grey);
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),

            const SizedBox(height: 12),

            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(label, style: Theme.of(context).textTheme.bodySmall),
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
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PlaceholderSection({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),

          const SizedBox(height: 16),

          Text(title, style: Theme.of(context).textTheme.titleLarge),

          const SizedBox(height: 8),

          Text(description, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MachineStatusStyle {
  final String label;
  final Color color;

  const _MachineStatusStyle({required this.label, required this.color});
}
