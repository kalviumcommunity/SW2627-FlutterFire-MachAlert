import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/app_routes.dart';
import '../../widgets/app_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MachAlert')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Login', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                'This is a navigation placeholder. '
                'The login form will be added on Day 4.',
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Open Sign Up',
                onPressed: () {
                  Navigator.of(context).push<void>(AppRoutes.signup());
                },
              ),

              // Temporary navigation demo.
              // Remove when the real authentication flow is connected.
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                AppButton(
                  text: 'Preview Home (no login)',
                  onPressed: () {
                    Navigator.of(context).push<void>(AppRoutes.homePreview());
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
