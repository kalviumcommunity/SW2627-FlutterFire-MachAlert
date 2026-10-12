import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSigningOut = false;

  Future<void> _handleLogout() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      final authService = context.read<AuthService>();

      await authService.signOut();

      // No Navigator.push/pop here.
      // Auth state -> AuthGate handles the screen change.
    } on AuthServiceException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to logout. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MachAlert')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Home', style: Theme.of(context).textTheme.headlineSmall),

              const SizedBox(height: 12),

              const Text('You are signed in to MachAlert.'),

              const Spacer(),

              AppButton(
                text: 'Logout',
                isLoading: _isSigningOut,
                onPressed: _isSigningOut ? null : _handleLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
