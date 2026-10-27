import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/services/storage_service.dart';

class FakeUser extends Fake implements User {
  @override
  final String uid;

  FakeUser({required this.uid});
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  User? _currentUser;

  FakeFirebaseAuth({User? initialUser}) : _currentUser = initialUser;

  @override
  User? get currentUser => _currentUser;

  set currentUser(User? user) => _currentUser = user;
}

class FakeStorageUploader implements StorageUploader {
  String? lastPath;
  Uint8List? lastBytes;
  SettableMetadata? lastMetadata;
  int uploadCallCount = 0;

  String downloadUrlToReturn =
      'https://firebasestorage.googleapis.com/v0/b/bucket/o/fault_images%2Ftest.jpg?alt=media';
  Exception? errorToThrow;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  }) async {
    uploadCallCount++;
    lastPath = path;
    lastBytes = bytes;
    lastMetadata = metadata;

    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    return downloadUrlToReturn;
  }
}

class FakeTaskSnapshot extends Fake implements TaskSnapshot {}

class FakeUploadTask extends Fake implements UploadTask {
  final Future<TaskSnapshot> _future;

  FakeUploadTask([Future<TaskSnapshot>? future])
    : _future = future ?? Future.value(FakeTaskSnapshot());

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) {
    return _future.then(onValue, onError: onError);
  }
}

class FakeReference extends Fake implements Reference {
  final String path;
  Uint8List? putDataBytes;
  SettableMetadata? putDataMetadata;
  Exception? putDataError;
  Exception? getDownloadUrlError;
  String downloadUrlToReturn =
      'https://firebasestorage.googleapis.com/test-url';

  FakeReference(this.path);

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    putDataBytes = data;
    putDataMetadata = metadata;
    if (putDataError != null) {
      return FakeUploadTask(Future.error(putDataError!));
    }
    return FakeUploadTask(Future.value(FakeTaskSnapshot()));
  }

  @override
  Future<String> getDownloadURL() async {
    if (getDownloadUrlError != null) {
      throw getDownloadUrlError!;
    }
    return downloadUrlToReturn;
  }
}

class FakeFirebaseStorage extends Fake implements FirebaseStorage {
  final Map<String, FakeReference> references = {};
  FakeReference? lastReference;
  Exception? nextPutDataError;
  Exception? nextGetDownloadUrlError;
  String defaultDownloadUrl = 'https://firebasestorage.googleapis.com/test-url';

  @override
  Reference ref([String? path]) {
    final refPath = path ?? '';
    final reference = references[refPath] ?? FakeReference(refPath)
      ..putDataError = nextPutDataError
      ..getDownloadUrlError = nextGetDownloadUrlError
      ..downloadUrlToReturn = defaultDownloadUrl;
    references[refPath] = reference;
    lastReference = reference;
    return reference;
  }
}

void main() {
  group('StorageService', () {
    late FakeFirebaseAuth fakeAuth;
    late FakeStorageUploader fakeUploader;
    late StorageService service;
    late Uint8List sampleBytes;

    setUp(() {
      fakeAuth = FakeFirebaseAuth(initialUser: FakeUser(uid: 'user-op-42'));
      fakeUploader = FakeStorageUploader();
      service = StorageService(auth: fakeAuth, uploader: fakeUploader);
      sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('1. A successful upload returns the download URL', () async {
      const expectedUrl =
          'https://firebasestorage.googleapis.com/v0/b/bucket/o/fault_images%2Fphoto.jpg?alt=media';
      fakeUploader.downloadUrlToReturn = expectedUrl;

      final result = await service.uploadFaultImage(
        bytes: sampleBytes,
        fileName: 'broken_gear.jpg',
      );

      expect(result, equals(expectedUrl));
      expect(fakeUploader.uploadCallCount, equals(1));
    });

    test('2. Upload path is unique and includes the intended folder and user scope', () async {
      final url1 = await service.uploadFaultImage(
        bytes: sampleBytes,
        fileName: 'gear.jpg',
      );
      final path1 = fakeUploader.lastPath!;

      final url2 = await service.uploadFaultImage(
        bytes: sampleBytes,
        fileName: 'gear.jpg',
      );
      final path2 = fakeUploader.lastPath!;

      expect(url1, isNotEmpty);
      expect(url2, isNotEmpty);

      // Path contains dedicated folder and user scope
      expect(path1, startsWith('fault_images/user-op-42/'));
      expect(path2, startsWith('fault_images/user-op-42/'));

      // Path ends with sanitized filename
      expect(path1, endsWith('_gear.jpg'));
      expect(path2, endsWith('_gear.jpg'));

      // Upload paths are strictly unique
      expect(path1, isNot(equals(path2)));
    });

    test('3. Filenames are sanitized properly', () async {
      // Spaces and special characters
      expect(
        StorageService.sanitizeFileName('my photo (1) #2.jpg'),
        equals('my_photo__1___2.jpg'),
      );

      // Path traversal characters stripped
      expect(
        StorageService.sanitizeFileName('../../etc/passwd.png'),
        equals('passwd.png'),
      );

      // Windows style path traversal stripped
      expect(
        StorageService.sanitizeFileName(r'C:\Users\Admin\photo.jpeg'),
        equals('photo.jpeg'),
      );

      // Leading dots stripped
      expect(
        StorageService.sanitizeFileName('...hidden_file.jpg'),
        equals('hidden_file.jpg'),
      );

      // Upload with path traversal and special chars produces clean path
      await service.uploadFaultImage(
        bytes: sampleBytes,
        fileName: '../../uploads/bad file name (1).jpg',
      );

      expect(fakeUploader.lastPath, endsWith('_bad_file_name__1_.jpg'));
      expect(fakeUploader.lastPath, isNot(contains('..')));
    });

    test('4. Empty image bytes are rejected safely', () async {
      final emptyBytes = Uint8List(0);

      expect(
        () =>
            service.uploadFaultImage(bytes: emptyBytes, fileName: 'valid.jpg'),
        throwsA(
          isA<StorageServiceException>()
              .having((e) => e.code, 'code', 'empty-data')
              .having(
                (e) => e.message,
                'message',
                'Cannot upload an empty image.',
              ),
        ),
      );

      expect(fakeUploader.uploadCallCount, equals(0));
    });

    test('5. Invalid filenames are handled safely', () async {
      final invalidFileNames = [
        '',
        '    ',
        '..',
        '...',
        '///',
        '../..',
        '???',
        '#@!\$',
      ];

      for (final invalid in invalidFileNames) {
        expect(
          () => service.uploadFaultImage(bytes: sampleBytes, fileName: invalid),
          throwsA(
            isA<StorageServiceException>()
                .having((e) => e.code, 'code', 'invalid-filename')
                .having(
                  (e) => e.message,
                  'message',
                  'The provided image filename is invalid.',
                ),
          ),
          reason: 'Failed to reject invalid filename "$invalid"',
        );
      }

      expect(fakeUploader.uploadCallCount, equals(0));
    });

    test('6. Missing authentication is handled safely', () async {
      fakeAuth.currentUser = null;

      expect(
        () =>
            service.uploadFaultImage(bytes: sampleBytes, fileName: 'motor.jpg'),
        throwsA(
          isA<StorageServiceException>()
              .having((e) => e.code, 'code', 'unauthenticated')
              .having(
                (e) => e.message,
                'message',
                'User is not authenticated. Please log in to upload images.',
              ),
        ),
      );

      // Empty UID also treated as unauthenticated
      fakeAuth.currentUser = FakeUser(uid: '   ');
      expect(
        () =>
            service.uploadFaultImage(bytes: sampleBytes, fileName: 'motor.jpg'),
        throwsA(
          isA<StorageServiceException>().having(
            (e) => e.code,
            'code',
            'unauthenticated',
          ),
        ),
      );

      expect(fakeUploader.uploadCallCount, equals(0));
    });

    test('7. Firebase Storage upload failures are mapped correctly', () async {
      final errorCodes = {
        'unauthorized':
            'You do not have permission to upload or access this file.',
        'permission-denied':
            'You do not have permission to upload or access this file.',
        'retry-limit-exceeded': 'The upload timed out or exceeded the retry limit. Please try again.',
        'quota-exceeded':
            'Storage quota exceeded. Please contact your system administrator.',
        'canceled': 'The image upload was cancelled.',
        'invalid-checksum':
            'File integrity check failed during upload. Please try again.',
      };

      for (final entry in errorCodes.entries) {
        fakeUploader.errorToThrow = FirebaseException(
          plugin: 'firebase_storage',
          code: entry.key,
          message: 'Internal raw message from backend',
        );

        expect(
          () => service.uploadFaultImage(
            bytes: sampleBytes,
            fileName: 'pump.png',
          ),
          throwsA(
            isA<StorageServiceException>()
                .having((e) => e.code, 'code', entry.key)
                .having((e) => e.message, 'message', entry.value),
          ),
          reason: 'Failed to map code ${entry.key}',
        );
      }

      // Generic unexpected error during upload
      fakeUploader.errorToThrow = Exception('Socket closed unexpectedly');
      expect(
        () =>
            service.uploadFaultImage(bytes: sampleBytes, fileName: 'pump.png'),
        throwsA(
          isA<StorageServiceException>()
              .having((e) => e.code, 'code', 'upload-failed')
              .having(
                (e) => e.message,
                'message',
                'Failed to upload the image. Please try again.',
              ),
        ),
      );
    });

    test('8. Download-URL retrieval failures are handled safely', () async {
      fakeUploader.errorToThrow = StorageServiceException(
        code: 'download-url-failed',
        message: 'Failed to retrieve the image download URL after upload.',
      );

      expect(
        () => service.uploadFaultImage(
          bytes: sampleBytes,
          fileName: 'sensor.jpg',
        ),
        throwsA(
          isA<StorageServiceException>()
              .having((e) => e.code, 'code', 'download-url-failed')
              .having(
                (e) => e.message,
                'message',
                'Failed to retrieve the image download URL after upload.',
              ),
        ),
      );
    });

    test(
      '9. Image content type and upload metadata are passed correctly',
      () async {
        // Explicit content type
        await service.uploadFaultImage(
          bytes: sampleBytes,
          fileName: 'panel.png',
          contentType: 'image/png',
        );

        expect(fakeUploader.lastMetadata?.contentType, equals('image/png'));
        expect(
          fakeUploader.lastMetadata?.customMetadata?['uploadedBy'],
          equals('user-op-42'),
        );
        expect(
          fakeUploader.lastMetadata?.customMetadata?['originalFileName'],
          equals('panel.png'),
        );

        // Default content type
        await service.uploadFaultImage(
          bytes: sampleBytes,
          fileName: 'default_type.jpg',
        );

        expect(fakeUploader.lastMetadata?.contentType, equals('image/jpeg'));

        // Prevent path traversal and directory component leakage in custom metadata
        await service.uploadFaultImage(
          bytes: sampleBytes,
          fileName: '../../private/photo.png',
        );

        final originalFileName =
            fakeUploader.lastMetadata?.customMetadata?['originalFileName'];
        expect(originalFileName, equals('photo.png'));
        expect(originalFileName, isNot(contains('/')));
        expect(originalFileName, isNot(contains(r'\')));
        expect(originalFileName, isNot(contains('..')));
      },
    );

    test('upload() alias delegates to uploadFaultImage()', () async {
      const expectedUrl = 'https://download.url/image.jpg';
      fakeUploader.downloadUrlToReturn = expectedUrl;

      final url = await service.upload(
        bytes: sampleBytes,
        fileName: 'conveyor.jpg',
        contentType: 'image/jpeg',
      );

      expect(url, equals(expectedUrl));
      expect(fakeUploader.lastPath, contains('fault_images/user-op-42/'));
    });

    test(
      'FirebaseStorageUploader delegates upload and downloadURL correctly',
      () async {
        final fakeStorage = FakeFirebaseStorage();
        final uploader = FirebaseStorageUploader(fakeStorage);
        final metadata = SettableMetadata(contentType: 'image/jpeg');

        final url = await uploader.upload(
          path: 'fault_images/user-1/test.jpg',
          bytes: sampleBytes,
          metadata: metadata,
        );

        expect(url, equals(fakeStorage.defaultDownloadUrl));
        expect(fakeStorage.lastReference?.putDataBytes, equals(sampleBytes));
        expect(
          fakeStorage.lastReference?.putDataMetadata?.contentType,
          equals('image/jpeg'),
        );
      },
    );

    test(
      'FirebaseStorageUploader handles empty download URL as failure',
      () async {
        final fakeStorage = FakeFirebaseStorage()..defaultDownloadUrl = '   ';
        final uploader = FirebaseStorageUploader(fakeStorage);
        final metadata = SettableMetadata(contentType: 'image/jpeg');

        expect(
          () => uploader.upload(
            path: 'fault_images/user-1/test.jpg',
            bytes: sampleBytes,
            metadata: metadata,
          ),
          throwsA(
            isA<StorageServiceException>().having(
              (e) => e.code,
              'code',
              'download-url-failed',
            ),
          ),
        );
      },
    );

    test(
      'FirebaseStorageUploader converts putData FirebaseException',
      () async {
        final fakeStorage = FakeFirebaseStorage()
          ..nextPutDataError = FirebaseException(
            plugin: 'firebase_storage',
            code: 'unauthorized',
          );
        final uploader = FirebaseStorageUploader(fakeStorage);
        final metadata = SettableMetadata(contentType: 'image/jpeg');

        expect(
          () => uploader.upload(
            path: 'fault_images/user-1/test.jpg',
            bytes: sampleBytes,
            metadata: metadata,
          ),
          throwsA(isA<FirebaseException>()),
        );
      },
    );

    test('StorageService with FirebaseStorageUploader converts getDownloadURL FirebaseException to StorageServiceException with user-safe message', () async {
      final fakeStorage = FakeFirebaseStorage();
      const rawBackendError =
          'Internal raw server exception: permission denied in security rules';
      fakeStorage.nextGetDownloadUrlError = FirebaseException(
        plugin: 'firebase_storage',
        code: 'permission-denied',
        message: rawBackendError,
      );

      final integratedService = StorageService(
        auth: fakeAuth,
        storage: fakeStorage,
      );

      try {
        await integratedService.uploadFaultImage(
          bytes: sampleBytes,
          fileName: 'blueprint.png',
        );
        fail('Expected uploadFaultImage to throw StorageServiceException');
      } on StorageServiceException catch (e) {
        expect(e.code, equals('permission-denied'));
        expect(
          e.message,
          equals('You do not have permission to upload or access this file.'),
        );
        expect(e.message, isNot(contains(rawBackendError)));
      }
    });

    test('StorageService with FirebaseStorageUploader converts unexpected non-Firebase getDownloadURL error to download-url-failed', () async {
      final fakeStorage = FakeFirebaseStorage();
      const rawInternalError =
          'Socket closed unexpectedly: network transport failure';
      fakeStorage.nextGetDownloadUrlError = Exception(rawInternalError);

      final integratedService = StorageService(
        auth: fakeAuth,
        storage: fakeStorage,
      );

      try {
        await integratedService.uploadFaultImage(
          bytes: sampleBytes,
          fileName: 'schematic.png',
        );
        fail('Expected uploadFaultImage to throw StorageServiceException');
      } on StorageServiceException catch (e) {
        expect(e.code, equals('download-url-failed'));
        expect(
          e.message,
          equals('Failed to retrieve the image download URL after upload.'),
        );
        expect(e.message, isNot(contains(rawInternalError)));
      }
    });

    test('StorageService exposes underlying storage and auth instances', () {
      final fakeStorage = FakeFirebaseStorage();
      final injectedService = StorageService(
        storage: fakeStorage,
        auth: fakeAuth,
      );
      expect(injectedService.storage, equals(fakeStorage));
      expect(injectedService.auth, equals(fakeAuth));
    });

    test(
      'StorageServiceException equality, hashCode and toString behave properly',
      () {
        final ex1 = StorageServiceException(code: 'unauthenticated');
        final ex2 = StorageServiceException(code: 'unauthenticated');
        final ex3 = StorageServiceException(code: 'empty-data');

        expect(ex1, equals(ex2));
        expect(ex1.hashCode, equals(ex2.hashCode));
        expect(ex1, isNot(equals(ex3)));
        expect(ex1.toString(), contains('unauthenticated'));

        final fromFirebase = StorageServiceException.fromFirebaseException(
          FirebaseException(
            plugin: 'firebase_storage',
            code: 'object_not_found',
          ),
        );
        expect(fromFirebase.code, equals('object-not-found'));
        expect(
          fromFirebase.message,
          equals('The requested storage file was not found.'),
        );
      },
    );
  });
}
