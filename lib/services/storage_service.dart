import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
      case 'unauthenticated':
        return 'User is not authenticated. Please log in to upload images.';
      case 'empty-data':
        return 'Cannot upload an empty image.';
      case 'invalid-filename':
        return 'The provided image filename is invalid.';
      case 'unauthorized':
      case 'permission-denied':
        return 'You do not have permission to upload or access this file.';
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
  /// Uploads [bytes] to the specified storage [path] with [metadata] and returns the download URL.
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

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  }) async {
    final ref = _storage.ref(path);

    try {
      final task = ref.putData(bytes, metadata);
      await task;
    } on FirebaseException {
      rethrow;
    } catch (e) {
      throw StorageServiceException(
        code: 'upload-failed',
        message: 'Failed to upload the image. Please try again.',
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

  /// Builds a unique, user-scoped storage path under [folder].
  ///
  /// Format: `<folder>/<uid>/<timestamp>_<counter>_<sanitizedFileName>`
  static String buildStoragePath({
    required String uid,
    required String fileName,
    String folder = defaultFolder,
  }) {
    final sanitized = sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final counter = _uniqueCounter++;
    return '$folder/$uid/${timestamp}_${counter}_$sanitized';
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
}
