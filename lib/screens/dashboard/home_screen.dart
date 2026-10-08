import 'package:flutter/material.dart';

import '../../widgets/app_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home preview')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Home screen',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Navigation preview only. '
                'No authentication or machine data is connected yet.',
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
