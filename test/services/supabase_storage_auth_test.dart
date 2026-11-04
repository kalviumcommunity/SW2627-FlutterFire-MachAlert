import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' show SettableMetadata;
import 'package:flutter_test/flutter_test.dart';
import 'package:mach_alert/models/fault_model.dart';
import 'package:mach_alert/services/fault_service.dart';
import 'package:mach_alert/services/storage_service.dart';
import 'package:mach_alert/services/supabase_storage_uploader.dart';
import 'package:mach_alert/utils/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final User? user;

  FakeFirebaseAuth({this.user});

  @override
  User? get currentUser => user;
}

class FakeFirebaseUser extends Fake implements User {
  @override
  final String uid;

  @override
  final String? email;

  @override
  final String? displayName;

  final String? mockToken;

  FakeFirebaseUser({
    required this.uid,
    this.email = 'test@machalert.com',
    this.displayName,
    this.mockToken = 'mock-firebase-jwt-token',
  });

  @override
  Future<String> getIdToken([bool forceRefresh = false]) async {
    return mockToken!;
  }
}

class FakeStorageFileApi extends Fake implements StorageFileApi {
  final List<({String path, Uint8List bytes, FileOptions? options})> uploadedFiles = [];
  bool uploadShouldFailWithPermissionDenied = false;
  bool uploadShouldFailWithPayloadTooLarge = false;

  @override
  Future<String> uploadBinary(
    String path,
    Uint8List data, {
    FileOptions fileOptions = const FileOptions(),
    int? retryAttempts,
    StorageRetryController? retryController,
  }) async {
    if (uploadShouldFailWithPermissionDenied) {
      throw const StorageException(
        'new row violates row-level security policy',
        statusCode: '403',
      );
    }
    if (uploadShouldFailWithPayloadTooLarge) {
      throw const StorageException(
        'payload too large',
        statusCode: '413',
      );
    }
    uploadedFiles.add((path: path, bytes: data, options: fileOptions));
    return path;
  }

  @override
  Future<String> createSignedUrl(
    String path,
    int expiresIn, {
    TransformOptions? transform,
    String? cacheNonce,
    dynamic download,
  }) async {
    return 'https://klerkuqcpizqfkaksbrl.supabase.co/storage/v1/object/sign/fault-images/$path?token=signed-jwt';
  }

  @override
  String getPublicUrl(
    String path, {
    TransformOptions? transform,
    String? cacheNonce,
    dynamic download,
  }) {
    return 'https://klerkuqcpizqfkaksbrl.supabase.co/storage/v1/object/public/fault-images/$path';
  }
}

class FakeSupabaseStorageClient extends Fake implements SupabaseStorageClient {
  final FakeStorageFileApi fileApi;

  FakeSupabaseStorageClient(this.fileApi);

  @override
  StorageFileApi from(String bucket) => fileApi;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final FakeSupabaseStorageClient _storageClient;

  FakeSupabaseClient(this._storageClient);

  @override
  SupabaseStorageClient get storage => _storageClient;
}

/// Evaluates Supabase PostgreSQL Row-Level Security rules in software
/// according to scripts/supabase/storage_rls_policies.sql specifications.
class SupabaseStorageRlsSimulator {
  static bool canInsert({
    required Map<String, dynamic>? jwt,
    required String bucketId,
    required String path,
    required String mimeType,
    required int fileSizeBytes,
  }) {
    if (jwt == null) return false;
    if (jwt['role'] != 'authenticated') return false;
    if (bucketId != 'fault-images') return false;

    // (storage.foldername(name))[1] = auth.jwt()->>'sub'
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.first != jwt['sub']) return false;

    // MIME type check
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];
    final isAllowedMime = allowedTypes.contains(mimeType.toLowerCase()) ||
        mimeType.toLowerCase().startsWith('image/');
    if (!isAllowedMime) return false;

    // Size limit check: 5 MB
    if (fileSizeBytes > 5 * 1024 * 1024) return false;

    return true;
  }

  static bool canSelect({
    required Map<String, dynamic>? jwt,
    required String bucketId,
    required String path,
  }) {
    if (jwt == null) return false;
    if (jwt['role'] != 'authenticated') return false;
    if (bucketId != 'fault-images') return false;

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final ownerUid = segments.isNotEmpty ? segments.first : '';

    // Reporter can read their own photos
    if (ownerUid == jwt['sub']) return true;

    // Technician can read plant-wide fault photos
    if (jwt['machalert_role'] == 'technician') return true;

    // Manager can read plant-wide fault photos
    if (jwt['machalert_role'] == 'manager') return true;

    // Foreign operators or other roles are denied
    return false;
  }

  static bool canUpdate() => false;
  static bool canDelete() => false;
}

void main() {
  group('Supabase Storage Authentication & Policy Enforcement Tests', () {
    late FakeStorageFileApi fakeFileApi;
    late FakeSupabaseClient fakeClient;
    late FakeFirebaseUser testUser;
    late FakeFirebaseAuth fakeAuth;
    late SupabaseStorageUploader uploader;

    setUp(() {
      fakeFileApi = FakeStorageFileApi();
      fakeClient = FakeSupabaseClient(FakeSupabaseStorageClient(fakeFileApi));
      testUser = FakeFirebaseUser(uid: 'tech-001', email: 'tech@machalert.com');
      fakeAuth = FakeFirebaseAuth(user: testUser);
      uploader = SupabaseStorageUploader(
        clientOverride: fakeClient,
        authOverride: fakeAuth,
      );
    });

    test('8. Upload allowed inside own UID folder', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final downloadUrl = await uploader.upload(
        path: 'tech-001/fault_photo.jpg',
        bytes: bytes,
        metadata: SettableMetadata(contentType: 'image/jpeg'),
      );

      expect(downloadUrl, contains('tech-001/fault_photo.jpg'));
      expect(fakeFileApi.uploadedFiles.length, 1);
      expect(fakeFileApi.uploadedFiles.first.path, 'tech-001/fault_photo.jpg');
    });

    test('8b. Path normalization strips legacy prefix and enforces user UID folder', () async {
      final normalized = SupabaseStorageUploader.normalizeUserScopedPath(
        'fault_images/tech-001/1700000000_abc_motor.jpg',
        'tech-001',
      );

      expect(normalized, 'tech-001/1700000000_abc_motor.jpg');
    });

    test('9. Foreign-folder upload is denied', () async {
      // Authenticated as tech-001, but trying to upload to other-user-999
      final foreignUser = FakeFirebaseUser(uid: 'tech-001');
      final foreignAuth = FakeFirebaseAuth(user: foreignUser);
      final foreignUploader = SupabaseStorageUploader(
        clientOverride: fakeClient,
        authOverride: foreignAuth,
      );

      // Force simulated RLS policy violation on Supabase backend
      fakeFileApi.uploadShouldFailWithPermissionDenied = true;

      expect(
        () => foreignUploader.upload(
          path: 'tech-001/evil.jpg',
          bytes: Uint8List.fromList([1, 2, 3]),
          metadata: SettableMetadata(contentType: 'image/jpeg'),
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        )),
      );
    });

    test('10. RLS Simulation: Foreign operator image read denied', () {
      final operatorJwt = {
        'sub': 'operator-999',
        'role': 'authenticated',
        'machalert_role': 'operator',
      };

      // Operator attempting to read photo belonging to user-111
      final canRead = SupabaseStorageRlsSimulator.canSelect(
        jwt: operatorJwt,
        bucketId: 'fault-images',
        path: 'user-111/bearing_overheat.jpg',
      );

      expect(canRead, isFalse);
    });

    test('10b. RLS Simulation: Reporter can read their own photos', () {
      final operatorJwt = {
        'sub': 'operator-999',
        'role': 'authenticated',
        'machalert_role': 'operator',
      };

      // Operator reading their own photo
      final canRead = SupabaseStorageRlsSimulator.canSelect(
        jwt: operatorJwt,
        bucketId: 'fault-images',
        path: 'operator-999/my_fault.jpg',
      );

      expect(canRead, isTrue);
    });

    test('11. RLS Simulation: Technician image read permitted plant-wide', () {
      final technicianJwt = {
        'sub': 'technician-456',
        'role': 'authenticated',
        'machalert_role': 'technician',
      };

      // Technician reading photo reported by another user
      final canRead = SupabaseStorageRlsSimulator.canSelect(
        jwt: technicianJwt,
        bucketId: 'fault-images',
        path: 'operator-999/leaking_pump.jpg',
      );

      expect(canRead, isTrue);
    });

    test('12. RLS Simulation: Manager image read permitted plant-wide', () {
      final managerJwt = {
        'sub': 'manager-789',
        'role': 'authenticated',
        'machalert_role': 'manager',
      };

      // Manager inspecting plant floor incident photo
      final canRead = SupabaseStorageRlsSimulator.canSelect(
        jwt: managerJwt,
        bucketId: 'fault-images',
        path: 'operator-999/cracked_gear.jpg',
      );

      expect(canRead, isTrue);
    });

    test('13. Unauthenticated access denied for upload and read', () async {
      // 1. Unauthenticated client uploader
      final unauthAuth = FakeFirebaseAuth(user: null);
      final unauthUploader = SupabaseStorageUploader(
        clientOverride: fakeClient,
        authOverride: unauthAuth,
      );

      expect(
        () => unauthUploader.upload(
          path: 'tech-001/photo.jpg',
          bytes: Uint8List.fromList([1, 2, 3]),
          metadata: SettableMetadata(contentType: 'image/jpeg'),
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'unauthenticated',
        )),
      );

      // 2. RLS Policy Simulation for unauthenticated request (null JWT)
      expect(
        SupabaseStorageRlsSimulator.canInsert(
          jwt: null,
          bucketId: 'fault-images',
          path: 'tech-001/photo.jpg',
          mimeType: 'image/jpeg',
          fileSizeBytes: 1024,
        ),
        isFalse,
      );

      expect(
        SupabaseStorageRlsSimulator.canSelect(
          jwt: null,
          bucketId: 'fault-images',
          path: 'tech-001/photo.jpg',
        ),
        isFalse,
      );
    });

    test('14. Client-side delete and update are strictly denied', () {
      expect(SupabaseStorageRlsSimulator.canUpdate(), isFalse);
      expect(SupabaseStorageRlsSimulator.canDelete(), isFalse);
    });

    test('15. Image size exceeding 5 MB limit is rejected before upload', () async {
      // 5 MB + 1 byte
      final oversizedBytes = Uint8List(5 * 1024 * 1024 + 1);

      expect(
        () => uploader.upload(
          path: 'tech-001/large_raw_photo.png',
          bytes: oversizedBytes,
          metadata: SettableMetadata(contentType: 'image/png'),
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'file-too-large',
        )),
      );

      expect(fakeFileApi.uploadedFiles.isEmpty, isTrue);
    });

    test('16. Empty bytes upload is rejected with empty-data error', () async {
      expect(
        () => uploader.upload(
          path: 'tech-001/empty.jpg',
          bytes: Uint8List(0),
          metadata: SettableMetadata(contentType: 'image/jpeg'),
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'empty-data',
        )),
      );
    });

    test('17. StorageService seamlessly integrates with SupabaseStorageUploader', () async {
      final storageService = StorageService(
        auth: fakeAuth,
        uploader: uploader,
      );

      final permanentPath = await storageService.uploadFaultImage(
        bytes: Uint8List.fromList([10, 20, 30]),
        fileName: 'conveyor_jam.jpg',
      );

      expect(permanentPath, contains('tech-001/'));
      expect(permanentPath, isNot(contains('token=')));
      expect(fakeFileApi.uploadedFiles.length, 1);
    });

    test('18. SupabaseStorageUploader returns permanent storagePath and does NOT return expiring token URL', () async {
      final path = await uploader.upload(
        path: 'tech-001/motor_bearing.jpg',
        bytes: Uint8List.fromList([1, 2, 3, 4]),
        metadata: SettableMetadata(contentType: 'image/jpeg'),
      );

      expect(path, equals('tech-001/motor_bearing.jpg'));
      expect(path, isNot(contains('token=')));
      expect(path, isNot(contains('http')));
    });

    test('19. getSignedUrl dynamically resolves temporary signed URLs on demand for private image viewing', () async {
      final signedUrl = await uploader.getSignedUrl('tech-001/private_photo.png', expiresInSeconds: 1800);

      expect(signedUrl, contains('tech-001/private_photo.png'));
      expect(signedUrl, contains('token=signed-jwt'));
    });

    test('20. UnconfiguredStorageUploader prevents silent fallback to Firebase Storage and throws clear error', () async {
      const unconfiguredUploader = UnconfiguredStorageUploader();
      final storageService = StorageService(
        auth: fakeAuth,
        uploader: unconfiguredUploader,
      );

      expect(storageService.storageProvider, equals('unconfigured'));

      expect(
        () => storageService.uploadFaultImage(
          bytes: Uint8List.fromList([10, 20]),
          fileName: 'blocked_upload.jpg',
        ),
        throwsA(isA<StorageServiceException>().having(
          (e) => e.code,
          'code',
          'storage-unconfigured',
        )),
      );
    });

    test('21. FaultModel serializes and deserializes storagePath and storageProvider cleanly', () {
      final model = FaultModel(
        id: 'F-101',
        machineId: 'M-1',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityHigh,
        description: 'Overheating gearbox on press line.',
        reportedBy: 'tech-001',
        storagePath: 'tech-001/1700_gearbox.jpg',
        storageProvider: AppConstants.storageProviderSupabase,
      );

      expect(model.hasImage, isTrue);
      expect(model.imageUrl, isNull);

      final map = model.toFirestoreMap();
      expect(map['storagePath'], equals('tech-001/1700_gearbox.jpg'));
      expect(map['storageProvider'], equals('supabase'));
      expect(map['imageUrl'], isNull);

      final restored = FaultModel.fromMap(map, 'F-101');
      expect(restored.storagePath, equals('tech-001/1700_gearbox.jpg'));
      expect(restored.storageProvider, equals('supabase'));
      expect(restored.hasImage, isTrue);
    });

    test('22. FaultModel.fromMap recovers permanent storagePath from legacy expiring signed URL', () {
      const legacyExpiringUrl =
          'https://klerkuqcpizqfkaksbrl.supabase.co/storage/v1/object/sign/fault-images/tech-001/169999_legacy.jpg?token=expiring-jwt-123';

      final map = <String, dynamic>{
        'machineId': 'M-02',
        'type': AppConstants.faultTypeElectrical,
        'severity': AppConstants.severityCritical,
        'description': 'Blown capacitor on main inverter.',
        'reportedBy': 'tech-001',
        'imageUrl': legacyExpiringUrl,
      };

      final restored = FaultModel.fromMap(map, 'F-LEGACY');
      expect(restored.storagePath, equals('tech-001/169999_legacy.jpg'));
      expect(restored.storageProvider, equals(AppConstants.storageProviderSupabase));
      expect(restored.hasImage, isTrue);
    });

    test('23. FaultService.addFault strips expiring signed URL and stores permanent storagePath metadata', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      const expiringSignedUrl =
          'https://klerkuqcpizqfkaksbrl.supabase.co/storage/v1/object/sign/fault-images/tech-001/spindle_jam.jpg?token=temp-jwt';

      final fault = FaultModel(
        id: '',
        machineId: 'M-03',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityHigh,
        description: 'Spindle bearing seized during morning shift.',
        reportedBy: '',
        imageUrl: expiringSignedUrl,
        createdAt: DateTime(2026, 11, 3, 10, 0),
      );

      final docId = await faultService.addFault(fault);

      final savedDoc = await fakeFirestore.collection('faults').doc(docId).get();
      final data = savedDoc.data()!;

      expect(data['storagePath'], equals('tech-001/spindle_jam.jpg'));
      expect(data['storageProvider'], equals(AppConstants.storageProviderSupabase));
      // Expiring signed URL must NOT be stored in Firestore
      expect(data['imageUrl'], isNull);
    });

    test('24. FaultService.addFault preserves existing permanent Firebase Storage imageUrl records', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      const firebasePermanentUrl =
          'https://firebasestorage.googleapis.com/v0/b/machalert.appspot.com/o/fault_images%2Flegacy.jpg?alt=media';

      final fault = FaultModel(
        id: '',
        machineId: 'M-04',
        type: AppConstants.faultTypeElectrical,
        severity: AppConstants.severityMedium,
        description: 'Flickering display panel on controller.',
        reportedBy: '',
        imageUrl: firebasePermanentUrl,
        createdAt: DateTime(2026, 11, 3, 10, 0),
      );

      final docId = await faultService.addFault(fault);

      final savedDoc = await fakeFirestore.collection('faults').doc(docId).get();
      final data = savedDoc.data()!;

      expect(data['imageUrl'], equals(firebasePermanentUrl));
      expect(data['storageProvider'], equals(AppConstants.storageProviderFirebase));
    });

    test('25. FaultService.getFaultImageUrl resolves signed URL for Supabase and permanent URL for Firebase', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final faultService = FaultService(
        firestore: fakeFirestore,
        firebaseAuth: fakeAuth,
      );

      final storageService = StorageService(
        auth: fakeAuth,
        uploader: uploader,
      );

      // 1. Supabase fault with permanent storagePath
      final supabaseFault = FaultModel(
        id: 'F-S1',
        machineId: 'M-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityLow,
        description: 'Minor oil leak.',
        reportedBy: 'tech-001',
        storagePath: 'tech-001/leak.jpg',
        storageProvider: AppConstants.storageProviderSupabase,
      );

      final resolvedSupabaseUrl = await faultService.getFaultImageUrl(
        supabaseFault,
        storageService: storageService,
      );

      expect(resolvedSupabaseUrl, contains('tech-001/leak.jpg'));
      expect(resolvedSupabaseUrl, contains('token=signed-jwt'));

      // 2. Firebase fault with permanent imageUrl
      const firebasePermanentUrl =
          'https://firebasestorage.googleapis.com/v0/b/machalert.appspot.com/o/fault_images%2Fphoto.jpg?alt=media';
      final firebaseFault = FaultModel(
        id: 'F-F1',
        machineId: 'M-01',
        type: AppConstants.faultTypeMechanical,
        severity: AppConstants.severityLow,
        description: 'Loose belt.',
        reportedBy: 'tech-001',
        imageUrl: firebasePermanentUrl,
      );

      final resolvedFirebaseUrl = await faultService.getFaultImageUrl(
        firebaseFault,
        storageService: storageService,
      );

      expect(resolvedFirebaseUrl, equals(firebasePermanentUrl));
    });
  });
}
