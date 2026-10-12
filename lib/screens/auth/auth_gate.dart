import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../widgets/app_loading_indicator.dart';
import '../dashboard/home_screen.dart';
import 'login_screen.dart';

/// Displays the appropriate UI for the shared authentication state.
///
/// This widget does not authenticate users or subscribe to Firebase.
/// It only reads AppStateProvider.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AppStateProvider>().status;

    if (status == AppStatus.initializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('MachAlert')),
        body: const AppLoadingIndicator(),
      );
    }

    // A different key creates a fresh navigation stack when the
    // authentication state changes.
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
