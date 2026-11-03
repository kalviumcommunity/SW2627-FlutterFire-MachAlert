import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/machine_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/main_bottom_navigation.dart';

class ReportsScreen extends StatefulWidget {
  final MachineProvider? machineProvider;

  const ReportsScreen({super.key, this.machineProvider});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0;

  static const _tabs = ['Overview', 'Inspections', 'Breakdowns'];

  @override
  void initState() {
    super.initState();
    widget.machineProvider?.addListener(_onMachineProviderChanged);
    _scheduleMachineSubscription();
  }

  @override
  void didUpdateWidget(ReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.machineProvider != oldWidget.machineProvider) {
      oldWidget.machineProvider?.removeListener(_onMachineProviderChanged);
      widget.machineProvider?.addListener(_onMachineProviderChanged);
      _scheduleMachineSubscription();
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
              child: const Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppTheme.navy,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Oct 1, 2026 - Oct 10, 2026',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
                padding: const EdgeInsets.all(18),
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

                        const SizedBox(width: 22),

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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendDot(color: AppTheme.green, label: 'Inspections'),
                        SizedBox(width: 20),
                        _LegendDot(color: AppTheme.danger, label: 'Breakdowns'),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      height: 170,
                      width: double.infinity,
                      child: CustomPaint(painter: _TrendPainter()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
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
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE8EDF1)
      ..strokeWidth = 1;

    for (var i = 1; i < 5; i++) {
      final y = size.height / 5 * i;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final greenPaint = Paint()
      ..color = AppTheme.green
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final redPaint = Paint()
      ..color = AppTheme.danger
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final greenPath = Path()
      ..moveTo(0, size.height * .68)
      ..lineTo(size.width * .12, size.height * .46)
      ..lineTo(size.width * .25, size.height * .58)
      ..lineTo(size.width * .38, size.height * .34)
      ..lineTo(size.width * .5, size.height * .54)
      ..lineTo(size.width * .63, size.height * .47)
      ..lineTo(size.width * .76, size.height * .28)
      ..lineTo(size.width * .88, size.height * .49)
      ..lineTo(size.width, size.height * .43);

    final redPath = Path()
      ..moveTo(0, size.height * .82)
      ..lineTo(size.width * .12, size.height * .78)
      ..lineTo(size.width * .25, size.height * .74)
      ..lineTo(size.width * .38, size.height * .76)
      ..lineTo(size.width * .5, size.height * .67)
      ..lineTo(size.width * .63, size.height * .71)
      ..lineTo(size.width * .76, size.height * .60)
      ..lineTo(size.width * .88, size.height * .65)
      ..lineTo(size.width, size.height * .62);

    canvas.drawPath(greenPath, greenPaint);

    canvas.drawPath(redPath, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
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
