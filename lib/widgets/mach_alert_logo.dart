import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MachAlertLogo extends StatelessWidget {
  final bool compact;
  final bool light;

  const MachAlertLogo({super.key, this.compact = false, this.light = false});

  @override
  Widget build(BuildContext context) {
    final textColor = light ? Colors.white : AppTheme.navy;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 44,
          height: compact ? 32 : 44,
          decoration: BoxDecoration(
            color: AppTheme.green,
            borderRadius: BorderRadius.circular(compact ? 9 : 13),
          ),
          child: Icon(
            Icons.monitor_heart_outlined,
            color: Colors.white,
            size: compact ? 20 : 27,
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: compact ? 18 : 28,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            children: const [
              TextSpan(text: 'Mach'),
              TextSpan(
                text: 'Alert',
                style: TextStyle(color: AppTheme.green),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
