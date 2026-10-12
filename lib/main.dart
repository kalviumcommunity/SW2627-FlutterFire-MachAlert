import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MachAlertApp());
}

class MachAlertApp extends StatelessWidget {
  final AuthService? authService;
  final AppStateProvider? appStateProvider;

  const MachAlertApp({super.key, this.authService, this.appStateProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (authService != null)
          Provider<AuthService>.value(value: authService!)
        else
          Provider<AuthService>(create: (_) => AuthService()),
        if (appStateProvider != null)
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appStateProvider!,
          )
        else
          ChangeNotifierProvider<AppStateProvider>(
            create: (context) {
              AuthService? resolvedAuth;
              try {
                resolvedAuth = context.read<AuthService>();
              } catch (_) {
                resolvedAuth = null;
              }
              return AppStateProvider(authService: resolvedAuth);
            },
          ),
      ],
      child: MaterialApp(
        title: 'MachAlert',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: const AuthGate(),
      ),
    );
  }
}
