import 'package:flutter/material.dart';

import '../../models/fault_model.dart';
import '../../services/fault_service.dart';
import '../../utils/app_constants.dart';
import '../../widgets/app_state_view.dart';

/// Screen displaying the history of reported faults.
class FaultHistoryScreen extends StatefulWidget {
  final FaultService? faultService;
  final String? machineId;

  const FaultHistoryScreen({super.key, this.faultService, this.machineId});

  @override
  State<FaultHistoryScreen> createState() => _FaultHistoryScreenState();
}

class _FaultHistoryScreenState extends State<FaultHistoryScreen> {
  List<FaultModel> _faults = [];

  bool _isLoading = true;

  String? _errorMessage;

  FaultService get _effectiveFaultService =>
      widget.faultService ?? FaultService();

  @override
  void initState() {
    super.initState();

    _fetchFaults();
  }

  Future<void> _fetchFaults({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await _effectiveFaultService.getFaults(
        machineId: widget.machineId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _faults = results;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = e is FaultServiceException
          ? e.message
          : 'Unable to retrieve fault history.';

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() {
    return _fetchFaults(showLoadingIndicator: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fault History')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppStateView.loading(
        title: 'Loading fault history...',
        message: 'Retrieving reported machine faults.',
      );
    }

    if (_errorMessage != null && _faults.isEmpty) {
      return _buildErrorState(_errorMessage!);
    }

    if (_faults.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _faults.length,
        itemBuilder: (context, index) {
          final fault = _faults[index];

          return _buildFaultCard(fault);
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: AppStateView.error(
                title: 'Unable to load fault history',
                message: message,
                actionLabel: 'Retry',
                onAction: () {
                  _fetchFaults();
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const AppStateView.empty(
                icon: Icons.assignment_turned_in_outlined,
                title: 'No faults found',
                message: 'No fault reports have been recorded yet.',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFaultCard(FaultModel fault) {
    final hasMachineName =
        fault.machineName != null && fault.machineName!.trim().isNotEmpty;

    final machineDisplayName = hasMachineName
        ? fault.machineName!.trim()
        : fault.machineId.trim().isNotEmpty
        ? fault.machineId.trim()
        : 'Unknown Machine';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        machineDisplayName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),

                      if (hasMachineName &&
                          fault.machineId.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),

                        Text(
                          'Machine ID: ${fault.machineId.trim()}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                _buildStatusBadge(fault.status),
              ],
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildTypeBadge(fault.type),
                _buildSeverityBadge(fault.severity),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              fault.description.trim().isNotEmpty
                  ? fault.description
                  : 'No description provided',
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            const SizedBox(height: 12),

            const Divider(height: 1),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),

                const SizedBox(width: 4),

                Expanded(
                  child: Text(
                    _formatDate(fault.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),

                if (fault.reportedByName != null &&
                    fault.reportedByName!.trim().isNotEmpty) ...[
                  Text(
                    'By ${fault.reportedByName!.trim()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ] else if (fault.reportedBy.trim().isNotEmpty) ...[
                  Text(
                    'By ${fault.reportedBy.trim()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],

                if (fault.imageUrl != null &&
                    fault.imageUrl!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),

                  Icon(
                    Icons.image_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final displayType = type.trim().isNotEmpty ? type.trim() : 'Other';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getFaultTypeIcon(displayType),
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),

          const SizedBox(width: 4),

          Text(
            displayType,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFaultTypeIcon(String type) {
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
        return Icons.warning_amber_rounded;
    }
  }

  Widget _buildSeverityBadge(String severity) {
    final normalized = severity.trim();

    final color = _getSeverityColor(normalized);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = color.withValues(alpha: isDark ? 0.25 : 0.12);

    final textColor = isDark
        ? color
        : _getAccessibleSeverityTextColor(normalized, color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
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
            normalized.isNotEmpty ? normalized : 'Unknown',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
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

  Color _getAccessibleSeverityTextColor(String severity, Color fallback) {
    switch (severity.trim().toLowerCase()) {
      case 'low':
        return const Color(0xFF1B5E20);

      case 'medium':
        return const Color(0xFFE65100);

      case 'high':
        return const Color(0xFFBF360C);

      case 'critical':
        return const Color(0xFFB71C1C);

      default:
        return fallback;
    }
  }

  Widget _buildStatusBadge(String status) {
    final normalized = status.trim();

    final color = _getStatusColor(normalized);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = color.withValues(alpha: isDark ? 0.25 : 0.12);

    final textColor = isDark
        ? color
        : _getAccessibleStatusTextColor(normalized, color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        normalized.isNotEmpty ? normalized : AppConstants.faultStatusOpen,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'open':
        return Colors.blue;

      case 'in progress':
        return Colors.amber.shade800;

      case 'resolved':
        return Colors.teal;

      default:
        return Colors.grey;
    }
  }

  Color _getAccessibleStatusTextColor(String status, Color fallback) {
    switch (status.trim().toLowerCase()) {
      case 'open':
        return const Color(0xFF0D47A1);

      case 'in progress':
        return const Color(0xFFE65100);

      case 'resolved':
        return const Color(0xFF004D40);

      default:
        return fallback;
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Date unavailable';
    }

    try {
      final local = dateTime.toLocal();

      final day = local.day.toString().padLeft(2, '0');

      final month = local.month.toString().padLeft(2, '0');

      final year = local.year;

      final hour = local.hour.toString().padLeft(2, '0');

      final minute = local.minute.toString().padLeft(2, '0');

      return '$day/$month/$year • $hour:$minute';
    } catch (_) {
      return 'Date unavailable';
    }
  }
}
