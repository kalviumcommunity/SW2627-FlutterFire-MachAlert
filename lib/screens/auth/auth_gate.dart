import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_state_provider.dart';
import '../dashboard/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../splash/splash_screen.dart';
import 'login_screen.dart';

/// Coordinates application startup, minimum splash display duration,
/// first-launch onboarding, and session navigation.
class AuthGate extends StatefulWidget {
  static const String hasCompletedOnboardingKey = 'hasCompletedOnboarding';

  /// Minimum duration the splash screen must remain visible on launch.
  final Duration minSplashDuration;

  /// Maximum duration to wait for initial authentication state before falling back.
  final Duration authTimeout;

  /// Optional injected [SharedPreferences] instance for deterministic testing.
  final SharedPreferences? sharedPreferences;

  const AuthGate({
    super.key,
    this.minSplashDuration = const Duration(milliseconds: 1500),
    this.authTimeout = const Duration(seconds: 6),
    this.sharedPreferences,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Timer? _splashTimer;
  Timer? _authSafetyTimer;

  bool _minSplashElapsed = false;
  bool _prefsLoaded = false;
  bool _hasCompletedOnboarding = false;
  bool _authTimeoutElapsed = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _startTimers();
    _loadPreferences();
  }

  void _startTimers() {
    if (widget.minSplashDuration == Duration.zero) {
      _minSplashElapsed = true;
    } else {
      _splashTimer = Timer(widget.minSplashDuration, () {
        if (!mounted) return;
        setState(() {
          _minSplashElapsed = true;
        });
      });
    }

    if (widget.authTimeout == Duration.zero) {
      _authTimeoutElapsed = true;
    } else {
      _authSafetyTimer = Timer(widget.authTimeout, () {
        if (!mounted) return;
        setState(() {
          _authTimeoutElapsed = true;
        });
      });
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs =
          widget.sharedPreferences ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      final completed =
          prefs.getBool(AuthGate.hasCompletedOnboardingKey) ?? false;
      if (!mounted) return;
      setState(() {
        _hasCompletedOnboarding = completed;
        _prefsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasCompletedOnboarding = false;
        _prefsLoaded = true;
      });
    }
  }

  Future<void> _handleOnboardingFinished() async {
    try {
      final prefs =
          _prefs ??
          widget.sharedPreferences ??
          await SharedPreferences.getInstance();
      await prefs.setBool(AuthGate.hasCompletedOnboardingKey, true);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _hasCompletedOnboarding = true;
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _authSafetyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AppStateProvider>().status;

    // Splash screen must remain visible while:
    // 1. The minimum 1.5s display duration has not elapsed, OR
    // 2. Preferences have not finished loading, OR
    // 3. Authentication is still initializing (unless the safety timeout elapsed).
    final isAuthResolving =
        status == AppStatus.initializing && !_authTimeoutElapsed;
    final showSplash = !_minSplashElapsed || !_prefsLoaded || isAuthResolving;

    if (showSplash) {
      return const SplashScreen();
    }

    // First installation: user has not completed onboarding
    if (!_hasCompletedOnboarding) {
      return OnboardingScreen(onFinished: _handleOnboardingFinished);
    }

    // Subsequent launches or post-onboarding: navigate to session
    return _SessionNavigator(key: ValueKey(status), status: status);
  }
}

class _SessionNavigator extends StatefulWidget {
  const _SessionNavigator({super.key, required this.status});

  final AppStatus status;

  @override
  State<_SessionNavigator> createState() => _SessionNavigatorState();
}

class _SessionNavigatorState extends State<_SessionNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler<void>(
      onPopWithResult: (_) {
        final navigator = _navigatorKey.currentState;

        if (navigator != null && navigator.canPop()) {
          navigator.pop<void>();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) {
              if (widget.status == AppStatus.authenticated) {
                return const HomeScreen();
              }

              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
