import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_routes.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/mach_alert_logo.dart';

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
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: MachAlertLogo()),

                    const SizedBox(height: 28),

                    const Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Login to continue to MachAlert',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF748694), fontSize: 13),
                    ),

                    const SizedBox(height: 30),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                  _showPassword
                                      ? 'Hide Password'
                                      : 'Show Password',
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            AppButton(
                              text: 'Login',
                              isLoading: _isLoading && !_isGoogleLoading,
                              onPressed: _isLoading ? null : _handleLogin,
                            ),

                            const SizedBox(height: 18),

                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Color(0xFF8796A2),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),

                            const SizedBox(height: 18),

                            OutlinedButton.icon(
                              key: const Key('google_sign_in_button'),
                              onPressed: _isLoading
                                  ? null
                                  : _handleGoogleSignIn,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.navy,
                                minimumSize: const Size.fromHeight(50),
                                side: const BorderSide(
                                  color: Color(0xFFDCE5EC),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              icon: _isGoogleLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.green,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/branding/google_g_logo.png',
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.contain,
                                      semanticLabel: 'Google logo',
                                    ),
                              label: Text(
                                _isGoogleLoading
                                    ? 'Signing in with Google...'
                                    : 'Sign in with Google',
                              ),
                            ),
                          ],
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
