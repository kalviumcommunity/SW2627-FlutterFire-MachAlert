import 'dart:math';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/app_constants.dart';
import '../utils/supabase_config.dart';
import 'supabase_storage_uploader.dart';

/// Exception thrown by [StorageService] operations when uploads fail,
/// input data is invalid, or the user is not authenticated.
class StorageServiceException implements Exception {
  static const String defaultErrorMessage =
      'A storage error occurred while uploading the image. Please try again.';

  /// Error code identifying the failure reason.
  final String code;

  /// User-readable, safe error message.
  final String message;

  StorageServiceException({required this.code, String? message})
    : message = message ?? messageForErrorCode(code);

  /// Creates a [StorageServiceException] from a [FirebaseException].
  factory StorageServiceException.fromFirebaseException(
    FirebaseException exception,
  ) {
    final normalizedCode = exception.code.toLowerCase().replaceAll('_', '-');
    return StorageServiceException(
      code: normalizedCode,
      message: messageForErrorCode(normalizedCode),
    );
  }

  /// Maps storage error codes to safe, user-friendly messages.
  static String messageForErrorCode(String code) {
    switch (code.toLowerCase().replaceAll('_', '-')) {
      case 'image-unreadable':
      case 'file-not-found':
        return 'The selected image file is missing or unreadable. Please choose another image.';
      case 'unauthenticated':
        return 'User is not authenticated. Please log in to upload images.';
      case 'empty-data':
        return 'Cannot upload an empty image.';
      case 'invalid-filename':
        return 'The provided image filename is invalid.';
      case 'unauthorized':
      case 'permission-denied':
        return 'You do not have permission to upload or access this file.';
      case 'network-request-failed':
      case 'network-error':
      case 'unavailable':
        return 'Network connection failed during upload. Please check your internet connection.';
      case 'canceled':
      case 'cancelled':
        return 'The image upload was cancelled.';
      case 'retry-limit-exceeded':
        return 'The upload timed out or exceeded the retry limit. Please try again.';
      case 'invalid-checksum':
        return 'File integrity check failed during upload. Please try again.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Please contact your system administrator.';
      case 'object-not-found':
        return 'The requested storage file was not found.';
      case 'bucket-not-found':
        return 'Storage bucket not configured properly.';
      case 'project-not-found':
        return 'Firebase project configuration error.';
      case 'download-url-failed':
        return 'Failed to retrieve the image download URL after upload.';
      case 'storage-unconfigured':
        return 'Image storage is not configured. Supabase credentials are required and Firebase Storage is disabled on this plan.';
      case 'upload-failed':
        return 'Failed to upload the image. Please try again.';
      default:
        return defaultErrorMessage;
    }
  }

  @override
  String toString() =>
      'StorageServiceException(code: $code, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorageServiceException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(code, message);
}

/// Abstract contract for uploading data to storage and resolving download URLs.
abstract class StorageUploader {
  /// Uploads [bytes] to the specified storage [path] with [metadata] and returns the download URL or permanent storage path.
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  });
}

/// Default implementation of [StorageUploader] delegating to [FirebaseStorage].
class FirebaseStorageUploader implements StorageUploader {
  final FirebaseStorage _storage;

  FirebaseStorageUploader(this._storage);

  String get provider => AppConstants.storageProviderFirebase;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  }) async {
    final ref = _storage.ref(path);

    try {
      final task = ref.putData(bytes, metadata);
      final snapshot = await task;
      if (snapshot.state == TaskState.canceled) {
        throw StorageServiceException(
          code: 'canceled',
          message: 'The image upload was cancelled.',
        );
      }
      if (snapshot.state == TaskState.error) {
        throw StorageServiceException(
          code: 'upload-failed',
          message: 'Failed to upload the image. Please try again.',
        );
      }
    } on FirebaseException {
      rethrow;
    } catch (e) {
      if (e is StorageServiceException) rethrow;
      throw StorageServiceException(
        code: 'upload-failed',
        message: 'Failed to upload the image. Please try again.',
      );
    }

    try {
      final objectMetadata = await ref.getMetadata();
      if (objectMetadata.size != null && objectMetadata.size! <= 0) {
        throw StorageServiceException(
          code: 'upload-failed',
          message: 'Uploaded file is empty or corrupted. Please try again.',
        );
      }
    } on FirebaseException {
      rethrow;
    } catch (e) {
      if (e is StorageServiceException) rethrow;
      throw StorageServiceException(
        code: 'upload-failed',
        message: 'Failed to verify uploaded image metadata. Please try again.',
      );
    }

    try {
      final downloadUrl = await ref.getDownloadURL();
      if (downloadUrl.trim().isEmpty) {
        throw StorageServiceException(
          code: 'download-url-failed',
          message: 'Failed to retrieve the image download URL after upload.',
        );
      }
      return downloadUrl;
    } on FirebaseException {
      rethrow;
    } catch (e) {
      if (e is StorageServiceException) {
        rethrow;
      }
      throw StorageServiceException(
        code: 'download-url-failed',
        message: 'Failed to retrieve the image download URL after upload.',
      );
    }
  }
}

/// Fallback [StorageUploader] used when Supabase is unconfigured,
/// preventing accidental uploads to the unavailable Firebase Storage service on Spark plan.
class UnconfiguredStorageUploader implements StorageUploader {
  final String message;

  const UnconfiguredStorageUploader({
    this.message =
        'Image upload is currently unavailable: Supabase Storage configuration is missing and Firebase Storage uploads are disabled on the Spark plan.',
  });

  String get provider => 'unconfigured';

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  }) async {
    throw StorageServiceException(
      code: 'storage-unconfigured',
      message: message,
    );
  }
}

/// Service managing image uploads to Firebase Storage for fault reports and other media.
class StorageService {
  /// Default folder for storing fault report image attachments.
  static const String defaultFolder = 'fault_images';

  static int _uniqueCounter = 0;

  final FirebaseStorage? _storage;
  final FirebaseAuth _auth;
  final StorageUploader _uploader;

  /// Creates a [StorageService] instance.
  ///
  /// Allows injection of [FirebaseStorage], [FirebaseAuth], and [StorageUploader]
  /// for isolated unit testing.
  StorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    StorageUploader? uploader,
  }) : _storage = storage,
       _auth = auth ?? FirebaseAuth.instance,
       _uploader =
           uploader ??
           FirebaseStorageUploader(storage ?? FirebaseStorage.instance);

  /// Access to the underlying [FirebaseStorage] instance.
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;

  /// Access to the underlying [FirebaseAuth] instance.
  FirebaseAuth get auth => _auth;

  /// The active storage provider ('supabase', 'firebase', or 'unconfigured').
  String get storageProvider {
    final uploader = _uploader;
    if (uploader is SupabaseStorageUploader) {
      return AppConstants.storageProviderSupabase;
    }
    if (uploader is UnconfiguredStorageUploader) {
      return 'unconfigured';
    }
    return AppConstants.storageProviderFirebase;
  }

  /// Resolves a displayable image URL.
  ///
  /// Returns HTTP(S) URLs directly (preserving existing Firebase Storage records).
  /// For Supabase private storage paths, generates a fresh signed URL for secure viewing.
  Future<String> getSignedUrl(
    String pathOrUrl, {
    int expiresInSeconds = 3600,
  }) async {
    final trimmed = pathOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final uploader = _uploader;
    if (uploader is SupabaseStorageUploader) {
      return await uploader.getSignedUrl(
        trimmed,
        expiresInSeconds: expiresInSeconds,
      );
    }

    if (SupabaseConfig.isConfigured && SupabaseConfig.client != null) {
      try {
        return await SupabaseConfig.client!.storage
            .from(SupabaseConfig.faultImagesBucket)
            .createSignedUrl(trimmed, expiresInSeconds);
      } catch (_) {}
    }

    return trimmed;
  }

  /// Sanitizes [fileName] by extracting the basename, removing path traversal segments,
  /// and replacing invalid or unsafe characters.
  ///
  /// Throws [StorageServiceException] with code `invalid-filename` if the filename is empty,
  /// contains only whitespace or dots, or lacks alphanumeric characters.
  static String sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      throw StorageServiceException(
        code: 'invalid-filename',
        message: 'The provided image filename is invalid.',
      );
    }

    // Extract basename if a path was provided (handle both Unix and Windows separators)
    final baseName = trimmed.split(RegExp(r'[/\\]')).last.trim();

    // Replace invalid/unsafe characters with underscores. Allow alphanumeric, dot, underscore, hyphen.
    final sanitized = baseName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // Remove leading dots to prevent hidden files or traversal (. or ..)
    final noLeadingDots = sanitized.replaceAll(RegExp(r'^\.+'), '');

    final clean = noLeadingDots.trim();

    if (clean.isEmpty ||
        clean == '.' ||
        clean == '..' ||
        !clean.contains(RegExp(r'[a-zA-Z0-9]'))) {
      throw StorageServiceException(
        code: 'invalid-filename',
        message: 'The provided image filename is invalid.',
      );
    }

    return clean;
  }

  /// Builds a unique, collision-resistant, user-scoped storage path under [folder].
  ///
  /// Format: `<folder>/<uid>/<timestamp>_<token>_<counter>_<sanitizedFileName>`
  static String buildStoragePath({
    required String uid,
    required String fileName,
    String folder = defaultFolder,
  }) {
    final sanitized = sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final counter = _uniqueCounter++;
    final token = Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$folder/$uid/${timestamp}_${token}_${counter}_$sanitized';
  }

  /// Uploads a fault report image to Firebase Storage and returns its public download URL.
  ///
  /// Conforms to Day 16 specifications: accepts image bytes, filename, and content type.
  Future<String> uploadFaultImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) {
    return uploadImage(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: defaultFolder,
    );
  }

  /// Uploads an image to Firebase Storage under [folder] and returns its download URL.
  ///
  /// Validates:
  /// - Non-empty bytes
  /// - User authentication via [FirebaseAuth]
  /// - Filename sanitization
  ///
  /// Maps all failures to [StorageServiceException].
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    String folder = defaultFolder,
    Map<String, String>? customMetadata,
  }) async {
    if (bytes.isEmpty) {
      throw StorageServiceException(
        code: 'empty-data',
        message: 'Cannot upload an empty image.',
      );
    }

    final user = auth.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw StorageServiceException(
        code: 'unauthenticated',
        message: 'User is not authenticated. Please log in to upload images.',
      );
    }

    final sanitized = sanitizeFileName(fileName);
    final path = buildStoragePath(
      uid: user.uid.trim(),
      fileName: sanitized,
      folder: folder,
    );

    final resolvedContentType = contentType.trim().isNotEmpty
        ? contentType.trim()
        : 'image/jpeg';

    final metadata = SettableMetadata(
      contentType: resolvedContentType,
      customMetadata: {
        'uploadedBy': user.uid.trim(),
        'originalFileName': sanitized,
        ...?customMetadata,
      },
    );

    try {
      return await _uploader.upload(
        path: path,
        bytes: bytes,
        metadata: metadata,
      );
    } on FirebaseException catch (e) {
      throw StorageServiceException.fromFirebaseException(e);
    } catch (e) {
      if (e is StorageServiceException) {
        rethrow;
      }
      throw StorageServiceException(
        code: 'upload-failed',
        message: 'Failed to upload the image. Please try again.',
      );
    }
  }

  /// Alias for [uploadFaultImage] supporting generic upload callers.
  Future<String> upload({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) {
    return uploadFaultImage(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );
  }

  /// Safely attempts to delete an uploaded storage file using its download URL.
  /// Used for orphan cleanup if a Firestore fault record cannot be saved.
  Future<void> deleteByUrl(String url) async {
    try {
      final ref = storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // Best-effort cleanup; ignore errors to avoid masking underlying failures
    }
  }

  /// Safely attempts to delete a storage object using its storage path.
  Future<void> deleteImage(String path) async {
    try {
      final ref = storage.ref(path);
      await ref.delete();
    } catch (_) {
      // Best-effort cleanup
    }
  }
}
