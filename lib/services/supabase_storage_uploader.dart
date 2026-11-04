import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' show SettableMetadata;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_constants.dart';
import '../utils/supabase_config.dart';
import 'storage_service.dart';

/// Concrete [StorageUploader] implementation uploading fault report photos
/// to Supabase Storage with Firebase Authentication third-party authorization.
class SupabaseStorageUploader implements StorageUploader {
  final SupabaseClient? clientOverride;
  final FirebaseAuth? authOverride;
  final String bucket;

  String get provider => AppConstants.storageProviderSupabase;

  /// Creates a [SupabaseStorageUploader].
  ///
  /// Optionally accepts [clientOverride] and [authOverride] for testing and dependency injection.
  /// Defaults to `Supabase.instance.client` and `FirebaseAuth.instance`.
  SupabaseStorageUploader({
    this.clientOverride,
    this.authOverride,
    this.bucket = SupabaseConfig.faultImagesBucket,
  });

  /// Resolves the active [SupabaseClient] instance.
  SupabaseClient get client {
    if (clientOverride != null) return clientOverride!;
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw StorageServiceException(
        code: 'supabase-not-initialized',
        message: 'Supabase client is not initialized. Please verify configuration.',
      );
    }
  }

  /// Resolves the active [FirebaseAuth] instance.
  FirebaseAuth get auth => authOverride ?? FirebaseAuth.instance;

  /// Normalizes an incoming storage path so that its top-level folder matches the user UID.
  ///
  /// For instance, `fault_images/<uid>/<file>` -> `<uid>/<file>`.
  /// Ensures strict compliance with Supabase RLS: `(storage.foldername(name))[1] = auth.jwt()->>'sub'`.
  static String normalizeUserScopedPath(String path, String expectedUid) {
    final segments = path.split('/').where((s) => s.trim().isNotEmpty).toList();

    if (segments.isEmpty) {
      throw StorageServiceException(
        code: 'invalid-path',
        message: 'The storage path cannot be empty.',
      );
    }

    // If already prefixed with UID: <uid>/<filename>
    if (segments.first == expectedUid) {
      return segments.join('/');
    }

    // If prefixed with folder: <folder>/<uid>/<filename>
    final uidIndex = segments.indexOf(expectedUid);
    if (uidIndex != -1) {
      return segments.sublist(uidIndex).join('/');
    }

    // Default: ensure path begins with expected UID
    return '$expectedUid/${segments.last}';
  }

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  }) async {
    // 1. Validate payload size (5 MB maximum)
    if (bytes.length > SupabaseConfig.maxUploadSizeBytes) {
      throw StorageServiceException(
        code: 'file-too-large',
        message: 'The image file exceeds the 5 MB limit. Please select a smaller image.',
      );
    }

    if (bytes.isEmpty) {
      throw StorageServiceException(
        code: 'empty-data',
        message: 'Cannot upload an empty image.',
      );
    }

    // 2. Validate user authentication
    final user = auth.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw StorageServiceException(
        code: 'unauthenticated',
        message: 'User is not authenticated. Please log in to upload images.',
      );
    }

    // 3. Ensure path is scoped to current authenticated user UID
    final normalizedPath = normalizeUserScopedPath(path, user.uid.trim());

    // Verify top-level folder matches authenticated UID
    final topFolder = normalizedPath.split('/').first;
    if (topFolder != user.uid.trim()) {
      throw StorageServiceException(
        code: 'permission-denied',
        message: 'Uploads are only permitted within your own user directory.',
      );
    }

    final contentType = metadata.contentType?.trim().isNotEmpty == true
        ? metadata.contentType!.trim()
        : 'image/jpeg';

    try {
      // 4. Upload binary to Supabase Storage
      await client.storage.from(bucket).uploadBinary(
            normalizedPath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: false,
            ),
          );

      // 5. Return the permanent storage path.
      // Firestore must store the permanent storagePath and storageProvider metadata,
      // NOT an expiring signed URL. Signed URLs are generated dynamically when displaying private images.
      return normalizedPath;
    } on StorageException catch (e) {
      final statusCode = int.tryParse(e.statusCode ?? '') ?? 0;

      if (statusCode == 401 || statusCode == 403) {
        throw StorageServiceException(
          code: 'permission-denied',
          message: 'You do not have permission to upload or access this file.',
        );
      } else if (statusCode == 413) {
        throw StorageServiceException(
          code: 'file-too-large',
          message: 'The image file exceeds the 5 MB limit. Please select a smaller image.',
        );
      }

      throw StorageServiceException(
        code: 'upload-failed',
        message: e.message.isNotEmpty
            ? e.message
            : 'Failed to upload image to Supabase Storage.',
      );
    } catch (e) {
      if (e is StorageServiceException) rethrow;

      throw StorageServiceException(
        code: 'upload-failed',
        message: 'Failed to upload the image to Supabase Storage: $e',
      );
    }
  }

  /// Generates a fresh, temporary signed URL for viewing a private image stored at [path].
  ///
  /// Defaults to 3600 seconds (1 hour) or custom [expiresInSeconds].
  Future<String> getSignedUrl(
    String path, {
    int expiresInSeconds = 3600,
  }) async {
    final cleanPath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    try {
      final signedUrl = await client.storage
          .from(bucket)
          .createSignedUrl(cleanPath, expiresInSeconds);

      if (signedUrl.trim().isNotEmpty) {
        return signedUrl;
      }
    } catch (e) {
      debugPrint('[SupabaseStorageUploader] Signed URL generation failed: $e');
    }

    return client.storage.from(bucket).getPublicUrl(cleanPath);
  }
}
