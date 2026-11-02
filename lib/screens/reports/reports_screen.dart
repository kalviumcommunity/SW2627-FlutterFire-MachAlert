import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/mach_alert_logo.dart';
import '../../widgets/main_bottom_navigation.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0;

  static const _tabs = ['Overview', 'Inspections', 'Breakdowns'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Reports')),
      bottomNavigationBar: const MainBottomNavigation(currentIndex: 3),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: MachAlertLogo(compact: true),
            ),

            const SizedBox(height: 22),

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
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 108,
                            height: 108,
                            child: CircularProgressIndicator(
                              value: 0.67,
                              strokeWidth: 15,
                              backgroundColor: const Color(0xFFFFE4E4),
                              color: AppTheme.green,
                            ),
                          ),
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '12',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy,
                                ),
                              ),
                              Text(
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

                    const Expanded(
                      child: Column(
                        children: [
                          _LegendRow(
                            color: AppTheme.green,
                            label: 'Running',
                            value: '8 (67%)',
                          ),
                          SizedBox(height: 12),
                          _LegendRow(
                            color: AppTheme.warning,
                            label: 'Maintenance',
                            value: '2 (17%)',
                          ),
                          SizedBox(height: 12),
                          _LegendRow(
                            color: AppTheme.danger,
                            label: 'Breakdown',
                            value: '2 (17%)',
                          ),
                        ],
                      ),
                    ),
                  ],
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
