import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/app_routes.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();

      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Do not navigate to Home manually.
      // Firebase auth state -> AppStateProvider -> AuthGate
      // will handle navigation.
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
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MachAlert')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.precision_manufacturing,
                      size: 72,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Login to continue to MachAlert',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),

                    const SizedBox(height: 16),

                    AppTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      validator: Validators.password,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                        child: Text(
                          _showPassword ? 'Hide Password' : 'Show Password',
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    AppButton(
                      text: 'Login',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleLogin,
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context)
                                  .push<void>(AppRoutes.signup());
                            },
                      child: const Text("Don't have an account? Sign Up"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
