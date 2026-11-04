import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/app_state_provider.dart';
import 'providers/machine_provider.dart';
import 'screens/auth/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/fault_service.dart';
import 'services/machine_activity_service.dart';
import 'services/machine_service.dart';
import 'services/maintenance_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_storage_uploader.dart';
import 'services/user_service.dart';
import 'utils/emulator_config.dart';
import 'utils/supabase_config.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  EmulatorConfig.configureFirestore();
  await EmulatorConfig.configureStorage();

  if (SupabaseConfig.isConfigured) {
    await SupabaseConfig.initialize();
  }

  runApp(const MachAlertApp());
}

class MachAlertApp extends StatelessWidget {
  final AuthService? authService;
  final UserService? userService;
  final MachineService? machineService;
  final FaultService? faultService;
  final StorageService? storageService;
  final MaintenanceService? maintenanceService;
  final MachineActivityService? machineActivityService;
  final AppStateProvider? appStateProvider;
  final MachineProvider? machineProvider;
  final Duration? minSplashDuration;
  final SharedPreferences? sharedPreferences;

  const MachAlertApp({
    super.key,
    this.authService,
    this.userService,
    this.machineService,
    this.faultService,
    this.storageService,
    this.maintenanceService,
    this.machineActivityService,
    this.appStateProvider,
    this.machineProvider,
    this.minSplashDuration,
    this.sharedPreferences,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (authService != null)
          Provider<AuthService>.value(value: authService!)
        else
          Provider<AuthService>(create: (_) => AuthService()),
        if (userService != null)
          Provider<UserService>.value(value: userService!)
        else
          Provider<UserService>(create: (_) => UserService()),
        if (machineService != null)
          Provider<MachineService>.value(value: machineService!)
        else
          Provider<MachineService>(create: (_) => MachineService()),
        if (faultService != null)
          Provider<FaultService>.value(value: faultService!)
        else
          Provider<FaultService>(create: (_) => FaultService()),
        if (storageService != null)
          Provider<StorageService>.value(value: storageService!)
        else
          Provider<StorageService>(
            create: (_) {
              if (SupabaseConfig.isConfigured) {
                return StorageService(uploader: SupabaseStorageUploader());
              }
              // Do not silently fall back to Firebase Storage for new uploads.
              // Firebase Storage is unavailable on the Spark plan.
              return StorageService(
                uploader: const UnconfiguredStorageUploader(),
              );
            },
          ),
        if (maintenanceService != null)
          Provider<MaintenanceService>.value(value: maintenanceService!)
        else
          Provider<MaintenanceService>(create: (_) => MaintenanceService()),
        if (machineActivityService != null)
          Provider<MachineActivityService>.value(value: machineActivityService!)
        else
          Provider<MachineActivityService>(
            create: (context) {
              final faultService = context.read<FaultService>();
              final maintenanceService = context.read<MaintenanceService>();
              final userService = context.read<UserService>();
              return MachineActivityService(
                faultService: faultService,
                maintenanceService: maintenanceService,
                userService: userService,
              );
            },
          ),
        if (appStateProvider != null)
          ChangeNotifierProvider<AppStateProvider>.value(
            value: appStateProvider!,
          )
        else
          ChangeNotifierProvider<AppStateProvider>(
            create: (context) {
              final authService = context.read<AuthService>();

              final userService = context.read<UserService>();

              return AppStateProvider(
                authService: authService,
                userService: userService,
              );
            },
          ),
        if (machineProvider != null)
          ChangeNotifierProvider<MachineProvider>.value(value: machineProvider!)
        else
          ChangeNotifierProvider<MachineProvider>(
            create: (context) {
              final machineService = context.read<MachineService>();
              return MachineProvider(machineService: machineService);
            },
          ),
      ],
      child: MaterialApp(
        title: 'MachAlert',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: AuthGate(
          minSplashDuration:
              minSplashDuration ?? const Duration(milliseconds: 1500),
          sharedPreferences: sharedPreferences,
        ),
      ),
    );
  }
}
