import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Centralized configuration for local Firebase, Firestore, and Storage emulators.
class EmulatorConfig {
  EmulatorConfig._();

  /// Default Firestore emulator port as configured in firebase.json.
  static const int defaultFirestorePort = 8080;

  /// Default Firebase Storage emulator port as configured in firebase.json.
  static const int defaultStoragePort = 9199;

  /// Android emulator loopback alias pointing to the development host machine.
  static const String androidHost = '10.0.2.2';

  /// Standard loopback address for macOS, iOS, web, and desktop.
  static const String defaultHost = '127.0.0.1';

  /// Resolves the platform-aware Firestore emulator host.
  ///
  /// The Android emulator runs in a separate virtual network space and must use
  /// `10.0.2.2` to access the Mac host's `127.0.0.1`.
  /// macOS desktop, iOS simulators, and other platforms use `127.0.0.1`.
  static String get firestoreHost {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidHost;
    }
    return defaultHost;
  }

  /// Resolves the platform-aware Storage emulator host.
  static String get storageHost {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidHost;
    }
    return defaultHost;
  }

  /// Compile-time environment flag for enabling/disabling the local emulator.
  /// Set with: `--dart-define=USE_FIREBASE_EMULATOR=false`
  static const bool useEmulatorFlag = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: true,
  );

  /// Compile-time environment flag for explicitly requesting cloud mode.
  /// Set with: `--dart-define=USE_CLOUD_FIRESTORE=true`
  static const bool useCloudFirestoreFlag = bool.fromEnvironment(
    'USE_CLOUD_FIRESTORE',
    defaultValue: false,
  );

  /// Compile-time environment mode string ('emulator' or 'cloud').
  /// Set with: `--dart-define=FIRESTORE_MODE=cloud`
  static const String firestoreMode = String.fromEnvironment(
    'FIRESTORE_MODE',
    defaultValue: '',
  );

  /// Compile-time environment flag for explicitly requesting cloud storage mode.
  /// Set with: `--dart-define=USE_CLOUD_STORAGE=true`
  static const bool useCloudStorageFlag = bool.fromEnvironment(
    'USE_CLOUD_STORAGE',
    defaultValue: false,
  );

  /// Compile-time environment mode string for storage ('emulator' or 'cloud').
  /// Set with: `--dart-define=STORAGE_MODE=cloud`
  static const String storageMode = String.fromEnvironment(
    'STORAGE_MODE',
    defaultValue: '',
  );

  /// Programmatic override for tests or dependency injection.
  /// If set to non-null, overrides compile-time flags and defaults.
  static bool? overrideUseEmulator;

  /// Cache of configured FirebaseStorage instances to prevent duplicate configuration.
  static final Set<FirebaseStorage> _configuredStorageInstances =
      <FirebaseStorage>{};

  /// Resets storage configuration tracking for unit tests.
  @visibleForTesting
  static void resetStorageConfiguration() {
    _configuredStorageInstances.clear();
  }

  /// Returns true if Firestore should connect to the local emulator.
  ///
  /// Guarantees:
  /// - Only enabled when running in [kDebugMode] (release builds never use the emulator).
  /// - Defaults to `true` in debug mode for safe local development/testing.
  /// - Returns `false` when explicitly configured for cloud mode:
  ///   - `--dart-define=USE_FIREBASE_EMULATOR=false`
  ///   - `--dart-define=USE_CLOUD_FIRESTORE=true`
  ///   - `--dart-define=FIRESTORE_MODE=cloud`
  /// - Programmatic [overrideUseEmulator] takes highest precedence when set.
  static bool get shouldUseEmulator {
    if (!kDebugMode) {
      return false;
    }

    if (overrideUseEmulator != null) {
      return overrideUseEmulator!;
    }

    if (useCloudFirestoreFlag || firestoreMode.toLowerCase() == 'cloud') {
      return false;
    }

    return useEmulatorFlag;
  }

  /// Returns true if Storage should connect to the local emulator.
  ///
  /// Follows the same security and environment policy as Firestore:
  /// - Only enabled in [kDebugMode].
  /// - Bypassed when explicit cloud flags are supplied.
  /// - Honors [overrideUseEmulator].
  static bool get shouldUseStorageEmulator {
    if (!kDebugMode) {
      return false;
    }

    if (overrideUseEmulator != null) {
      return overrideUseEmulator!;
    }

    if (useCloudStorageFlag || storageMode.toLowerCase() == 'cloud') {
      return false;
    }

    if (useCloudFirestoreFlag || firestoreMode.toLowerCase() == 'cloud') {
      return false;
    }

    return useEmulatorFlag;
  }

  /// Returns true if the app is currently configured to connect to the real Cloud Firestore database.
  static bool get isCloudMode => !shouldUseEmulator;

  /// Returns true if the app is currently configured to connect to the real Cloud Storage bucket.
  static bool get isStorageCloudMode => !shouldUseStorageEmulator;

  /// Configures [FirebaseFirestore] targeting either the local emulator or Cloud Firestore.
  ///
  /// - When emulator mode is selected (safe debug default):
  ///   redirects Firestore traffic to local emulator at [host] and [port].
  /// - When cloud mode is selected (explicit cloud flag or release build):
  ///   does NOT call [useFirestoreEmulator], allowing Firestore to connect directly
  ///   to the real Firebase Cloud Firestore database.
  ///
  /// Returns `true` if connected to the local emulator, or `false` if connected to Cloud Firestore.
  static bool configureFirestore({
    FirebaseFirestore? firestore,
    String? host,
    int port = defaultFirestorePort,
    bool? useEmulator,
  }) {
    final activeUseEmulator = useEmulator ?? shouldUseEmulator;

    if (!activeUseEmulator) {
      if (kDebugMode) {
        debugPrint(
          '[EmulatorConfig] Firestore configured for REAL CLOUD DATABASE (machalert).',
        );
      }
      return false;
    }

    final targetFirestore = firestore ?? FirebaseFirestore.instance;
    final targetHost = host ?? firestoreHost;

    if (kDebugMode) {
      debugPrint(
        '[EmulatorConfig] Firestore configured for LOCAL EMULATOR at $targetHost:$port.',
      );
    }

    targetFirestore.useFirestoreEmulator(targetHost, port, sslEnabled: false);
    return true;
  }

  /// Backward-compatible alias for [configureFirestore].
  static bool configureFirestoreEmulator({
    FirebaseFirestore? firestore,
    String? host,
    int port = defaultFirestorePort,
    bool? useEmulator,
  }) {
    return configureFirestore(
      firestore: firestore,
      host: host,
      port: port,
      useEmulator: useEmulator,
    );
  }

  /// Configures [FirebaseStorage] targeting either the local emulator or Cloud Storage.
  ///
  /// - When emulator mode is selected (safe debug default):
  ///   redirects Storage traffic to local emulator at [host] and [port].
  /// - When cloud mode is selected (explicit cloud flag or release build):
  ///   does NOT call [useStorageEmulator], allowing Storage to connect directly
  ///   to the real Firebase Cloud Storage bucket.
  ///
  /// Guarantees:
  /// - Never connects release builds to the emulator.
  /// - Avoids configuring the same [FirebaseStorage] instance twice.
  /// - Preserves dependency injection used by tests.
  ///
  /// Returns `true` if connected to the local emulator, or `false` if connected to Cloud Storage.
  static Future<bool> configureStorage({
    FirebaseStorage? storage,
    String? host,
    int port = defaultStoragePort,
    bool? useEmulator,
  }) async {
    final activeUseEmulator = useEmulator ?? shouldUseStorageEmulator;

    if (!activeUseEmulator) {
      if (kDebugMode) {
        debugPrint(
          '[EmulatorConfig] Storage configured for REAL CLOUD STORAGE (machalert).',
        );
      }
      return false;
    }

    final targetStorage = storage ?? FirebaseStorage.instance;
    if (_configuredStorageInstances.contains(targetStorage)) {
      if (kDebugMode) {
        debugPrint(
          '[EmulatorConfig] Storage instance already configured for emulator.',
        );
      }
      return true;
    }

    final targetHost = host ?? storageHost;

    if (kDebugMode) {
      debugPrint(
        '[EmulatorConfig] Storage configured for LOCAL EMULATOR at $targetHost:$port.',
      );
    }

    await targetStorage.useStorageEmulator(targetHost, port);
    _configuredStorageInstances.add(targetStorage);
    return true;
  }
}
