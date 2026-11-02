import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/maintenance_model.dart';
import '../../services/maintenance_service.dart';
import 'maintenance_details_screen.dart';
import 'maintenance_task_form_screen.dart';

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

  Stream<List<MaintenanceModel>>? _stream;
  MaintenanceService? _resolvedService;
  bool _initialized = false;

  static final List<MaintenanceModel> _sampleTasks = [
    MaintenanceModel(
      id: 'MNT-001',
      machineId: 'CNC Milling Unit 01',
      machineName: 'CNC Milling Unit 01',
      technicianId: 'Technician Team',
      technicianName: 'Technician Team',
      priority: 'High',
      status: 'Pending',
      notes: 'Inspect spindle vibration',
      createdAt: DateTime.now(),
    ),
    MaintenanceModel(
      id: 'MNT-002',
      machineId: 'Hydraulic Press 02',
      machineName: 'Hydraulic Press 02',
      technicianId: 'Technician Team',
      technicianName: 'Technician Team',
      priority: 'Critical',
      status: 'In Progress',
      notes: 'Check hydraulic pressure',
      createdAt: DateTime.now(),
    ),
    MaintenanceModel(
      id: 'MNT-003',
      machineId: 'Assembly Conveyor 04',
      machineName: 'Assembly Conveyor 04',
      technicianId: 'Technician Team',
      technicianName: 'Technician Team',
      priority: 'Medium',
      status: 'Resolved',
      notes: 'Lubricate conveyor bearings',
      createdAt: DateTime.now(),
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
          isTechnician ? 'Assigned Maintenance' : 'Maintenance',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              key: const ValueKey('create-maintenance-task-fab'),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => MaintenanceTaskFormScreen(
                      maintenanceService: _resolvedService,
                    ),
                  ),
                );
                if (result == true && mounted) {
                  _retry();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Task'),
            )
          : null,
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
                        ),
                ),
              ],
            );
          },
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
            isTechnician
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
                _initStream();
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    final message = error is MaintenanceServiceException
        ? error.message
        : 'Failed to load maintenance tasks. Please check your connection.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load maintenance tasks',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isTechnician) {
    final hasFilter = _selectedStatus != 'All';

    final String title;
    final String subtitle;
    final IconData icon;

    if (hasFilter) {
      title = 'No maintenance tasks found';
      subtitle = 'Try another status filter.';
      icon = Icons.filter_list_off;
    } else if (isTechnician) {
      title = 'No assigned maintenance tasks';
      subtitle = 'You have no maintenance tasks assigned.';
      icon = Icons.assignment_turned_in_outlined;
    } else {
      title = 'No maintenance tasks found';
      subtitle = 'There are currently no maintenance tasks recorded.';
      icon = Icons.build_circle_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceModel item;
  final VoidCallback onTap;

  const _MaintenanceCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(item.priority);

    final title = item.notes?.trim().isNotEmpty == true
        ? item.notes!.trim()
        : 'Maintenance Task #${item.id}';

    final machineName = item.machineName?.trim().isNotEmpty == true
        ? item.machineName!.trim()
        : (item.machineId.isNotEmpty ? item.machineId : 'Machine');

    final technician = item.technicianName?.trim().isNotEmpty == true
        ? item.technicianName!.trim()
        : (item.technicianId.isNotEmpty ? item.technicianId : 'Technician');

    final dateText = item.createdAt != null
        ? 'Assigned: ${item.createdAt!.year}-${item.createdAt!.month.toString().padLeft(2, '0')}-${item.createdAt!.day.toString().padLeft(2, '0')}'
        : 'Assigned: Today';

    final displayStatus = item.status == 'Resolved' ? 'Completed' : item.status;

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
                      title,
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
                text: machineName,
              ),
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.person_outline, text: technician),
              const SizedBox(height: 6),
              _InfoRow(icon: Icons.event_outlined, text: dateText),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusBadge(status: displayStatus),
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
