import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _handleSignup() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();

      final credential = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Firebase Auth currently stores email/password.
      // Save the entered name as the Firebase display name.
      await credential.user?.updateDisplayName(_nameController.text.trim());

      // Do not manually navigate to Home.
      // Auth state handling + AuthGate will do that.
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
      appBar: AppBar(title: const Text('Sign Up')),
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
                      Icons.person_add_alt_1,
                      size: 64,
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),

                    const SizedBox(height: 24),

                    AppTextField(
                      label: 'Full Name',
                      controller: _nameController,
                      validator: (value) =>
                          Validators.required(value, 'Full Name'),
                    ),

                    const SizedBox(height: 16),

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

                    const SizedBox(height: 8),

                    AppTextField(
                      label: 'Confirm Password',
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      validator: (value) => Validators.confirmPassword(
                        value,
                        _passwordController.text,
                      ),
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                });
                              },
                        child: Text(
                          _showConfirmPassword
                              ? 'Hide Password'
                              : 'Show Password',
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    AppButton(
                      text: 'Sign Up',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleSignup,
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.of(context).pop<void>();
                            },
                      child: const Text('Already have an account? Login'),
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
