import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create your account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'This is a navigation placeholder. '
                'The signup form will be added on Day 4.',
              ),
              const SizedBox(height: 24),
              AppButton(
                text: 'Back to Login',
                onPressed: () {
                  Navigator.of(context).pop<void>();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
