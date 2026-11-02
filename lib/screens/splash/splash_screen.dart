import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/mach_alert_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const MachAlertLogo(),

                const SizedBox(height: 22),

                const Text(
                  'Real-time machine monitoring\nfor a smarter factory',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 46),

                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppTheme.green,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'Checking your session...',
                  style: TextStyle(
                    color: AppTheme.navy.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
