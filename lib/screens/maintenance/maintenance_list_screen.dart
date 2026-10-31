import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_model.dart';
import '../../services/maintenance_service.dart';
import 'maintenance_details_screen.dart';

class MaintenanceListScreen extends StatefulWidget {
  final bool assignedOnly;
  final MaintenanceService? maintenanceService;

  const MaintenanceListScreen({
    super.key,
    this.assignedOnly = false,
    this.maintenanceService,
  });

  @override
  State<MaintenanceListScreen> createState() => _MaintenanceListScreenState();
}

class _MaintenanceListScreenState extends State<MaintenanceListScreen> {
  String _selectedStatus = 'All';

  static const _statuses = ['All', 'Pending', 'In Progress', 'Completed'];

  final List<_MaintenancePreview> _items = const [
    _MaintenancePreview(
      id: 'MNT-001',
      title: 'Inspect spindle vibration',
      machineName: 'CNC Milling Unit 01',
      technician: 'Technician Team',
      priority: 'High',
      status: 'Pending',
      dueDate: 'Today',
    ),
    _MaintenancePreview(
      id: 'MNT-002',
      title: 'Check hydraulic pressure',
      machineName: 'Hydraulic Press 02',
      technician: 'Technician Team',
      priority: 'Critical',
      status: 'In Progress',
      dueDate: 'Today',
    ),
    _MaintenancePreview(
      id: 'MNT-003',
      title: 'Lubricate conveyor bearings',
      machineName: 'Assembly Conveyor 04',
      technician: 'Technician Team',
      priority: 'Medium',
      status: 'Completed',
      dueDate: 'Yesterday',
    ),
  ];

  MaintenanceService? get _resolvedService {
    if (widget.maintenanceService != null) {
      return widget.maintenanceService;
    }
    try {
      return Provider.of<MaintenanceService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  Stream<List<MaintenanceModel>> _taskStream(MaintenanceService service) {
    if (widget.assignedOnly) {
      return service.streamAssignedMaintenanceTasks();
    }
    return service.streamMaintenanceTasks();
  }

  @override
  Widget build(BuildContext context) {
    final service = _resolvedService;

    if (service != null) {
      return StreamBuilder<List<MaintenanceModel>>(
        stream: _taskStream(service),
        builder: (context, snapshot) {
          final items = (snapshot.data ?? const <MaintenanceModel>[])
              .map(
                (task) => _MaintenancePreview(
                  id: task.id,
                  title: (task.notes?.trim().isNotEmpty == true)
                      ? task.notes!.trim()
                      : 'Maintenance Task #${task.id}',
                  machineName: (task.machineName?.trim().isNotEmpty == true)
                      ? task.machineName!.trim()
                      : task.machineId,
                  technician: (task.technicianName?.trim().isNotEmpty == true)
                      ? task.technicianName!.trim()
                      : task.technicianId,
                  priority: task.priority,
                  status: task.status == 'Resolved' ? 'Completed' : task.status,
                  dueDate: task.createdAt != null
                      ? '${task.createdAt!.year}-${task.createdAt!.month.toString().padLeft(2, '0')}-${task.createdAt!.day.toString().padLeft(2, '0')}'
                      : 'Today',
                ),
              )
              .toList();

          return _buildContent(context, items, service);
        },
      );
    }

    return _buildContent(context, _items, null);
  }

  Widget _buildContent(
    BuildContext context,
    List<_MaintenancePreview> allItems,
    MaintenanceService? service,
  ) {
    final filtered = _selectedStatus == 'All'
        ? allItems
        : allItems.where((item) => item.status == _selectedStatus).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assignedOnly ? 'Assigned Maintenance' : 'Maintenance',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(allItems),

            _buildFilters(),

            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        return _MaintenanceCard(
                          item: item,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => MaintenanceDetailsScreen(
                                  maintenanceId: item.id,
                                  title: item.title,
                                  machineName: item.machineName,
                                  technician: item.technician,
                                  priority: item.priority,
                                  status: item.status,
                                  dueDate: item.dueDate,
                                  maintenanceService: service,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<_MaintenancePreview> items) {
    final pendingCount = items.where((item) => item.status == 'Pending').length;

    final inProgressCount = items
        .where((item) => item.status == 'In Progress')
        .length;

    final completedCount = items
        .where(
          (item) => item.status == 'Completed' || item.status == 'Resolved',
        )
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.assignedOnly
                ? 'Your assigned maintenance work'
                : 'Track machine maintenance activity',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Pending',
                  value: pendingCount.toString(),
                  icon: Icons.schedule_outlined,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _SummaryCard(
                  label: 'Active',
                  value: inProgressCount.toString(),
                  icon: Icons.engineering_outlined,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _SummaryCard(
                  label: 'Done',
                  value: completedCount.toString(),
                  icon: Icons.check_circle_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final status = _statuses[index];

          return ChoiceChip(
            label: Text(status),
            selected: _selectedStatus == status,
            onSelected: (_) {
              setState(() {
                _selectedStatus = status;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined, size: 64),
            SizedBox(height: 12),
            Text(
              'No maintenance tasks found',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text('Try another status filter.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final _MaintenancePreview item;
  final VoidCallback onTap;

  const _MaintenanceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(item.priority);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.priority,
                      style: TextStyle(
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              _InfoRow(
                icon: Icons.precision_manufacturing_outlined,
                text: item.machineName,
              ),

              const SizedBox(height: 6),

              _InfoRow(icon: Icons.person_outline, text: item.technician),

              const SizedBox(height: 6),

              _InfoRow(
                icon: Icons.event_outlined,
                text: 'Due: ${item.dueDate}',
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _StatusBadge(status: item.status),

                  const Spacer(),

                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Critical':
        return Colors.red;

      case 'High':
        return Colors.deepOrange;

      case 'Medium':
        return Colors.orange;

      default:
        return Colors.green;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Completed' || 'Resolved' => Colors.green,
      'In Progress' => Colors.blue,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MaintenancePreview {
  final String id;
  final String title;
  final String machineName;
  final String technician;
  final String priority;
  final String status;
  final String dueDate;

  const _MaintenancePreview({
    required this.id,
    required this.title,
    required this.machineName,
    required this.technician,
    required this.priority,
    required this.status,
    required this.dueDate,
  });
}
