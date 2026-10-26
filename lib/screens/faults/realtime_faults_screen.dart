import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/fault_model.dart';

class RealtimeFaultsScreen extends StatelessWidget {
  final Stream<List<FaultModel>>? faultStream;

  const RealtimeFaultsScreen({super.key, this.faultStream});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Faults',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: faultStream == null
            ? _buildDisconnectedState(context)
            : StreamBuilder<List<FaultModel>>(
                stream: faultStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(context);
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final faults = [...?snapshot.data];

                  faults.sort((a, b) {
                    final aDate = a.createdAt;
                    final bDate = b.createdAt;

                    if (aDate == null && bDate == null) {
                      return 0;
                    }

                    if (aDate == null) {
                      return 1;
                    }

                    if (bDate == null) {
                      return -1;
                    }

                    return bDate.compareTo(aDate);
                  });

                  if (faults.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return _buildFaultList(context, faults);
                },
              ),
      ),
    );
  }

  Widget _buildFaultList(BuildContext context, List<FaultModel> faults) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${faults.length} live '
                  '${faults.length == 1 ? 'fault' : 'faults'}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Text(
                'Updates automatically',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            itemCount: faults.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _RealtimeFaultCard(fault: faults[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 18),
            Text(
              'No active faults',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'New fault reports will appear here automatically.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load live faults',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'The real-time connection encountered an error.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 18),
            Text(
              'Live fault monitoring',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time fault updates will appear here once the live data connection is integrated.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RealtimeFaultCard extends StatelessWidget {
  final FaultModel fault;

  const _RealtimeFaultCard({required this.fault});

  @override
  Widget build(BuildContext context) {
    final machineName = fault.machineName?.trim().isNotEmpty == true
        ? fault.machineName!.trim()
        : fault.machineId.trim().isNotEmpty
        ? fault.machineId.trim()
        : 'Unknown Machine';

    final severityColor = _severityColor(fault.severity);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.report_problem_outlined,
                    color: severityColor,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machineName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      if (fault.machineId.trim().isNotEmpty)
                        Text(
                          fault.machineId,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),

                _StatusBadge(status: fault.status),
              ],
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoBadge(
                  icon: _faultTypeIcon(fault.type),
                  label: fault.type.trim().isEmpty ? 'Other' : fault.type,
                ),
                _SeverityBadge(severity: fault.severity),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              fault.description.trim().isEmpty
                  ? 'No description provided.'
                  : fault.description,
            ),

            const SizedBox(height: 12),

            const Divider(height: 1),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDate(fault.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (fault.reportedByName?.trim().isNotEmpty == true)
                  Text(
                    'By ${fault.reportedByName}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _severityColor(String severity) {
    switch (severity.trim().toLowerCase()) {
      case 'low':
        return Colors.green;

      case 'medium':
        return Colors.orange;

      case 'high':
        return Colors.deepOrange;

      case 'critical':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  static IconData _faultTypeIcon(String type) {
    switch (type.trim().toLowerCase()) {
      case 'mechanical':
        return Icons.build_outlined;

      case 'electrical':
        return Icons.bolt_outlined;

      case 'hydraulic':
        return Icons.water_drop_outlined;

      case 'thermal':
        return Icons.thermostat_outlined;

      case 'pneumatic':
        return Icons.air_outlined;

      default:
        return Icons.warning_amber;
    }
  }

  static String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Just now';
    }

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month • $hour:$minute';
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;

  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = _RealtimeFaultCard._severityColor(severity);

    final label = severity.trim().isEmpty ? 'Unknown' : severity.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();

    Color color;

    switch (normalized) {
      case 'resolved':
        color = Colors.green;
        break;

      case 'in progress':
        color = Colors.orange;
        break;

      case 'open':
        color = Colors.red;
        break;

      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.trim().isEmpty ? 'Open' : status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
