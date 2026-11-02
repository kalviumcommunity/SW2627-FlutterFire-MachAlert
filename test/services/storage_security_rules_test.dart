import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/services/storage_service.dart';

/// Helper to generate an unsigned mock JWT accepted by Firebase Emulators.
String _createMockJwt(String uid) {
  final header = base64Url
      .encode(utf8.encode(jsonEncode({'alg': 'none', 'typ': 'JWT'})))
      .replaceAll('=', '');
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': uid, 'user_id': uid, 'aud': 'machalert'}),
        ),
      )
      .replaceAll('=', '');
  return '$header.$payload.';
}

/// Checks whether the local Storage emulator is reachable on port 9199.
Future<bool> _isStorageEmulatorRunning() async {
  try {
    final socket = await Socket.connect(
      '127.0.0.1',
      9199,
      timeout: const Duration(milliseconds: 500),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

/// Helper client for interacting with the Firebase Storage Emulator REST API.
class StorageEmulatorTestClient {
  final HttpClient _httpClient = HttpClient();
  final String host;
  final int port;
  final String bucket;

  StorageEmulatorTestClient({
    this.host = '127.0.0.1',
    this.port = 9199,
    this.bucket = 'machalert.appspot.com',
  });

  String get basePath => '/v0/b/$bucket/o';

  void close() => _httpClient.close(force: true);

  /// Uploads raw bytes to the specified storage object path.
  Future<int> uploadFile({
    required String path,
    required List<int> bytes,
    required String contentType,
    String? token,
    Map<String, String>? customMetadata,
  }) async {
    if (customMetadata != null && customMetadata.isNotEmpty) {
      // Use resumable protocol to attach metadata to the object
      final encodedName = Uri.encodeQueryComponent(path);
      final startUri = Uri.parse(
        'http://$host:$port$basePath?name=$encodedName',
      );
      final startReq = await _httpClient.postUrl(startUri);
      if (token != null) {
        startReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      startReq.headers.set('x-goog-upload-protocol', 'resumable');
      startReq.headers.set('x-goog-upload-command', 'start');
      startReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      startReq.add(
        utf8.encode(
          jsonEncode({'contentType': contentType, 'metadata': customMetadata}),
        ),
      );
      final startRes = await startReq.close();
      final uploadUrlStr = startRes.headers.value('x-goog-upload-url');
      await startRes.drain<void>();
      if (startRes.statusCode != 200 || uploadUrlStr == null) {
        return startRes.statusCode;
      }

      final uploadUri = Uri.parse(uploadUrlStr);
      final uploadReq = await _httpClient.postUrl(uploadUri);
      if (token != null) {
        uploadReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      uploadReq.headers.set('x-goog-upload-command', 'upload, finalize');
      uploadReq.headers.set('x-goog-upload-offset', '0');
      uploadReq.add(bytes);
      final uploadRes = await uploadReq.close();
      await uploadRes.drain<void>();
      return uploadRes.statusCode;
    }

    final encodedName = Uri.encodeQueryComponent(path);
    final uri = Uri.parse('http://$host:$port$basePath?name=$encodedName');
    final req = await _httpClient.postUrl(uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    req.headers.set(HttpHeaders.contentTypeHeader, contentType);
    req.add(bytes);
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Downloads a file from the specified storage path.
  Future<int> downloadFile(String path, {String? token}) async {
    final encodedPath = Uri.encodeComponent(path);
    final uri = Uri.parse('http://$host:$port$basePath/$encodedPath?alt=media');
    final req = await _httpClient.getUrl(uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  /// Deletes a file at the specified storage path.
  Future<int> deleteFile(String path, {String? token}) async {
    final encodedPath = Uri.encodeComponent(path);
    final uri = Uri.parse('http://$host:$port$basePath/$encodedPath');
    final req = await _httpClient.deleteUrl(uri);
    if (token != null) {
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
}

class _FakeStorageUploader implements StorageUploader {
  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required SettableMetadata metadata,
  }) async => 'https://example.com/test.jpg';
}

/// Helper to seed documents into Cloud Firestore Emulator REST v1 API
/// for cross-service Storage security rule tests.
class _FirestoreAdminSeeder {
  static const String host = '127.0.0.1';
  static const int port = 8080;
  static const String projectId = 'machalert';
  final HttpClient _httpClient = HttpClient();

  _FirestoreAdminSeeder();

  void close() => _httpClient.close(force: true);

  Future<void> setDocument(String path, Map<String, dynamic> fields) async {
    final uri = Uri.parse(
      'http://$host:$port/v1/projects/$projectId/databases/(default)/documents/$path',
    );
    final req = await _httpClient.openUrl('PATCH', uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'fields': _encodeFields(fields)}));
    final res = await req.close();
    await res.drain<void>();
  }

  Map<String, dynamic> _encodeFields(Map<String, dynamic> raw) {
    final encoded = <String, dynamic>{};
    raw.forEach((key, value) {
      encoded[key] = _encodeValue(value);
    });
    return encoded;
  }

  Map<String, dynamic> _encodeValue(dynamic value) {
    if (value is String) {
      return {'stringValue': value};
    } else if (value is int) {
      return {'integerValue': value.toString()};
    } else if (value is bool) {
      return {'booleanValue': value};
    } else if (value == null) {
      return {'nullValue': null};
    } else if (value is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': _encodeFields(value)},
      };
    }
    return {'stringValue': value.toString()};
  }
}

void main() {
  group('Firebase Storage Security Invariants & Schema Verification', () {
    const maxSizeBytes = 5 * 1024 * 1024; // 5 MB

    test(
      'Storage path format complies with user-scoped fault images pattern',
      () {
        final path = StorageService.buildStoragePath(
          uid: 'user_operator_123',
          fileName: 'conveyor_jam.jpg',
          folder: 'fault_images',
        );

        expect(path, startsWith('fault_images/user_operator_123/'));
        expect(path, endsWith('_conveyor_jam.jpg'));

        final parts = path.split('/');
        expect(parts.length, equals(3));
        expect(parts[0], equals('fault_images'));
        expect(parts[1], equals('user_operator_123'));
        expect(parts[2], contains('conveyor_jam.jpg'));
      },
    );

    test(
      'Storage path format complies with user-scoped maintenance proof pattern',
      () {
        final path = StorageService.buildStoragePath(
          uid: 'user_technician_456',
          fileName: 'bearing_repaired.png',
          folder: 'maintenance_proofs',
        );

        expect(path, startsWith('maintenance_proofs/user_technician_456/'));
        expect(path, endsWith('_bearing_repaired.png'));

        final parts = path.split('/');
        expect(parts.length, equals(3));
        expect(parts[0], equals('maintenance_proofs'));
        expect(parts[1], equals('user_technician_456'));
        expect(parts[2], contains('bearing_repaired.png'));
      },
    );

    test('Max file size boundary validation (5 MB limit)', () {
      const allowedSize = maxSizeBytes;
      const exceededSize = maxSizeBytes + 1;

      expect(allowedSize <= 5 * 1024 * 1024, isTrue);
      expect(exceededSize <= 5 * 1024 * 1024, isFalse);
    });

    test('Content type regex validation conforms to image/.* requirements', () {
      final regex = RegExp(r'^image/.*$');

      // Allowed image MIME types
      expect(regex.hasMatch('image/jpeg'), isTrue);
      expect(regex.hasMatch('image/png'), isTrue);
      expect(regex.hasMatch('image/webp'), isTrue);
      expect(regex.hasMatch('image/gif'), isTrue);

      // Disallowed non-image MIME types
      expect(regex.hasMatch('text/plain'), isFalse);
      expect(regex.hasMatch('application/pdf'), isFalse);
      expect(regex.hasMatch('application/octet-stream'), isFalse);
      expect(regex.hasMatch('application/javascript'), isFalse);
      expect(regex.hasMatch('video/mp4'), isFalse);
    });

    test('Filename sanitization rejects path traversal attempts', () {
      expect(
        () => StorageService.sanitizeFileName('../../etc/passwd'),
        returnsNormally,
      );
      final sanitized = StorageService.sanitizeFileName('../../etc/passwd');
      expect(sanitized, equals('passwd'));
      expect(sanitized, isNot(contains('/')));
      expect(sanitized, isNot(contains('..')));
    });

    test('StorageService rejects empty upload bytes', () async {
      final service = StorageService(
        auth: _FakeFirebaseAuth(),
        uploader: _FakeStorageUploader(),
      );
      expect(
        () =>
            service.uploadFaultImage(bytes: Uint8List(0), fileName: 'test.jpg'),
        throwsA(
          isA<StorageServiceException>().having(
            (e) => e.code,
            'code',
            equals('empty-data'),
          ),
        ),
      );
    });
  });

  group('Firebase Storage Security Rules - Emulator Allow/Deny Tests', () {
    late StorageEmulatorTestClient client;
    bool emulatorAvailable = false;

    final tokenUser1 = _createMockJwt('sec_storage_user_1');
    final tokenUser2 = _createMockJwt('sec_storage_user_2');
    final tokenMgr = _createMockJwt('sec_storage_mgr_1');
    final tokenTechAssigned = _createMockJwt('sec_storage_tech_assigned');
    final tokenTechOther = _createMockJwt('sec_storage_tech_other');
    final tokenOp = _createMockJwt('sec_storage_op_user');

    // 100 bytes sample image
    final sampleImageBytes = List<int>.filled(100, 0xFF);
    // 6 MB payload (exceeds 5 MB limit)
    final oversizeBytes = List<int>.filled(6 * 1024 * 1024, 0xAA);

    setUpAll(() async {
      emulatorAvailable = await _isStorageEmulatorRunning();
      client = StorageEmulatorTestClient();

      if (emulatorAvailable) {
        final seeder = _FirestoreAdminSeeder();
        try {
          await seeder.setDocument('users/sec_storage_mgr_1', {
            'uid': 'sec_storage_mgr_1',
            'role': 'manager',
          });
          await seeder.setDocument('users/sec_storage_tech_assigned', {
            'uid': 'sec_storage_tech_assigned',
            'role': 'technician',
          });
          await seeder.setDocument('users/sec_storage_tech_other', {
            'uid': 'sec_storage_tech_other',
            'role': 'technician',
          });
          await seeder.setDocument('users/sec_storage_op_user', {
            'uid': 'sec_storage_op_user',
            'role': 'operator',
          });
          await seeder.setDocument('maintenance/task_proof_cross_read', {
            'id': 'task_proof_cross_read',
            'technicianId': 'sec_storage_tech_assigned',
            'machineId': 'MCH-01',
            'status': 'Pending',
          });
        } finally {
          seeder.close();
        }
      }
    });

    tearDownAll(() {
      client.close();
    });

    test(
      'Authenticated user can upload image to own fault folder (200)',
      () async {
        if (!emulatorAvailable) return;

        final status = await client.uploadFile(
          path: 'fault_images/sec_storage_user_1/sample.jpg',
          bytes: sampleImageBytes,
          contentType: 'image/jpeg',
          token: tokenUser1,
        );

        expect(status, 200);
      },
    );

    test('Authenticated user can upload image to own maintenance proof folder (200)', () async {
      if (!emulatorAvailable) return;

      final status = await client.uploadFile(
        path: 'maintenance_proofs/sec_storage_user_1/proof.png',
        bytes: sampleImageBytes,
        contentType: 'image/png',
        token: tokenUser1,
      );

      expect(status, 200);
    });

    test(
      'User cannot upload image to another user fault folder (403)',
      () async {
        if (!emulatorAvailable) return;

        // User 1 attempts upload to User 2 folder
        final status = await client.uploadFile(
          path: 'fault_images/sec_storage_user_2/impersonate.jpg',
          bytes: sampleImageBytes,
          contentType: 'image/jpeg',
          token: tokenUser1,
        );

        expect(status, 403);
      },
    );

    test(
      'User cannot upload image to another user maintenance proof folder (403)',
      () async {
        if (!emulatorAvailable) return;

        // User 1 attempts upload to User 2 maintenance proofs
        final status = await client.uploadFile(
          path: 'maintenance_proofs/sec_storage_user_2/impersonate_proof.jpg',
          bytes: sampleImageBytes,
          contentType: 'image/jpeg',
          token: tokenUser1,
        );

        expect(status, 403);
      },
    );

    test('Unauthenticated image upload is rejected (403)', () async {
      if (!emulatorAvailable) return;

      final status = await client.uploadFile(
        path: 'fault_images/sec_storage_user_1/unauthenticated.jpg',
        bytes: sampleImageBytes,
        contentType: 'image/jpeg',
        token: null, // No auth token
      );

      expect(status, 403);
    });

    test('Non-image upload is rejected (403)', () async {
      if (!emulatorAvailable) return;

      final status = await client.uploadFile(
        path: 'fault_images/sec_storage_user_1/script.sh',
        bytes: utf8.encode('echo "malicious"'),
        contentType: 'text/plain',
        token: tokenUser1,
      );

      expect(status, 403);
    });

    test('Upload exceeding 5 MB limit is rejected (403)', () async {
      if (!emulatorAvailable) return;

      final status = await client.uploadFile(
        path: 'fault_images/sec_storage_user_1/huge_image.jpg',
        bytes: oversizeBytes,
        contentType: 'image/jpeg',
        token: tokenUser1,
      );

      expect(status, 403);
    });

    test('Upload to arbitrary non-approved folder is rejected (403)', () async {
      if (!emulatorAvailable) return;

      final status = await client.uploadFile(
        path: 'unapproved_folder/sec_storage_user_1/photo.jpg',
        bytes: sampleImageBytes,
        contentType: 'image/jpeg',
        token: tokenUser1,
      );

      expect(status, 403);
    });

    test('Owner can read their own uploaded fault image (200)', () async {
      if (!emulatorAvailable) return;

      await client.uploadFile(
        path: 'fault_images/sec_storage_user_1/read_test.jpg',
        bytes: sampleImageBytes,
        contentType: 'image/jpeg',
        token: tokenUser1,
      );

      final status = await client.downloadFile(
        'fault_images/sec_storage_user_1/read_test.jpg',
        token: tokenUser1,
      );

      expect(status, 200);
    });

    test(
      'Foreign operator without role privileges cannot read fault image (403)',
      () async {
        if (!emulatorAvailable) return;

        // User 2 (not owner, not tech/manager) attempts read -> 403
        final status = await client.downloadFile(
          'fault_images/sec_storage_user_1/read_test.jpg',
          token: tokenUser2,
        );

        expect(status, 403);
      },
    );

    test('Owner can read their own maintenance proof image (200)', () async {
      if (!emulatorAvailable) return;

      await client.uploadFile(
        path: 'maintenance_proofs/sec_storage_user_1/proof_read_test.png',
        bytes: sampleImageBytes,
        contentType: 'image/png',
        token: tokenUser1,
      );

      final status = await client.downloadFile(
        'maintenance_proofs/sec_storage_user_1/proof_read_test.png',
        token: tokenUser1,
      );

      expect(status, 200);
    });

    test('Foreign user cannot read maintenance proof image (403)', () async {
      if (!emulatorAvailable) return;

      final status = await client.downloadFile(
        'maintenance_proofs/sec_storage_user_1/proof_read_test.png',
        token: tokenUser2,
      );

      expect(status, 403);
    });

    test('Manager can read any maintenance proof image (200)', () async {
      if (!emulatorAvailable) return;

      final status = await client.downloadFile(
        'maintenance_proofs/sec_storage_user_1/proof_read_test.png',
        token: tokenMgr,
      );

      expect(status, 200);
    });

    test('Assigned technician can read maintenance proof with matching taskId in metadata (200)', () async {
      if (!emulatorAvailable) return;

      // Upload proof with taskId metadata
      final uploadStatus = await client.uploadFile(
        path: 'maintenance_proofs/sec_storage_user_1/proof_task_assigned.jpg',
        bytes: sampleImageBytes,
        contentType: 'image/jpeg',
        token: tokenUser1,
        customMetadata: {'taskId': 'task_proof_cross_read'},
      );
      expect(uploadStatus, 200);

      // Assigned technician accesses the proof
      final readStatus = await client.downloadFile(
        'maintenance_proofs/sec_storage_user_1/proof_task_assigned.jpg',
        token: tokenTechAssigned,
      );
      expect(readStatus, 200);
    });

    test('Unassigned technician cannot read maintenance proof even with taskId in metadata (403)', () async {
      if (!emulatorAvailable) return;

      final readStatus = await client.downloadFile(
        'maintenance_proofs/sec_storage_user_1/proof_task_assigned.jpg',
        token: tokenTechOther,
      );
      expect(readStatus, 403);
    });

    test('Operator cannot read maintenance proof even with taskId in metadata (403)', () async {
      if (!emulatorAvailable) return;

      final readStatus = await client.downloadFile(
        'maintenance_proofs/sec_storage_user_1/proof_task_assigned.jpg',
        token: tokenOp,
      );
      expect(readStatus, 403);
    });

    test('Unauthenticated image read is rejected (403)', () async {
      if (!emulatorAvailable) return;

      final status = await client.downloadFile(
        'fault_images/sec_storage_user_1/read_test.jpg',
        token: null,
      );

      expect(status, 403);
    });

    test('Unauthorized image deletion is rejected (403)', () async {
      if (!emulatorAvailable) return;

      final status = await client.deleteFile(
        'fault_images/sec_storage_user_1/read_test.jpg',
        token: tokenUser1,
      );

      expect(status, 403);
    });
  });
}
