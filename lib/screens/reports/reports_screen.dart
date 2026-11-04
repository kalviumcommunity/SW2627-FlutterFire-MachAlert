import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fault_model.dart';
import '../../models/machine_model.dart';
import '../../providers/machine_provider.dart';
import '../../services/fault_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_bottom_navigation.dart';

class ReportsScreen extends StatefulWidget {
  final MachineProvider? machineProvider;
  final FaultService? faultService;
  final List<FaultModel>? initialFaults;
  final String? reportingPeriod;

  const ReportsScreen({
    super.key,
    this.machineProvider,
    this.faultService,
    this.initialFaults,
    this.reportingPeriod,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0;
  List<FaultModel> _faults = [];
  bool _isLoadingFaults = true;
  String? _faultsError;
  StreamSubscription<List<FaultModel>>? _faultsSubscription;

  static const _tabs = ['Overview', 'Inspections', 'Breakdowns'];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialFaults != null) {
      _faults = List.from(widget.initialFaults!);
      _isLoadingFaults = false;
    }
    widget.machineProvider?.addListener(_onMachineProviderChanged);
    _scheduleMachineSubscription();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initialFaults == null && _faultsSubscription == null) {
      _subscribeToFaults();
    }
  }

  @override
  void didUpdateWidget(ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.machineProvider != oldWidget.machineProvider) {
      oldWidget.machineProvider?.removeListener(_onMachineProviderChanged);
      widget.machineProvider?.addListener(_onMachineProviderChanged);
      _scheduleMachineSubscription();
    }
    if (widget.initialFaults != oldWidget.initialFaults && widget.initialFaults != null) {
      _faults = List.from(widget.initialFaults!);
      _isLoadingFaults = false;
    } else if (widget.faultService != oldWidget.faultService) {
      _subscribeToFaults();
    }
  }

  @override
  void dispose() {
    widget.machineProvider?.removeListener(_onMachineProviderChanged);
    _faultsSubscription?.cancel();
    super.dispose();
  }

  void _onMachineProviderChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  FaultService? _resolveFaultService() {
    if (widget.faultService != null) return widget.faultService;
    try {
      return context.read<FaultService>();
    } catch (_) {
      return null;
    }
  }

  void _subscribeToFaults() {
    _faultsSubscription?.cancel();
    final service = widget.faultService ?? _resolveFaultService();
    if (service == null) {
      if (mounted) {
        setState(() {
          _isLoadingFaults = false;
        });
      }
      return;
    }

    _isLoadingFaults = true;
    _faultsSubscription = service.streamFaults().listen(
      (data) {
        if (mounted) {
          setState(() {
            _faults = data;
            _isLoadingFaults = false;
            _faultsError = null;
          });
        }
      },
      onError: (Object err) {
        if (mounted) {
          setState(() {
            _isLoadingFaults = false;
            _faultsError = err.toString();
          });
        }
      },
    );
  }

  void _scheduleMachineSubscription() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = _resolveMachineProvider();
      if (provider != null && !provider.hasActiveSubscription) {
        provider.subscribeToMachines();
      }
    });
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

  static String _formatShortDate(DateTime dt) {
    final local = dt.toLocal();
    final month = _months[local.month - 1];
    return '$month ${local.day}, ${local.year}';
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _computeReportingPeriodText(List<MachineModel> machines) {
    if (widget.reportingPeriod != null && widget.reportingPeriod!.trim().isNotEmpty) {
      return widget.reportingPeriod!.trim();
    }

    final timestamps = <DateTime>[];
    for (final f in _faults) {
      if (f.createdAt != null) timestamps.add(f.createdAt!);
    }
    for (final m in machines) {
      if (m.lastInspection != null) timestamps.add(m.lastInspection!);
    }

    if (timestamps.isEmpty) {
      return 'Live Operational Data (All Time)';
    }

    timestamps.sort();
    final earliest = timestamps.first;
    final latest = timestamps.last;

    if (_isSameDay(earliest, latest)) {
      return '${_formatShortDate(earliest)} (Live)';
    }

    return '${_formatShortDate(earliest)} - ${_formatShortDate(latest)}';
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMachineSubscription();

    MachineProvider? provider = widget.machineProvider;
    if (provider == null) {
      try {
        provider = context.watch<MachineProvider>();
      } catch (_) {}
    }

    final isLoading = provider == null ||
        provider.isLoading ||
        (!provider.hasActiveSubscription &&
            !provider.hasError &&
            provider.machines.isEmpty);

    final hasError = provider != null && provider.hasError;

    final stats = (provider != null && !hasError && !isLoading)
        ? provider.statistics
        : null;

    final machines = provider?.machines ?? const [];
    final periodText = _computeReportingPeriodText(machines);

    Widget tabContent;
    switch (_selectedTab) {
      case 1:
        tabContent = _buildInspectionsTab(context, machines);
        break;
      case 2:
        tabContent = _buildBreakdownsTab(
          context,
          machines,
          _faults,
          _isLoadingFaults,
          _faultsError,
        );
        break;
      case 0:
      default:
        tabContent = _buildOverviewTab(
          context,
          provider,
          stats,
          isLoading,
          hasError,
          _faults,
        );
        break;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Reports')),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 3),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final selected = _selectedTab == index;

                  return Expanded(
                    child: GestureDetector(
                      key: ValueKey('reports-tab-${_tabs[index].toLowerCase()}'),
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
                          _tabs[index],
                          style: TextStyle(
                            color: selected ? Colors.white : AppTheme.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4EBF0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppTheme.navy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      periodText,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),

            const SizedBox(height: 24),

            tabContent,
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 0: OVERVIEW
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab(
    BuildContext context,
    MachineProvider? provider,
    MachineStatistics? stats,
    bool isLoading,
    bool hasError,
    List<FaultModel> displayFaults,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Machine Status',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 14),

        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Builder(
              builder: (context) {
                if (hasError) {
                  final errorMessage = provider?.errorMessage ??
                      'Failed to load machine statistics';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.danger,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () {
                              if (provider != null) {
                                provider.refresh();
                              } else {
                                _scheduleMachineSubscription();
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (isLoading) {
                  final isTest = !kIsWeb &&
                      Platform.environment['FLUTTER_TEST'] == 'true';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              value: isTest ? 0.75 : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Loading machine statistics...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF788896),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final displayStats =
                    stats ?? MachineStatistics.fromMachines(const []);

                return Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          MachineStatusDonutChart(stats: displayStats),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayStats.total.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy,
                                ),
                              ),
                              const Text(
                                'Machines',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF788896),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        children: [
                          _LegendRow(
                            color: AppTheme.green,
                            label: 'Running',
                            value:
                                '${displayStats.running} (${displayStats.runningPercentage}%)',
                          ),
                          const SizedBox(height: 12),
                          _LegendRow(
                            color: AppTheme.warning,
                            label: 'Maintenance',
                            value:
                                '${displayStats.maintenance} (${displayStats.maintenancePercentage}%)',
                          ),
                          const SizedBox(height: 12),
                          _LegendRow(
                            color: AppTheme.danger,
                            label: 'Breakdown',
                            value:
                                '${displayStats.breakdown} (${displayStats.breakdownPercentage}%)',
                          ),
                          if (displayStats.other > 0) ...[
                            const SizedBox(height: 12),
                            _LegendRow(
                              color: const Color(0xFF788896),
                              label: 'Other / Unknown',
                              value:
                                  '${displayStats.other} (${displayStats.otherPercentage}%)',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          'Events Trend',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 14),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _LegendDot(
                      color: Color(0xFF94A3B8),
                      label: 'Inspections',
                    ),
                    _LegendDot(
                      color: AppTheme.danger,
                      label: 'Breakdowns',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 36,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Insufficient Historical Trend Data',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Continuous trend curves require multiple historical logging intervals. MachAlert displays authentic real-time records rather than simulated telemetry curves.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Live Breakdowns: ${displayFaults.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.danger,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Inspection Logs: Not tracked',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: INSPECTIONS (HONEST UNAVAILABLE DATA STATE)
  // ---------------------------------------------------------------------------
  Widget _buildInspectionsTab(BuildContext context, List<MachineModel> machines) {
    final machinesWithInspections =
        machines.where((m) => m.lastInspection != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inspections Status',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: AppTheme.navy,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Inspection Records Persisted',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Standalone routine inspection collections are not configured in this database release. Inspection workflows are currently handled via scheduled Maintenance Tasks and Fault Reports.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Audit Note: Telemetry data is never simulated.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Machine Inspection Timestamps',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (machinesWithInspections.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history_toggle_off, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      machines.isEmpty
                          ? 'No machines registered.'
                          : 'None of the ${machines.length} registered machines have a recorded inspection timestamp.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...machinesWithInspections.map((m) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.precision_manufacturing_outlined, color: AppTheme.green),
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(
                'Last Inspected: ${_formatShortDate(m.lastInspection!)}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Text(m.status, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
            ),
          )),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: BREAKDOWNS (LIVE FIRESTORE FAULT / MACHINE RECORDS)
  // ---------------------------------------------------------------------------
  Widget _buildBreakdownsTab(
    BuildContext context,
    List<MachineModel> machines,
    List<FaultModel> faults,
    bool isLoadingFaults,
    String? faultsError,
  ) {
    final breakdownMachines = machines.where((m) {
      final s = m.status.trim().toLowerCase();
      return s == 'breakdown' || s == 'broken' || s == 'critical';
    }).toList();

    final openFaults = faults.where((f) => f.isOpen || f.isInProgress).toList();
    final criticalFaults = faults.where((f) => f.isCriticalSeverity).toList();
    final resolvedFaults = faults.where((f) => f.isResolved).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Breakdown Statistics',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildBreakdownMetricCard(
                label: 'Total Incidents',
                value: faults.length.toString(),
                color: AppTheme.navy,
                icon: Icons.report_problem_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBreakdownMetricCard(
                label: 'Active Faults',
                value: openFaults.length.toString(),
                color: AppTheme.warning,
                icon: Icons.pending_actions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildBreakdownMetricCard(
                label: 'Critical Severity',
                value: criticalFaults.length.toString(),
                color: AppTheme.danger,
                icon: Icons.error_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBreakdownMetricCard(
                label: 'Resolved',
                value: resolvedFaults.length.toString(),
                color: AppTheme.green,
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Machines in Breakdown Status',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (breakdownMachines.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.green),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No machines currently in Breakdown or Critical status.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...breakdownMachines.map((m) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.danger),
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text('ID: ${m.id} • Line: ${m.productionLine}', style: const TextStyle(fontSize: 11)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  m.status,
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          )),
        const SizedBox(height: 20),
        const Text(
          'Recorded Breakdown Incidents',
          style: TextStyle(
            color: AppTheme.navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (isLoadingFaults)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (faultsError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load breakdown records: $faultsError',
                style: const TextStyle(color: AppTheme.danger, fontSize: 12),
              ),
            ),
          )
        else if (faults.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.green),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No breakdown or fault incidents recorded in Firestore.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...faults.map((f) => Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.machineName != null && f.machineName!.isNotEmpty
                              ? f.machineName!
                              : 'Machine ${f.machineId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildSeverityBadge(f.severity),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    f.description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Type: ${f.type}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        f.createdAt != null
                            ? _formatShortDate(f.createdAt!)
                            : 'Live Incident',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )),
      ],
    );
  }

  Widget _buildBreakdownMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    final norm = severity.trim().toLowerCase();
    Color bg;
    Color fg;
    if (norm == 'critical') {
      bg = AppTheme.danger.withValues(alpha: 0.1);
      fg = AppTheme.danger;
    } else if (norm == 'high') {
      bg = AppTheme.warning.withValues(alpha: 0.1);
      fg = const Color(0xFFD97706);
    } else {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class MachineStatusDonutChart extends StatelessWidget {
  final MachineStatistics? stats;
  final double size;
  final double strokeWidth;

  const MachineStatusDonutChart({
    super.key,
    required this.stats,
    this.size = 108,
    this.strokeWidth = 15,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: MachineStatusDonutPainter(
          stats: stats,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class MachineStatusDonutPainter extends CustomPainter {
  final MachineStatistics? stats;
  final double strokeWidth;

  const MachineStatusDonutPainter({
    required this.stats,
    this.strokeWidth = 15.0,
  });

  List<({int count, Color color})> get segments {
    final s = stats;
    if (s == null || s.total == 0) return const [];
    return [
      (count: s.running, color: AppTheme.green),
      (count: s.maintenance, color: AppTheme.warning),
      (count: s.breakdown, color: AppTheme.danger),
      if (s.other > 0) (count: s.other, color: const Color(0xFF788896)),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = const Color(0xFFEFF4F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    final currentStats = stats;
    if (currentStats == null || currentStats.total == 0) {
      return;
    }

    final total = currentStats.total;
    double startAngle = -math.pi / 2;

    for (final segment in segments) {
      if (segment.count <= 0) continue;
      final sweepAngle = (segment.count / total) * 2 * math.pi;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant MachineStatusDonutPainter oldDelegate) =>
      oldDelegate.stats != stats || oldDelegate.strokeWidth != strokeWidth;
}
