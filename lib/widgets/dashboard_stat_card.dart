import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final bool isLoading;
  final bool hasError;

  const DashboardStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.isLoading = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.green;
    final isTest = !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoading)
                    SizedBox(
                      height: 27,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            value: isTest ? 0.75 : null,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(AppTheme.navy),
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      value,
                      style: TextStyle(
                        color: hasError ? AppTheme.danger : AppTheme.navy,
                        fontSize: hasError && value.length > 3 ? 16 : 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF718292),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
