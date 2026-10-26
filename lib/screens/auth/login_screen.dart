import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  final UserService? userService;
  final AuthService? authService;

  const LoginScreen({super.key, this.userService, this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

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

      final credential = await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user != null) {
        await _ensureUserProfile(userService: userService, user: user);
      }

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

  Future<void> _ensureUserProfile({
    required UserService? userService,
    required User user,
  }) async {
    if (userService == null) {
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint(
          '[LoginScreen] Ensuring profile exists for UID: ${user.uid}',
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
          '[LoginScreen] Profile confirmed for UID: ${profile.id}, role: ${profile.role}',
        );
      }
    } on UserServiceException catch (profileError) {
      if (kDebugMode) {
        debugPrint(
          '[LoginScreen] Profile creation failed for UID: ${user.uid}: code=${profileError.code}, message=${profileError.message}',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Signed in, but could not set up user profile: ${profileError.message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[LoginScreen] Profile creation unexpected error for UID: ${user.uid}: $e',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signed in, but could not set up user profile. Please check your connection.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _isGoogleLoading = true;
    });

    // Capture services before async boundary so unmounting upon auth state change
    // does not prevent user profile creation or context lookup failure.
    AuthService? authService = widget.authService;
    if (authService == null) {
      try {
        authService = context.read<AuthService>();
      } catch (_) {
        authService = null;
      }
    }

    if (authService == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isGoogleLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication service is not available.'),
          ),
        );
      }
      return;
    }

    UserService? userService = widget.userService;
    if (userService == null) {
      try {
        userService = context.read<UserService>();
      } catch (_) {
        userService = null;
      }
    }

    try {
      final credential = await authService.signInWithGoogle();

      if (credential?.user != null) {
        final user = credential!.user!;
        if (kDebugMode) {
          debugPrint(
            '[LoginScreen] Google Sign-In succeeded for UID: ${user.uid}, email: ${user.email ?? 'unknown'}',
          );
        }

        await _ensureUserProfile(userService: userService, user: user);
      }

      // Do not navigate to Home manually.
      // Firebase auth state -> AppStateProvider -> AuthGate
      // will handle navigation.
    } on AuthServiceException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[LoginScreen] Google Sign-In AuthServiceException: code=${error.code}, message=${error.message}',
        );
      }
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LoginScreen] Google Sign-In unexpected error: $e');
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
                      isLoading: _isLoading && !_isGoogleLoading,
                      onPressed: _isLoading ? null : _handleLogin,
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
                      key: const Key('google_sign_in_button'),
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
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
                            ? 'Signing in with Google...'
                            : 'Sign in with Google',
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
