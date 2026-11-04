import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized configuration and initialization for Supabase Storage.
///
/// Configures third-party Firebase Authentication integration so that
/// Supabase Storage requests are authorized using the fresh Firebase ID token.
class SupabaseConfig {
  SupabaseConfig._();

  /// Default Supabase Project URL for MachAlert-Storage.
  static const String defaultUrl = 'https://klerkuqcpizqfkaksbrl.supabase.co';

  /// Default private bucket for fault incident photo attachments.
  static const String defaultBucket = 'fault-images';

  /// Compile-time configured Supabase project URL.
  /// Set via: `--dart-define=SUPABASE_URL=https://klerkuqcpizqfkaksbrl.supabase.co`
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: defaultUrl,
  );

  /// Compile-time configured Supabase publishable/anon key.
  /// Set via: `--dart-define=SUPABASE_PUBLISHABLE_KEY=<key>`
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
  );

  /// Storage bucket identifier for fault report image attachments.
  /// Set via: `--dart-define=SUPABASE_BUCKET=fault-images`
  static const String faultImagesBucket = String.fromEnvironment(
    'SUPABASE_BUCKET',
    defaultValue: defaultBucket,
  );

  /// Maximum allowed image upload size in bytes (5 MB).
  static const int maxUploadSizeBytes = 5 * 1024 * 1024;

  /// Returns whether Supabase has been supplied with a non-empty publishable key.
  static bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  /// Resolves the active [SupabaseClient] if initialized, or null.
  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initializes the Supabase client with the Firebase ID token provider.
  ///
  /// Third-party authentication passes the fresh Firebase ID token containing
  /// the custom claims (`role: 'authenticated'`, `machalert_role: '<role>'`)
  /// to Supabase Storage RLS policies.
  static Future<bool> initialize({
    String? customUrl,
    String? customKey,
    FirebaseAuth? auth,
    Future<String?> Function()? accessTokenProvider,
  }) async {
    final targetUrl = customUrl ?? url;
    final targetKey = customKey ?? publishableKey;

    if (targetKey.trim().isEmpty) {
      debugPrint(
        '[SupabaseConfig] Publishable key not configured. '
        'Supabase client initialization skipped.',
      );
      return false;
    }

    try {
      final effectiveAuth = auth ?? FirebaseAuth.instance;
      final tokenProvider = accessTokenProvider ??
          () async {
            try {
              final user = effectiveAuth.currentUser;
              if (user == null) return null;
              // Return current valid ID token or refreshed token
              return await user.getIdToken();
            } catch (e) {
              debugPrint('[SupabaseConfig] Failed to retrieve Firebase ID token: $e');
              return null;
            }
          };

      await Supabase.initialize(
        url: targetUrl.trim(),
        publishableKey: targetKey.trim(),
        accessToken: tokenProvider,
      );

      debugPrint(
        '[SupabaseConfig] Supabase initialized successfully for project: $targetUrl',
      );
      return true;
    } catch (e) {
      debugPrint('[SupabaseConfig] Supabase initialization failed: $e');
      return false;
    }
  }
}
