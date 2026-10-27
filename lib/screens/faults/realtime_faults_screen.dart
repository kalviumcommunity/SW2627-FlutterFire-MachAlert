import 'package:flutter/material.dart';

import '../../models/fault_model.dart';
import '../../utils/app_constants.dart';

class RealtimeFaultsScreen extends StatefulWidget {
  final Stream<List<FaultModel>>? faultStream;

  const RealtimeFaultsScreen({super.key, this.faultStream});

  @override
  State<RealtimeFaultsScreen> createState() => _RealtimeFaultsScreenState();
}

class _RealtimeFaultsScreenState extends State<RealtimeFaultsScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedSeverity;
  String? _selectedStatus;

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedSeverity != null ||
      _selectedStatus != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
      _selectedSeverity = null;
      _selectedStatus = null;
    });
  }

  List<FaultModel> _filterFaults(List<FaultModel> faults) {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = faults.where((fault) {
      final matchesSearch =
          query.isEmpty ||
          fault.machineId.toLowerCase().contains(query) ||
          (fault.machineName ?? '').toLowerCase().contains(query) ||
          fault.type.toLowerCase().contains(query) ||
          fault.description.toLowerCase().contains(query) ||
          (fault.reportedByName ?? '').toLowerCase().contains(query);

      final matchesSeverity =
          _selectedSeverity == null ||
          fault.severity.trim().toLowerCase() ==
              _selectedSeverity!.toLowerCase();

      final matchesStatus =
          _selectedStatus == null ||
          fault.status.trim().toLowerCase() == _selectedStatus!.toLowerCase();

      return matchesSearch && matchesSeverity && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
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

    return filtered;
  }

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
        child: widget.faultStream == null
            ? _buildDisconnectedState(context)
            : StreamBuilder<List<FaultModel>>(
                stream: widget.faultStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(context);
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allFaults = [...?snapshot.data];

                  if (allFaults.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final filteredFaults = _filterFaults(allFaults);

                  return _buildFaultContent(
                    context,
                    allFaults: allFaults,
                    filteredFaults: filteredFaults,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildFaultContent(
    BuildContext context, {
    required List<FaultModel> allFaults,
    required List<FaultModel> filteredFaults,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchField(),

        _buildFilterSection(),

        _buildSummary(
          context,
          visibleCount: filteredFaults.length,
          totalCount: allFaults.length,
        ),

        if (filteredFaults.isEmpty)
          Expanded(child: _buildNoMatchesState(context))
        else
          Expanded(
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: filteredFaults.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _RealtimeFaultCard(fault: filteredFaults[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search faults...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.close),
                )
              : null,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All'),
                ),
            ],
          ),

          const SizedBox(height: 4),

          Text('Severity', style: Theme.of(context).textTheme.bodySmall),

          const SizedBox(height: 6),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedSeverity == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedSeverity = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...AppConstants.severities.map((severity) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(severity),
                      selected: _selectedSeverity == severity,
                      onSelected: (_) {
                        setState(() {
                          _selectedSeverity = severity;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Text('Status', style: Theme.of(context).textTheme.bodySmall),

          const SizedBox(height: 6),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _selectedStatus == null,
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...AppConstants.faultStatuses.map((status) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: _selectedStatus == status,
                      onSelected: (_) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context, {
    required int visibleCount,
    required int totalCount,
  }) {
    final message = _hasActiveFilters
        ? '$visibleCount of $totalCount faults shown'
        : '$totalCount live '
              '${totalCount == 1 ? 'fault' : 'faults'}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (!_hasActiveFilters)
            const Text('Updates automatically', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildNoMatchesState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 56,
                      color: Theme.of(context).colorScheme.outline,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'No matching faults',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Try changing your search or filters.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
