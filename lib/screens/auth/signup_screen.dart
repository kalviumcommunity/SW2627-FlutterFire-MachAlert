import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class SignupScreen extends StatefulWidget {
  final UserService? userService;
  final AuthService? authService;

  const SignupScreen({super.key, this.userService, this.authService});

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
  bool _isGoogleLoading = false;

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
      AuthService? authService = widget.authService;
      if (authService == null) {
        try {
          authService = context.read<AuthService>();
        } catch (_) {
          authService = null;
        }
      }

      if (authService == null) {
        throw AuthServiceException(
          code: 'operation-not-allowed',
          message: 'Authentication service is not available.',
        );
      }

      UserService? userService = widget.userService;
      if (userService == null) {
        try {
          userService = context.read<UserService>();
        } catch (_) {
          userService = null;
        }
      }

      final credential = await authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Firebase Auth currently stores email/password.
      // Save the entered name as the Firebase display name.
      await credential.user?.updateDisplayName(_nameController.text.trim());

      if (userService != null && credential.user != null) {
        try {
          await userService.createProfileIfAbsent(
            uid: credential.user!.uid,
            email: _emailController.text.trim(),
            displayName: _nameController.text.trim(),
            role: AppConstants.roleOperator,
          );
        } on UserServiceException catch (profileError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Account created, but could not set up user profile: ${profileError.message}',
                ),
              ),
            );
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created, but could not set up user profile. Please check your connection.',
                ),
              ),
            );
          }
        }
      }

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

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
      _isGoogleLoading = true;
    });

    try {
      AuthService? authService = widget.authService;
      if (authService == null) {
        try {
          authService = context.read<AuthService>();
        } catch (_) {
          authService = null;
        }
      }

      if (authService == null) {
        throw AuthServiceException(
          code: 'google-sign-in-failed',
          message: 'Authentication service is not available.',
        );
      }

      // Capture services before async boundary so unmounting upon auth state change
      // does not prevent user profile creation or context lookup failure.
      UserService? userService = widget.userService;
      if (userService == null) {
        try {
          userService = context.read<UserService>();
        } catch (_) {
          userService = null;
        }
      }

      final credential = await authService.signInWithGoogle();

      if (credential?.user != null) {
        final user = credential!.user!;
        if (kDebugMode) {
          debugPrint(
            '[SignupScreen] Google Sign-Up succeeded for UID: ${user.uid}, email: ${user.email ?? 'unknown'}',
          );
        }

        if (userService != null) {
          try {
            if (kDebugMode) {
              debugPrint(
                '[SignupScreen] Ensuring profile exists for UID: ${user.uid}',
              );
            }
            final profile = await userService.createProfileIfAbsent(
              uid: user.uid,
              email: user.email ?? '',
              displayName: user.displayName,
              role: AppConstants.roleOperator,
            );
            if (kDebugMode) {
              debugPrint(
                '[SignupScreen] Profile confirmed for UID: ${profile.id}, role: ${profile.role}',
              );
            }
          } on UserServiceException catch (profileError) {
            if (kDebugMode) {
              debugPrint(
                '[SignupScreen] Profile creation failed for UID: ${user.uid}: code=${profileError.code}, message=${profileError.message}',
              );
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Account created, but could not set up user profile: ${profileError.message}',
                  ),
                ),
              );
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                '[SignupScreen] Profile creation unexpected error for UID: ${user.uid}: $e',
              );
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Account created, but could not set up user profile. Please check your connection.',
                  ),
                ),
              );
            }
          }
        }
      }

      // Do not manually navigate to Home.
      // Auth state handling + AuthGate will do that.
    } on AuthServiceException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SignupScreen] Google Sign-In AuthServiceException: code=${error.code}, message=${error.message}',
        );
      }
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SignupScreen] Google Sign-In unexpected error: $e');
      }
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong with Google Sign-In. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleLoading = false;
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
                    Icon(
                      Icons.person_add_alt_1,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
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
                      isLoading: _isLoading && !_isGoogleLoading,
                      onPressed: _isLoading ? null : _handleSignup,
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      key: const Key('google_sign_up_button'),
                      onPressed: _isLoading ? null : _handleGoogleSignUp,
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                      label: Text(
                        _isGoogleLoading
                            ? 'Signing up with Google...'
                            : 'Sign up with Google',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

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
