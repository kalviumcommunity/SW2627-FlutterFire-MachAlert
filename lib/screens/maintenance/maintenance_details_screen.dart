import 'package:flutter/material.dart';

typedef MaintenanceStatusUpdateCallback = Future<void> Function(
  String status,
  String notes,
);

class MaintenanceDetailsScreen extends StatefulWidget {
  final String maintenanceId;
  final String title;
  final String machineName;
  final String technician;
  final String priority;
  final String status;
  final String dueDate;
  final String? dateLabel;
  final String? notes;

  /// Optional callback for Day 18/Member 3 backend integration.
  final MaintenanceStatusUpdateCallback? onStatusUpdate;

  const MaintenanceDetailsScreen({
    super.key,
    required this.maintenanceId,
    required this.title,
    required this.machineName,
    required this.technician,
    required this.priority,
    required this.status,
    required this.dueDate,
    this.dateLabel,
    this.notes,
    this.onStatusUpdate,
  });

  @override
  State<MaintenanceDetailsScreen> createState() =>
      _MaintenanceDetailsScreenState();
}

class _MaintenanceDetailsScreenState extends State<MaintenanceDetailsScreen> {
  static const List<String> _statuses = ['Pending', 'In Progress', 'Completed'];

  late String _currentStatus;

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();

    _currentStatus = _statuses.contains(widget.status)
        ? widget.status
        : 'Pending';
  }

  Future<void> _openStatusUpdateSheet() async {
    if (_isUpdating) {
      return;
    }

    final result = await showModalBottomSheet<_StatusUpdateResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return _StatusUpdateSheet(currentStatus: _currentStatus);
      },
    );

    if (result == null || !mounted) {
      return;
    }

    await _updateStatus(result.status, result.notes);
  }

  Future<void> _updateStatus(String status, String notes) async {
    if (_isUpdating) {
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      if (widget.onStatusUpdate != null) {
        await widget.onStatusUpdate!(status, notes);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _currentStatus = status;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maintenance status updated to $status.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to update maintenance status. Please try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Maintenance Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),

              const SizedBox(height: 20),

              _buildInformationCard(),

              const SizedBox(height: 20),

              _buildDescriptionCard(),

              const SizedBox(height: 20),

              _buildTimelineCard(),

              const SizedBox(height: 24),

              FilledButton.icon(
                key: const ValueKey('update-maintenance-status-button'),
                onPressed: _isUpdating ? null : _openStatusUpdateSheet,
                icon: _isUpdating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_outlined),
                label: Text(
                  _isUpdating ? 'Updating...' : 'Update Maintenance Status',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.engineering_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 4),

                      Text(widget.maintenanceId),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(widget.priority),
                ),

                _MaintenanceStatusChip(status: _currentStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _DetailsRow(
              icon: Icons.precision_manufacturing_outlined,
              label: 'Machine',
              value: widget.machineName,
            ),

            const Divider(height: 24),

            _DetailsRow(
              icon: Icons.person_outline,
              label: 'Assigned To',
              value: widget.technician,
            ),

            const Divider(height: 24),

            _DetailsRow(
              icon: Icons.event_outlined,
              label: widget.dateLabel ?? 'Due',
              value: widget.dueDate,
            ),

            const Divider(height: 24),

            _DetailsRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: _currentStatus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance Notes',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              widget.notes?.trim().isNotEmpty == true ? widget.notes!.trim() : 'Inspect the reported machine issue, document findings, and complete the required maintenance checks.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            const _TimelineItem(
              icon: Icons.add_task,
              title: 'Maintenance task created',
              subtitle: 'Task added to maintenance queue',
            ),

            const SizedBox(height: 14),

            const _TimelineItem(
              icon: Icons.assignment_ind_outlined,
              title: 'Technician assigned',
              subtitle: 'Task assigned for maintenance',
            ),

            if (_currentStatus == 'In Progress' ||
                _currentStatus == 'Completed') ...[
              const SizedBox(height: 14),

              const _TimelineItem(
                icon: Icons.engineering_outlined,
                title: 'Maintenance started',
                subtitle: 'Technician started working on the task',
              ),
            ],

            if (_currentStatus == 'Completed') ...[
              const SizedBox(height: 14),

              const _TimelineItem(
                icon: Icons.check_circle_outline,
                title: 'Maintenance completed',
                subtitle: 'Maintenance work marked as completed',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusUpdateSheet extends StatefulWidget {
  final String currentStatus;

  const _StatusUpdateSheet({required this.currentStatus});

  @override
  State<_StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<_StatusUpdateSheet> {
  static const List<String> _statuses = ['Pending', 'In Progress', 'Completed'];

  late String _selectedStatus;

  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _selectedStatus = widget.currentStatus;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      _StatusUpdateResult(
        status: _selectedStatus,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + keyboardInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Update Maintenance Status',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Select the current maintenance progress.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),

            Text(
              'Status',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statuses.map((status) {
                return ChoiceChip(
                  label: Text(status),
                  selected: _selectedStatus == status,
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            TextField(
              key: const ValueKey('maintenance-update-notes'),
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Update Notes',
                hintText: 'Add maintenance notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              key: const ValueKey('save-maintenance-status'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Status'),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusUpdateResult {
  final String status;
  final String notes;

  const _StatusUpdateResult({required this.status, required this.notes});
}

class _MaintenanceStatusChip extends StatelessWidget {
  final String status;

  const _MaintenanceStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Completed' => Colors.green,
      'In Progress' => Colors.blue,
      _ => Colors.orange,
    };

    return Chip(
      avatar: Icon(_statusIcon(status), size: 18, color: color),
      label: Text(status),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle_outline;

      case 'In Progress':
        return Icons.engineering_outlined;

      default:
        return Icons.schedule_outlined;
    }
  }
}

class _DetailsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailsRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),

              const SizedBox(height: 2),

              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 18, child: Icon(icon, size: 18)),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

              const SizedBox(height: 3),

              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
